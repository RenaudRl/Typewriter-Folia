import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart" hide ConnectionState;
import "package:flutter_animate/flutter_animate.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:typewriter/app_router.dart";
import "package:typewriter/hooks/delayed_execution.dart";
import "package:typewriter/models/book.dart";
import "package:typewriter/models/communicator.dart";
import "package:typewriter/models/entry_blueprint.dart";
import "package:typewriter/models/mcp_service.dart";
import "package:typewriter/pages/connect_page.dart";
import "package:typewriter/utils/icons.dart";
import "package:typewriter/widgets/components/app/search_bar.dart";
import "package:typewriter/widgets/components/app/writers.dart";
import "package:typewriter/widgets/components/general/iconify.dart";
import "package:url_launcher/url_launcher.dart";

@RoutePage()
class BookPage extends HookConsumerWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);

    return AutoTabsRouter(
      routes: const [
        PagesListRoute(),
      ],
      transitionBuilder: (context, child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            SearchBarWrapper(
              child: Scaffold(
                body: Row(
                  children: [
                    const _SideRail(),
                    Expanded(
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
            if (connectionState == ConnectionState.disconnected) ...[
              const ModalBarrier(
                dismissible: false,
                color: Colors.black54,
              ),
              const _ReconnectOverlay(),
            ],
          ],
        );
      },
    );
  }
}

class _ReconnectOverlay extends HookConsumerWidget {
  const _ReconnectOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(
      duration: 30.seconds,
    )..forward();

    final colorTween = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.5, 1),
      ),
    );

    useAnimation(controller);

    useDelayedExecution(() {
      while (ModalRoute.of(context)?.isCurrent != true) {
        Navigator.of(context).pop();
      }
    });

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 420,
            child: LinearProgressIndicator(
              value: 1 - controller.value,
              valueColor: colorTween,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Connection lost, Reconnecting...",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const ConnectionScroller(
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends HookConsumerWidget {
  const _SideRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var index = 0;
    return Container(
      width: 60,
      color: const Color(0xFF11274f),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13.0),
            child: Image.asset("assets/typewriter-icon.png"),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Column(
              children: [
                _RailButton(index++, icon: TWIcons.filePen),
                const Spacer(),
                const GlobalWriters(direction: Axis.vertical),
                const SizedBox(height: 5),
                const _MCPButton(),
                const SizedBox(height: 5),
                const _DiscordButton(),
                const SizedBox(height: 5),
                const _WikiButton(),
                const SizedBox(height: 5),
                const _ReloadBookButton(),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RailButton extends HookConsumerWidget {
  const _RailButton(
    this.index, {
    required this.icon,
  });
  final int index;
  final String icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabRouter = context.tabsRouter;
    final isSelected = tabRouter.activeIndex == index;
    return Material(
      color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => tabRouter.setActiveIndex(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Iconify(
            icon,
            color: isSelected ? Colors.white : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SimpleButton extends HookConsumerWidget {
  const _SimpleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(duration: 2.seconds);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onHover: (hover) {
          if (hover) {
            controller.forward(from: 0);
          } else {
            controller.reset();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Iconify(
              icon,
              color: Colors.white54,
              size: 20,
            ),
          )
              .animate(controller: controller)
              .scaleXY(
                begin: 1,
                end: 1.1,
                curve: Curves.easeInOutCubicEmphasized,
                duration: 500.ms,
              )
              .shake(delay: 300.ms, duration: 700.ms)
              .scaleXY(
                begin: 1.1,
                end: 1,
                curve: Curves.easeInOut,
                delay: 700.ms,
                duration: 500.ms,
              ),
        ),
      ),
    );
  }
}

class _DiscordButton extends HookConsumerWidget {
  const _DiscordButton();

  void _launchDiscord() {
    launchUrl(
      Uri.parse("https://discord.gg/gs5QYhfv9x"),
      webOnlyWindowName: "_blank",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleButton(
      tooltip: "Join Discord",
      icon: "bi:discord",
      onTap: _launchDiscord,
    );
  }
}

class _WikiButton extends HookConsumerWidget {
  const _WikiButton();

  void _launchWiki() {
    launchUrl(
      Uri.parse(wikiBaseUrl),
      webOnlyWindowName: "_blank",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleButton(
      tooltip: "Open Wiki",
      icon: "oi:book",
      onTap: _launchWiki,
    );
  }
}

class _ReloadBookButton extends HookConsumerWidget {
  const _ReloadBookButton() : super();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleButton(
      tooltip: "Reload Data",
      icon: "fa6-solid:arrows-rotate",
      onTap: () => ref.read(bookProvider.notifier).reload(),
    );
  }
}

class _MCPButton extends HookConsumerWidget {
  const _MCPButton();

  void _showMCPDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _MCPDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _showMCPDialog(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: "MCP AI Assistant",
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Iconify(
                  TWIcons.robot,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MCPDialog extends HookConsumerWidget {
  const _MCPDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mcpState = ref.watch(mcpProvider);
    final isConnected = mcpState.connectionState == MCPConnectionState.connected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Iconify(TWIcons.robot, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "MCP AI Assistant",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.info_outline,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? "Connected" : "Ready for AI",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                        Text(
                          mcpState.statusMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Claude Code can now edit your TypeWriter pages directly. Use the MCP connector to:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const _FeatureItem(icon: Icons.auto_fix_high, text: "Create entries automatically"),
            const _FeatureItem(icon: Icons.link, text: "Link triggers and criteria"),
            const _FeatureItem(icon: Icons.psychology, text: "Generate quests and dialogues"),
            const _FeatureItem(icon: Icons.speed, text: "Batch modifications"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isConnected) {
                    ref.read(mcpProvider.notifier).disconnect();
                  } else {
                    ref.read(mcpProvider.notifier).connect();
                  }
                },
                icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                label: Text(isConnected ? "Disable MCP" : "Enable MCP"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : const Color(0xFF6366f1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6366f1)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
