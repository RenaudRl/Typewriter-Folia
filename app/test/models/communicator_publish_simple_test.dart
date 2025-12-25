import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:typewriter/models/staging.dart';

void main() {
  group('StagingState Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with production state', () {
      expect(
        container.read(stagingStateProvider),
        StagingState.production,
      );
    });

    test('should update state when notifier is called', () {
      // Initially production
      expect(container.read(stagingStateProvider), StagingState.production);

      // Change to staging
      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;
      expect(container.read(stagingStateProvider), StagingState.staging);

      // Change to publishing
      container.read(stagingStateProvider.notifier).state =
          StagingState.publishing;
      expect(container.read(stagingStateProvider), StagingState.publishing);

      // Back to production
      container.read(stagingStateProvider.notifier).state =
          StagingState.production;
      expect(container.read(stagingStateProvider), StagingState.production);
    });

    test('should maintain state across multiple reads', () {
      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;

      expect(container.read(stagingStateProvider), StagingState.staging);
      expect(container.read(stagingStateProvider), StagingState.staging);
      expect(container.read(stagingStateProvider), StagingState.staging);
    });
  });

  group('Staging workflow', () {
    test('should transition through all states correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Production -> Staging
      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;
      expect(container.read(stagingStateProvider), StagingState.staging);

      // Staging -> Publishing
      container.read(stagingStateProvider.notifier).state =
          StagingState.publishing;
      expect(container.read(stagingStateProvider), StagingState.publishing);

      // Publishing -> Production
      container.read(stagingStateProvider.notifier).state =
          StagingState.production;
      expect(container.read(stagingStateProvider), StagingState.production);
    });

    test('should allow direct transitions between any states', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Production -> Publishing (skip staging)
      container.read(stagingStateProvider.notifier).state =
          StagingState.publishing;
      expect(container.read(stagingStateProvider), StagingState.publishing);

      // Publishing -> Staging (reverse)
      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;
      expect(container.read(stagingStateProvider), StagingState.staging);
    });
  });

  group('State equality and comparison', () {
    test('should correctly identify staging state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(stagingStateProvider.notifier).state =
          StagingState.staging;

      final currentState = container.read(stagingStateProvider);
      expect(currentState == StagingState.staging, true);
      expect(currentState == StagingState.production, false);
      expect(currentState == StagingState.publishing, false);
    });

    test('should use same instance for enum values', () {
      expect(
        identical(StagingState.staging, StagingState.staging),
        true,
      );
      expect(
        identical(StagingState.production, StagingState.production),
        true,
      );
    });
  });
}
