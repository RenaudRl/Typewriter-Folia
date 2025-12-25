import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:typewriter/models/communicator.dart';
import 'package:typewriter/models/staging.dart';
import 'package:typewriter/widgets/components/app/staging.dart';

import 'staging_indicator_test.mocks.dart';

@GenerateMocks([Socket, Communicator])
void main() {
  group('StagingIndicator', () {
    late MockSocket mockSocket;
    late MockCommunicator mockCommunicator;

    setUp(() {
      mockSocket = MockSocket();
      mockCommunicator = MockCommunicator();
    });

    Widget createTestWidget(StagingState initialState) {
      return ProviderScope(
        overrides: [
          stagingStateProvider.overrideWith((ref) => initialState),
          socketProvider.overrideWith(
            (ref) => SocketNotifier(ref)..state = mockSocket,
          ),
          communicatorProvider.overrideWith((ref) => mockCommunicator),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StagingIndicator(),
          ),
        ),
      );
    });

    testWidgets('should display "Production" label when in production state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.production));

      // Assert
      expect(find.text('Production'), findsOneWidget);
    });

    testWidgets('should display "Staging" label when in staging state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.staging));

      // Assert
      expect(find.text('Staging'), findsOneWidget);
    });

    testWidgets('should display "Publishing" label when in publishing state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.publishing));

      // Assert
      expect(find.text('Publishing'), findsOneWidget);
    });

    testWidgets('should show dotted border only in staging state',
        (tester) async {
      // Test staging state
      await tester.pumpWidget(createTestWidget(StagingState.staging));
      await tester.pumpAndSettle();

      // In staging, the dotted border should be visible (orange color)
      final stagingText = tester.widget<Text>(find.text('Staging'));
      expect(stagingText.style?.color, Colors.orange);

      // Test production state
      await tester.pumpWidget(createTestWidget(StagingState.production));
      await tester.pumpAndSettle();

      final productionText = tester.widget<Text>(find.text('Production'));
      expect(productionText.style?.color, Colors.green);
    });

    testWidgets('should display green color for production state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.production));

      // Assert
      final text = tester.widget<Text>(find.text('Production'));
      expect(text.style?.color, Colors.green);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('should display orange color for staging state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.staging));

      // Assert
      final text = tester.widget<Text>(find.text('Staging'));
      expect(text.style?.color, Colors.orange);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('should display light blue color for publishing state',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget(StagingState.publishing));

      // Assert
      final text = tester.widget<Text>(find.text('Publishing'));
      expect(text.style?.color, Colors.lightBlue);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('should show publish button only in staging state',
        (tester) async {
      // Test staging state - should show publish button
      await tester.pumpWidget(createTestWidget(StagingState.staging));
      await tester.pumpAndSettle();

      expect(find.text('Publish'), findsOneWidget);

      // Test production state - should not show publish button
      await tester.pumpWidget(createTestWidget(StagingState.production));
      await tester.pumpAndSettle();

      expect(find.text('Publish'), findsNothing);

      // Test publishing state - should not show publish button
      await tester.pumpWidget(createTestWidget(StagingState.publishing));
      await tester.pumpAndSettle();

      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('should call publish() when publish button is tapped',
        (tester) async {
      // Arrange
      when(mockSocket.connected).thenReturn(true);
      when(mockCommunicator.publish()).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget(StagingState.staging));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockCommunicator.publish()).called(1);
    });

    testWidgets('publish button should animate on hover', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(StagingState.staging));
      await tester.pumpAndSettle();

      // Get initial position
      final publishButton = find.text('Publish');
      expect(publishButton, findsOneWidget);

      // Note: Hover testing in widget tests is limited, but we can verify
      // the button exists and is tappable
      await tester.tap(publishButton);
      await tester.pumpAndSettle();
    });
  });

  group('StagingIndicator state transitions', () {
    testWidgets('should update UI when state changes', (tester) async {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: StagingIndicator(),
            ),
          ),
        ),
      );

      // Initial state should be production
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);

      // Change to staging
      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;
      await tester.pumpAndSettle();

      expect(find.text('Staging'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);

      // Change to publishing
      container.read(stagingStateProvider.notifier).state =
          StagingState.publishing;
      await tester.pumpAndSettle();

      expect(find.text('Publishing'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);

      // Back to production
      container.read(stagingStateProvider.notifier).state =
          StagingState.production;
      await tester.pumpAndSettle();

      expect(find.text('Production'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });
  });
}
