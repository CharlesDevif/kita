import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemini_nano_bridge.dart';

/// Mock GeminiNanoBridge for unit tests — no native dependencies.
class MockGeminiNanoBridge implements GeminiNanoBridge {
  GeminiNanoStatus statusToReturn = GeminiNanoStatus.unavailable;
  GeminiNanoDescriptionResult? descriptionToReturn;
  Exception? errorToThrow;
  bool downloadModelCalled = false;
  bool disposeCalled = false;
  int describeCallCount = 0;
  Uint8List? lastBytes;

  @override
  Future<GeminiNanoStatus> checkAvailability() async {
    return statusToReturn;
  }

  @override
  Future<bool> downloadModel() async {
    downloadModelCalled = true;
    return statusToReturn == GeminiNanoStatus.available ||
        statusToReturn == GeminiNanoStatus.downloadable;
  }

  @override
  Future<GeminiNanoDescriptionResult> describeImage(Uint8List bytes) async {
    describeCallCount++;
    lastBytes = bytes;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    return descriptionToReturn ??
        const GeminiNanoDescriptionResult(description: '');
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}

void main() {
  group('GeminiNanoStatus', () {
    test('has all expected values', () {
      expect(GeminiNanoStatus.values, hasLength(4));
      expect(GeminiNanoStatus.available.name, 'available');
      expect(GeminiNanoStatus.downloadable.name, 'downloadable');
      expect(GeminiNanoStatus.downloading.name, 'downloading');
      expect(GeminiNanoStatus.unavailable.name, 'unavailable');
    });
  });

  group('GeminiNanoDescriptionResult', () {
    test('stores description', () {
      const result = GeminiNanoDescriptionResult(
        description: 'A person sitting at a table with a laptop.',
      );
      expect(
        result.description,
        equals('A person sitting at a table with a laptop.'),
      );
    });
  });

  group('MockGeminiNanoBridge', () {
    late MockGeminiNanoBridge bridge;

    setUp(() {
      bridge = MockGeminiNanoBridge();
    });

    test('checkAvailability returns configured status', () async {
      bridge.statusToReturn = GeminiNanoStatus.available;
      expect(
        await bridge.checkAvailability(),
        equals(GeminiNanoStatus.available),
      );
    });

    test('describeImage returns configured result', () async {
      bridge.descriptionToReturn = const GeminiNanoDescriptionResult(
        description: 'A red car on a road.',
      );

      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await bridge.describeImage(bytes);

      expect(result.description, equals('A red car on a road.'));
      expect(bridge.describeCallCount, equals(1));
      expect(bridge.lastBytes, same(bytes));
    });

    test('describeImage throws configured error', () async {
      bridge.errorToThrow = Exception('Gemini Nano failed');

      expect(
        () => bridge.describeImage(Uint8List.fromList([1, 2, 3])),
        throwsException,
      );
    });

    test('dispose marks bridge as disposed', () async {
      await bridge.dispose();
      expect(bridge.disposeCalled, isTrue);
    });

    test('downloadModel returns true when available', () async {
      bridge.statusToReturn = GeminiNanoStatus.available;
      expect(await bridge.downloadModel(), isTrue);
      expect(bridge.downloadModelCalled, isTrue);
    });

    test('downloadModel returns false when unavailable', () async {
      bridge.statusToReturn = GeminiNanoStatus.unavailable;
      expect(await bridge.downloadModel(), isFalse);
    });
  });
}
