import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';

void main() {
  final testImage = ImageData(
    bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xD9]),
    mimeType: 'image/jpeg',
  );

  group('DescribePhase', () {
    test('has all expected values', () {
      expect(DescribePhase.values, containsAll([
        DescribePhase.idle,
        DescribePhase.describing,
        DescribePhase.detailed,
        DescribePhase.completed,
      ]));
    });
  });

  group('DescribeState', () {
    test('default state is idle with no data', () {
      const state = DescribeState();
      expect(state.phase, DescribePhase.idle);
      expect(state.imageData, isNull);
      expect(state.description, isNull);
      expect(state.detailedDescription, isNull);
      expect(state.isOffline, isFalse);
    });

    test('idle constant matches default state', () {
      expect(DescribeState.idle.phase, DescribePhase.idle);
      expect(DescribeState.idle.imageData, isNull);
    });

    test('lastDescription returns null when no descriptions', () {
      expect(DescribeState.idle.lastDescription, isNull);
    });

    test('lastDescription returns description when no detailed', () {
      final state = DescribeState.idle.withDescription(
        testImage,
        'A bright room.',
      );
      expect(state.lastDescription, 'A bright room.');
    });

    test('lastDescription returns detailedDescription when available', () {
      final state = DescribeState.idle
          .withDescription(testImage, 'A bright room.')
          .withDetailedDescription('A bright room with blue sofa.');
      expect(state.lastDescription, 'A bright room with blue sofa.');
    });
  });

  group('transitions', () {
    test('idle -> describing via withDescription', () {
      final state = DescribeState.idle.withDescription(
        testImage,
        'Un salon lumineux.',
      );
      expect(state.phase, DescribePhase.describing);
      expect(state.imageData, testImage);
      expect(state.description, 'Un salon lumineux.');
      expect(state.isOffline, isFalse);
    });

    test('idle -> describing with offline flag', () {
      final state = DescribeState.idle.withDescription(
        testImage,
        'Texte OCR brut.',
        offline: true,
      );
      expect(state.phase, DescribePhase.describing);
      expect(state.isOffline, isTrue);
    });

    test('describing -> detailed via withDetailedDescription', () {
      final state = DescribeState.idle
          .withDescription(testImage, 'Un salon.')
          .withDetailedDescription('Un salon lumineux avec un canape bleu.');
      expect(state.phase, DescribePhase.detailed);
      expect(state.description, 'Un salon.');
      expect(state.detailedDescription, 'Un salon lumineux avec un canape bleu.');
      expect(state.imageData, testImage);
    });

    test('describing -> completed via toCompleted', () {
      final state = DescribeState.idle
          .withDescription(testImage, 'Un salon.')
          .toCompleted();
      expect(state.phase, DescribePhase.completed);
      expect(state.description, 'Un salon.');
      expect(state.imageData, testImage);
    });

    test('detailed -> completed via toCompleted', () {
      final state = DescribeState.idle
          .withDescription(testImage, 'Un salon.')
          .withDetailedDescription('Details...')
          .toCompleted();
      expect(state.phase, DescribePhase.completed);
    });

    test('copyWith preserves existing values when no args', () {
      final state = DescribeState.idle.withDescription(testImage, 'Desc.');
      final copied = state.copyWith();
      expect(copied.phase, state.phase);
      expect(copied.imageData, state.imageData);
      expect(copied.description, state.description);
      expect(copied.isOffline, state.isOffline);
    });

    test('copyWith overrides specified values', () {
      final state = DescribeState.idle.withDescription(testImage, 'Desc.');
      final copied = state.copyWith(isOffline: true, phase: DescribePhase.completed);
      expect(copied.phase, DescribePhase.completed);
      expect(copied.isOffline, isTrue);
      expect(copied.description, 'Desc.');
    });
  });
}
