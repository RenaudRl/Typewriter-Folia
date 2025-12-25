import "dart:async";
import "dart:convert";

import "package:collection/collection.dart";
import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:typewriter/models/book.dart";
import "package:typewriter/models/entry.dart";
import "package:typewriter/models/entry_blueprint.dart";
import "package:typewriter/models/page.dart";
import "package:typewriter/utils/passing_reference.dart";
import "package:web_socket_channel/web_socket_channel.dart";

enum MCPConnectionState { disconnected, connecting, connected, error }

class MCPState {
  const MCPState({
    this.connectionState = MCPConnectionState.disconnected,
    this.statusMessage = "Not connected",
    this.lastCommand,
    this.commandsReceived = 0,
  });

  final MCPConnectionState connectionState;
  final String statusMessage;
  final String? lastCommand;
  final int commandsReceived;

  MCPState copyWith({
    MCPConnectionState? connectionState,
    String? statusMessage,
    String? lastCommand,
    int? commandsReceived,
  }) {
    return MCPState(
      connectionState: connectionState ?? this.connectionState,
      statusMessage: statusMessage ?? this.statusMessage,
      lastCommand: lastCommand ?? this.lastCommand,
      commandsReceived: commandsReceived ?? this.commandsReceived,
    );
  }
}

class MCPNotifier extends StateNotifier<MCPState> {
  MCPNotifier(this.ref) : super(const MCPState());

  final Ref ref;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  int _messageId = 0;

  static const int mcpPort = 3491;

  Future<void> connect() async {
    if (state.connectionState == MCPConnectionState.connecting) return;

    state = state.copyWith(
      connectionState: MCPConnectionState.connecting,
      statusMessage: "Connecting to MCP...",
    );

    try {
      final wsUrl = Uri.parse("ws://localhost:$mcpPort");
      _channel = WebSocketChannel.connect(wsUrl);

      await _channel!.ready;

      state = state.copyWith(
        connectionState: MCPConnectionState.connected,
        statusMessage: "Connected - AI can edit pages",
      );

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (dynamic error) {
          state = state.copyWith(
            connectionState: MCPConnectionState.error,
            statusMessage: "Error: $error",
          );
        },
        onDone: () {
          state = state.copyWith(
            connectionState: MCPConnectionState.disconnected,
            statusMessage: "Disconnected",
          );
        },
      );

      _sendPanelInfo();
      _sendBlueprints();
      _startHeartbeat();
    } on Exception catch (e) {
      state = state.copyWith(
        connectionState: MCPConnectionState.error,
        statusMessage: "Connection failed: $e",
      );
    }
  }

  void disconnect() {
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    state = state.copyWith(
      connectionState: MCPConnectionState.disconnected,
      statusMessage: "Disconnected",
    );
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      _send({"type": "heartbeat"});
    });
  }

  void _sendPanelInfo() {
    final book = ref.read(bookProvider);
    final pages = book.pages;

    _send({
      "type": "panelInfo",
      "data": {
        "version": "4.0.0",
        "pagesCount": pages.length,
        "pages": pages
            .map(
              (p) => {
                "id": p.id,
                "name": p.pageName,
                "type": p.type.name,
                "entriesCount": p.entries.length,
              },
            )
            .toList(),
      },
    });
  }

  void _sendBlueprints() {
    final blueprints = ref.read(entryBlueprintsProvider);
    _send({
      "type": "blueprintsUpdate",
      "blueprints": blueprints
          .map(
            (b) => {
              "id": b.id,
              "name": b.name,
              "description": b.description,
              "extension": b.extension,
              "tags": b.tags,
              "icon": b.icon,
            },
          )
          .toList(),
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel == null) return;
    data["id"] = ++_messageId;
    _channel!.sink.add(jsonEncode(data));
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data["type"] as String?;

      state = state.copyWith(
        lastCommand: type,
        commandsReceived: state.commandsReceived + 1,
      );

      switch (type) {
        case "getPages":
          _handleGetPages(data);
        case "getPage":
          _handleGetPage(data);
        case "getEntry":
          _handleGetEntry(data);
        case "getFullProject":
          _handleGetFullProject(data);
        case "createEntry":
          _handleCreateEntry(data);
        case "updateEntry":
          _handleUpdateEntry(data);
        case "deleteEntry":
          _handleDeleteEntry(data);
        case "createPage":
          _handleCreatePage(data);
        case "linkEntries":
          _handleLinkEntries(data);
        case "addCriteria":
          _handleAddCriteria(data);
        case "addModifier":
          _handleAddModifier(data);
        case "getBlueprints":
          _handleGetBlueprints(data);
        default:
          _sendResponse(data["id"] as int?, {"error": "Unknown command: $type"});
      }
    } on Exception catch (e) {
      debugPrint("MCP message error: $e");
    }
  }

  void _sendResponse(int? id, Map<String, dynamic> response) {
    if (id == null) return;
    _send({"type": "response", "requestId": id, ...response});
  }

  void _handleGetPages(Map<String, dynamic> data) {
    final book = ref.read(bookProvider);
    final pages = book.pages;

    _sendResponse(data["id"] as int?, {
      "pages": pages
          .map(
            (p) => {
              "id": p.id,
              "name": p.pageName,
              "type": p.type.name,
              "entriesCount": p.entries.length,
            },
          )
          .toList(),
    });
  }

  void _handleGetPage(Map<String, dynamic> data) {
    final pageId = data["pageId"] as String?;
    if (pageId == null) {
      _sendResponse(data["id"] as int?, {"error": "pageId required"});
      return;
    }

    final book = ref.read(bookProvider);
    final page = book.pages.where((p) => p.id == pageId).firstOrNull;

    if (page == null) {
      _sendResponse(data["id"] as int?, {"error": "Page not found"});
      return;
    }

    _sendResponse(data["id"] as int?, {
      "page": {
        "id": page.id,
        "name": page.pageName,
        "type": page.type.name,
        "entries": page.entries
            .map(
              (e) => {
                "id": e.id,
                "name": e.name,
                "type": e.blueprintId,
                "triggers": e.get("triggers") ?? [],
                "criteria": e.get("criteria") ?? [],
                "modifiers": e.get("modifiers") ?? [],
              },
            )
            .toList(),
      },
    });
  }

  void _handleGetEntry(Map<String, dynamic> data) {
    final pageId = data["pageId"] as String?;
    final entryId = data["entryId"] as String?;
    if (pageId == null || entryId == null) {
      _sendResponse(data["id"] as int?, {"error": "pageId and entryId required"});
      return;
    }

    final book = ref.read(bookProvider);
    final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) {
      _sendResponse(data["id"] as int?, {"error": "Page not found"});
      return;
    }

    final entry = page.entries.firstWhereOrNull((e) => e.id == entryId);
    if (entry == null) {
      _sendResponse(data["id"] as int?, {"error": "Entry not found"});
      return;
    }

    _sendResponse(data["id"] as int?, {
      "entry": {
        "id": entry.id,
        "name": entry.name,
        "type": entry.blueprintId,
        "data": entry.data,
      },
    });
  }

  void _handleGetFullProject(Map<String, dynamic> data) {
    final book = ref.read(bookProvider);
    final pages = book.pages;

    _sendResponse(data["id"] as int?, {
      "pages": pages
          .map(
            (p) => {
              "id": p.id,
              "name": p.pageName,
              "type": p.type.name,
              "entries": p.entries
                  .map(
                    (e) => {
                      "id": e.id,
                      "name": e.name,
                      "type": e.blueprintId,
                      "triggers": e.get("triggers") ?? [],
                      "criteria": e.get("criteria") ?? [],
                      "modifiers": e.get("modifiers") ?? [],
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    });
  }

  Future<void> _handleCreateEntry(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI creating entry...");
    try {
      final pageId = data["pageId"] as String?;
      final entryData = data["entry"] as Map<String, dynamic>?;
      if (pageId == null || entryData == null) {
        _sendResponse(data["id"] as int?, {"error": "pageId and entry required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Page not found"});
        return;
      }
      final entry = Entry(entryData.cast<String, dynamic>());
      await page.createEntry(ref.passing, entry);
      state = state.copyWith(statusMessage: "Entry created: ${entry.name}");
      _sendResponse(data["id"] as int?, {"success": true, "entryId": entry.id});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleUpdateEntry(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI updating entry...");
    try {
      final pageId = data["pageId"] as String?;
      final entryId = data["entryId"] as String?;
      final updates = data["data"] as Map<String, dynamic>?;
      if (pageId == null || entryId == null || updates == null) {
        _sendResponse(data["id"] as int?, {"error": "pageId, entryId, and data required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Page not found"});
        return;
      }
      final entry = page.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) {
        _sendResponse(data["id"] as int?, {"error": "Entry not found"});
        return;
      }
      var updatedEntry = entry;
      for (final field in updates.entries) {
        updatedEntry = updatedEntry.copyWith(field.key, field.value);
      }
      await page.updateEntireEntry(ref.passing, updatedEntry);
      state = state.copyWith(statusMessage: "Entry updated: ${entry.name}");
      _sendResponse(data["id"] as int?, {"success": true});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleDeleteEntry(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI deleting entry...");
    try {
      final pageId = data["pageId"] as String?;
      final entryId = data["entryId"] as String?;
      if (pageId == null || entryId == null) {
        _sendResponse(data["id"] as int?, {"error": "pageId and entryId required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Page not found"});
        return;
      }
      final entry = page.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) {
        _sendResponse(data["id"] as int?, {"error": "Entry not found"});
        return;
      }
      page.deleteEntry(ref.passing, entry);
      state = state.copyWith(statusMessage: "Entry deleted: ${entry.name}");
      _sendResponse(data["id"] as int?, {"success": true});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleCreatePage(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI creating page...");
    try {
      final pageData = data["page"] as Map<String, dynamic>?;
      if (pageData == null) {
        _sendResponse(data["id"] as int?, {"error": "page data required"});
        return;
      }
      final name = pageData["name"] as String? ?? "New Page";
      final typeStr = pageData["type"] as String? ?? "sequence";
      final pageType = PageType.values.firstWhereOrNull((t) => t.name == typeStr) ?? PageType.sequence;
      final newPage = await ref.read(bookProvider.notifier).createPage(name, pageType);
      state = state.copyWith(statusMessage: "Page created: $name");
      _sendResponse(data["id"] as int?, {"success": true, "pageId": newPage.id});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleLinkEntries(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI linking entries...");
    try {
      final sourcePageId = data["sourcePageId"] as String?;
      final sourceEntryId = data["sourceEntryId"] as String?;
      final targetEntryId = data["targetEntryId"] as String?;
      if (sourcePageId == null || sourceEntryId == null || targetEntryId == null) {
        _sendResponse(data["id"] as int?, {"error": "sourcePageId, sourceEntryId, targetEntryId required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == sourcePageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Source page not found"});
        return;
      }
      final entry = page.entries.firstWhereOrNull((e) => e.id == sourceEntryId);
      if (entry == null) {
        _sendResponse(data["id"] as int?, {"error": "Source entry not found"});
        return;
      }
      final currentTriggers = (entry.get("triggers") as List<dynamic>?) ?? [];
      final newTriggers = [...currentTriggers, targetEntryId];
      final updatedEntry = entry.copyWith("triggers", newTriggers);
      await page.updateEntireEntry(ref.passing, updatedEntry);
      state = state.copyWith(statusMessage: "Entries linked");
      _sendResponse(data["id"] as int?, {"success": true});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleAddCriteria(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI adding criteria...");
    try {
      final pageId = data["pageId"] as String?;
      final entryId = data["entryId"] as String?;
      final criteriaData = data["criteria"] as Map<String, dynamic>?;
      if (pageId == null || entryId == null || criteriaData == null) {
        _sendResponse(data["id"] as int?, {"error": "pageId, entryId, criteria required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Page not found"});
        return;
      }
      final entry = page.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) {
        _sendResponse(data["id"] as int?, {"error": "Entry not found"});
        return;
      }
      final currentCriteria = (entry.get("criteria") as List<dynamic>?) ?? [];
      final newCriteria = [...currentCriteria, criteriaData];
      final updatedEntry = entry.copyWith("criteria", newCriteria);
      await page.updateEntireEntry(ref.passing, updatedEntry);
      state = state.copyWith(statusMessage: "Criteria added");
      _sendResponse(data["id"] as int?, {"success": true});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  Future<void> _handleAddModifier(Map<String, dynamic> data) async {
    state = state.copyWith(statusMessage: "AI adding modifier...");
    try {
      final pageId = data["pageId"] as String?;
      final entryId = data["entryId"] as String?;
      final modifierData = data["modifier"] as Map<String, dynamic>?;
      if (pageId == null || entryId == null || modifierData == null) {
        _sendResponse(data["id"] as int?, {"error": "pageId, entryId, modifier required"});
        return;
      }
      final book = ref.read(bookProvider);
      final page = book.pages.firstWhereOrNull((p) => p.id == pageId);
      if (page == null) {
        _sendResponse(data["id"] as int?, {"error": "Page not found"});
        return;
      }
      final entry = page.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) {
        _sendResponse(data["id"] as int?, {"error": "Entry not found"});
        return;
      }
      final currentModifiers = (entry.get("modifiers") as List<dynamic>?) ?? [];
      final newModifiers = [...currentModifiers, modifierData];
      final updatedEntry = entry.copyWith("modifiers", newModifiers);
      await page.updateEntireEntry(ref.passing, updatedEntry);
      state = state.copyWith(statusMessage: "Modifier added");
      _sendResponse(data["id"] as int?, {"success": true});
    } on Exception catch (e) {
      _sendResponse(data["id"] as int?, {"error": e.toString()});
    }
  }

  void _handleGetBlueprints(Map<String, dynamic> data) {
    final blueprints = ref.read(entryBlueprintsProvider);
    _sendResponse(data["id"] as int?, {
      "blueprints": blueprints
          .map(
            (b) => {
              "id": b.id,
              "name": b.name,
              "description": b.description,
              "extension": b.extension,
              "tags": b.tags,
              "icon": b.icon,
            },
          )
          .toList(),
    });
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final mcpProvider = StateNotifierProvider<MCPNotifier, MCPState>((ref) {
  return MCPNotifier(ref);
});
