import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:typewriter/models/communicator.dart';
import 'package:typewriter/models/staging.dart';

import 'communicator_publish_test.mocks.dart';

@GenerateMocks([Socket])
void main() {
  group('Communicator.publish()', () {
    late ProviderContainer container;
    late MockSocket mockSocket;

    setUp(() {
      mockSocket = MockSocket();
      container = ProviderContainer(
        overrides: [
          socketProvider.overrideWith((ref) => SocketNotifier(ref)..state = mockSocket),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should emit publish event when in staging state and connected', () async {
      // Arrange
      when(mockSocket.connected).thenReturn(true);
      container.read(stagingStateProvider.notifier).state = StagingState.staging;

      when(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      )).thenAnswer((invocation) {
        final ack = invocation.namedArguments[Symbol('ack')] as Function?;
        ack?.call(null); // Simulate successful acknowledgment
      });

      // Act
      await container.read(communicatorProvider).publish();

      // Assert
      verify(mockSocket.emitWithAck(
        'publish',
        '',
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      )).called(1);
    });

    test('should not emit publish event when socket is null', () async {
      // Arrange
      final containerWithoutSocket = ProviderContainer(
        overrides: [
          socketProvider.overrideWith((ref) => SocketNotifier(ref)..state = null),
        ],
      );
      containerWithoutSocket.read(stagingStateProvider.notifier).state = StagingState.staging;

      // Act
      await containerWithoutSocket.read(communicatorProvider).publish();

      // Assert
      verifyNever(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));

      containerWithoutSocket.dispose();
    });

    test('should not emit publish event when socket is not connected', () async {
      // Arrange
      when(mockSocket.connected).thenReturn(false);
      container.read(stagingStateProvider.notifier).state = StagingState.staging;

      // Act
      await container.read(communicatorProvider).publish();

      // Assert
      verifyNever(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));
    });

    test('should not emit publish event when state is production', () async {
      // Arrange
      when(mockSocket.connected).thenReturn(true);
      container.read(stagingStateProvider.notifier).state = StagingState.production;

      // Act
      await container.read(communicatorProvider).publish();

      // Assert
      verifyNever(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));
    });

    test('should not emit publish event when state is publishing', () async {
      // Arrange
      when(mockSocket.connected).thenReturn(true);
      container.read(stagingStateProvider.notifier).state = StagingState.publishing;

      // Act
      await container.read(communicatorProvider).publish();

      // Assert
      verifyNever(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));
    });

    test('should handle publish with empty string data', () async {
      // Arrange
      when(mockSocket.connected).thenReturn(true);
      container.read(stagingStateProvider.notifier).state = StagingState.staging;

      String? capturedData;
      when(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      )).thenAnswer((invocation) {
        capturedData = invocation.positionalArguments[1] as String?;
        final ack = invocation.namedArguments[Symbol('ack')] as Function?;
        ack?.call(null);
      });

      // Act
      await container.read(communicatorProvider).publish();

      // Assert
      expect(capturedData, '');
    });
  });

  group('Communicator.handleStagingState()', () {
    late ProviderContainer container;
    late MockSocket mockSocket;

    setUp(() {
      mockSocket = MockSocket();
      container = ProviderContainer(
        overrides: [
          socketProvider.overrideWith((ref) => SocketNotifier(ref)..state = mockSocket),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should update staging state to publishing when receiving "publishing"', () {
      // Arrange
      final communicator = container.read(communicatorProvider);

      // Act
      communicator.handleStagingState('publishing');

      // Assert
      expect(
        container.read(stagingStateProvider),
        StagingState.publishing,
      );
    });

    test('should update staging state to staging when receiving "staging"', () {
      // Arrange
      final communicator = container.read(communicatorProvider);

      // Act
      communicator.handleStagingState('staging');

      // Assert
      expect(
        container.read(stagingStateProvider),
        StagingState.staging,
      );
    });

    test('should update staging state to production when receiving "production"', () {
      // Arrange
      final communicator = container.read(communicatorProvider);

      // Act
      communicator.handleStagingState('production');

      // Assert
      expect(
        container.read(stagingStateProvider),
        StagingState.production,
      );
    });

    test('should default to production when receiving unknown state', () {
      // Arrange
      final communicator = container.read(communicatorProvider);

      // Act
      communicator.handleStagingState('unknown_state');

      // Assert
      expect(
        container.read(stagingStateProvider),
        StagingState.production,
      );
    });

    test('should handle empty string as unknown state', () {
      // Arrange
      final communicator = container.read(communicatorProvider);

      // Act
      communicator.handleStagingState('');

      // Assert
      expect(
        container.read(stagingStateProvider),
        StagingState.production,
      );
    });
  });

  group('Staging workflow integration', () {
    late ProviderContainer container;
    late MockSocket mockSocket;

    setUp(() {
      mockSocket = MockSocket();
      container = ProviderContainer(
        overrides: [
          socketProvider.overrideWith((ref) => SocketNotifier(ref)..state = mockSocket),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should transition from production to staging to production', () {
      final communicator = container.read(communicatorProvider);

      // Start in production
      expect(container.read(stagingStateProvider), StagingState.production);

      // Transition to staging
      communicator.handleStagingState('staging');
      expect(container.read(stagingStateProvider), StagingState.staging);

      // Transition back to production
      communicator.handleStagingState('production');
      expect(container.read(stagingStateProvider), StagingState.production);
    });

    test('should allow publish only in staging state', () async {
      when(mockSocket.connected).thenReturn(true);
      when(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      )).thenAnswer((invocation) {
        final ack = invocation.namedArguments[Symbol('ack')] as Function?;
        ack?.call(null);
      });

      final communicator = container.read(communicatorProvider);

      // In production - should not publish
      communicator.handleStagingState('production');
      await communicator.publish();
      verifyNever(mockSocket.emitWithAck(
        'publish',
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));

      // In staging - should publish
      communicator.handleStagingState('staging');
      await communicator.publish();
      verify(mockSocket.emitWithAck(
        'publish',
        '',
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      )).called(1);
    });

    test('should handle publishing state correctly', () {
      final communicator = container.read(communicatorProvider);

      // Transition to publishing
      communicator.handleStagingState('publishing');
      expect(container.read(stagingStateProvider), StagingState.publishing);

      // Should not allow publish while publishing
      when(mockSocket.connected).thenReturn(true);
      communicator.publish();
      verifyNever(mockSocket.emitWithAck(
        any,
        any,
        binary: anyNamed('binary'),
        ack: anyNamed('ack'),
      ));
    });
  });
}
