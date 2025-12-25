import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typewriter/models/staging.dart';

void main() {
  group('StagingState', () {
    test('should have correct number of states', () {
      expect(StagingState.values.length, 3);
    });

    test('publishing state should have correct properties', () {
      const state = StagingState.publishing;
      expect(state.label, 'Publishing');
      expect(state.color, Colors.lightBlue);
      expect(state.name, 'publishing');
    });

    test('staging state should have correct properties', () {
      const state = StagingState.staging;
      expect(state.label, 'Staging');
      expect(state.color, Colors.orange);
      expect(state.name, 'staging');
    });

    test('production state should have correct properties', () {
      const state = StagingState.production;
      expect(state.label, 'Production');
      expect(state.color, Colors.green);
      expect(state.name, 'production');
    });

    test('should be ordered correctly', () {
      expect(StagingState.values[0], StagingState.publishing);
      expect(StagingState.values[1], StagingState.staging);
      expect(StagingState.values[2], StagingState.production);
    });

    test('should have unique indices', () {
      expect(StagingState.publishing.index, 0);
      expect(StagingState.staging.index, 1);
      expect(StagingState.production.index, 2);
    });
  });

  group('PublishPagesIntent', () {
    test('should create instance', () {
      const intent = PublishPagesIntent();
      expect(intent, isA<Intent>());
    });

    test('should be const constructible', () {
      const intent1 = PublishPagesIntent();
      const intent2 = PublishPagesIntent();
      expect(identical(intent1, intent2), true);
    });
  });
}
