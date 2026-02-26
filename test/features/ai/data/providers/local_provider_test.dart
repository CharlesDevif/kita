import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/gemini_nano_bridge.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';
import 'package:kita/features/ai/data/providers/ml_kit_bridge.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

/// Mock MlKitBridge for unit tests — no native dependencies needed.
class MockMlKitBridge implements MlKitBridge {
  MlKitVisionResult? resultToReturn;
  Exception? errorToThrow;
  bool disposeCalled = false;
  int analyzeCallCount = 0;
  Uint8List? lastBytes;
  int? lastWidth;
  int? lastHeight;

  @override
  Future<MlKitVisionResult> analyzeImage(
    Uint8List bytes, {
    int? width,
    int? height,
  }) async {
    analyzeCallCount++;
    lastBytes = bytes;
    lastWidth = width;
    lastHeight = height;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    return resultToReturn ??
        const MlKitVisionResult(recognizedText: '', labels: []);
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}

/// Mock GeminiNanoBridge for unit tests.
class MockGeminiNanoBridge implements GeminiNanoBridge {
  GeminiNanoStatus statusToReturn = GeminiNanoStatus.unavailable;
  GeminiNanoDescriptionResult? descriptionToReturn;
  Exception? errorToThrow;
  bool downloadModelCalled = false;
  bool disposeCalled = false;
  int describeCallCount = 0;

  @override
  Future<GeminiNanoStatus> checkAvailability() async {
    return statusToReturn;
  }

  @override
  Future<bool> downloadModel() async {
    downloadModelCalled = true;
    return statusToReturn == GeminiNanoStatus.available;
  }

  @override
  Future<GeminiNanoDescriptionResult> describeImage(Uint8List bytes) async {
    describeCallCount++;

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
  group('LocalProvider — Android (ML Kit)', () {
    late LocalProvider provider;
    late MockMlKitBridge mockBridge;

    setUp(() {
      mockBridge = MockMlKitBridge();
      provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockBridge,
      );
    });

    test('has correct id and displayName for Android', () {
      expect(provider.id, equals('mlkit'));
      expect(provider.displayName, equals('ML Kit (Android)'));
    });

    test('tier is local', () {
      expect(provider.tier, equals(ProviderTier.local));
    });

    test('isAvailable is true on Android', () {
      expect(provider.isAvailable, isTrue);
    });

    test('complete returns degraded response', () async {
      final result = await provider.complete(
        const AIRequest(
          prompt: 'describe something',
          priority: RequestPriority.critical,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.status, equals(AIResponseStatus.degraded));
      expect(response.meta.providerId, equals('mlkit'));
      expect(response.meta.tier, equals(ProviderTier.local));
    });

    test('complete detects obstacle keywords', () async {
      final result = await provider.complete(
        const AIRequest(
          prompt: 'obstacle devant',
          priority: RequestPriority.critical,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Attention'));
      expect(response.content, contains('Obstacle'));
    });

    test('complete detects text/read keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'lis ce texte'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Texte'));
    });

    test('complete detects time keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'quelle heure est-il'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('heure'));
    });

    test('complete detects help keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'aide moi'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('hors-ligne'));
      expect(response.content, contains('obstacles'));
    });

    test('complete detects navigation keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'ou est la sortie'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Navigation'));
    });

    test('complete detects describe/image keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'decris cette photo'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('camera'));
    });

    test('complete returns generic response for unknown prompt', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'random query xyz'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('locale limitee'));
    });

    test('validateApiKey always succeeds (no key needed)', () async {
      final result = await provider.validateApiKey('anything');
      expect(result.isSuccess, isTrue);
    });
  });

  group('LocalProvider — vision with ML Kit', () {
    late LocalProvider provider;
    late MockMlKitBridge mockBridge;
    late MockGeminiNanoBridge mockNanoUnavailable;

    setUp(() {
      mockBridge = MockMlKitBridge();
      mockNanoUnavailable = MockGeminiNanoBridge()
        ..statusToReturn = GeminiNanoStatus.unavailable;
      provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockBridge,
        geminiNanoBridge: mockNanoUnavailable,
      );
    });

    test('vision calls bridge with image bytes and dimensions', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [],
      );

      await provider.vision(
        ImageData(bytes: bytes, width: 320, height: 240),
        'describe',
      );

      expect(mockBridge.analyzeCallCount, equals(1));
      expect(mockBridge.lastBytes, same(bytes));
      expect(mockBridge.lastWidth, equals(320));
      expect(mockBridge.lastHeight, equals(240));
    });

    test('vision returns labels in French', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [
          MlKitLabel(label: 'Person', confidence: 0.95),
          MlKitLabel(label: 'Table', confidence: 0.85),
          MlKitLabel(label: 'Chair', confidence: 0.70),
        ],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Je vois'));
      expect(response.content, contains('personne'));
      expect(response.content, contains('table'));
      expect(response.content, contains('chaise'));
      expect(response.status, equals(AIResponseStatus.degraded));
      expect(response.meta.providerId, equals('mlkit'));
    });

    test('vision returns OCR text when available', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: 'Rue de la Paix',
        labels: [],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'read text',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Texte detecte'));
      expect(response.content, contains('Rue de la Paix'));
    });

    test('vision combines labels and OCR text', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: 'STOP',
        labels: [
          MlKitLabel(label: 'Sign', confidence: 0.90),
        ],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'what do you see',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Je vois'));
      expect(response.content, contains('panneau'));
      expect(response.content, contains('Texte detecte'));
      expect(response.content, contains('STOP'));
    });

    test('vision returns message when nothing detected', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('aucun element reconnu'));
    });

    test('vision limits labels to 5 maximum', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [
          MlKitLabel(label: 'Person', confidence: 0.95),
          MlKitLabel(label: 'Table', confidence: 0.90),
          MlKitLabel(label: 'Chair', confidence: 0.85),
          MlKitLabel(label: 'Dog', confidence: 0.80),
          MlKitLabel(label: 'Cat', confidence: 0.75),
          MlKitLabel(label: 'Book', confidence: 0.70),
          MlKitLabel(label: 'Bottle', confidence: 0.65),
        ],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      // Should contain first 5 but not the 6th/7th
      expect(response.content, contains('personne'));
      expect(response.content, contains('chat'));
      expect(response.content, isNot(contains('livre')));
      expect(response.content, isNot(contains('bouteille')));
    });

    test('vision translates unknown labels to lowercase', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [
          MlKitLabel(label: 'CustomObject', confidence: 0.80),
        ],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('customobject'));
    });

    test('vision returns failure when ML Kit throws', () async {
      mockBridge.errorToThrow = Exception('ML Kit crashed');

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<AIProviderFailure>());
      expect(failure.userMessage, contains('echouee'));
    });

    test('vision includes latency in response meta', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: 'Hello',
        labels: [],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'read',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.latency.inMicroseconds, greaterThanOrEqualTo(0));
      expect(response.meta.tier, equals(ProviderTier.local));
    });
  });

  group('LocalProvider — Gemini Nano integration', () {
    late LocalProvider provider;
    late MockMlKitBridge mockMlKit;
    late MockGeminiNanoBridge mockNano;

    setUp(() {
      mockMlKit = MockMlKitBridge();
      mockNano = MockGeminiNanoBridge();
      provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockMlKit,
        geminiNanoBridge: mockNano,
      );
    });

    test('vision uses Gemini Nano when available', () async {
      mockNano.statusToReturn = GeminiNanoStatus.available;
      mockNano.descriptionToReturn = const GeminiNanoDescriptionResult(
        description: 'A woman sitting at a wooden table with a laptop and a coffee cup.',
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('woman sitting'));
      expect(response.content, contains('laptop'));
      expect(response.meta.providerId, equals('gemini-nano'));
      expect(response.meta.tier, equals(ProviderTier.local));
      // ML Kit should NOT have been called
      expect(mockMlKit.analyzeCallCount, equals(0));
      // Gemini Nano should have been called
      expect(mockNano.describeCallCount, equals(1));
    });

    test('vision falls back to ML Kit when Gemini Nano unavailable', () async {
      mockNano.statusToReturn = GeminiNanoStatus.unavailable;
      mockMlKit.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [
          MlKitLabel(label: 'Person', confidence: 0.9),
        ],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('personne'));
      expect(response.meta.providerId, equals('mlkit'));
      // Gemini Nano was checked but not used
      expect(mockNano.describeCallCount, equals(0));
      // ML Kit was used
      expect(mockMlKit.analyzeCallCount, equals(1));
    });

    test('vision falls back to ML Kit when Gemini Nano throws', () async {
      mockNano.statusToReturn = GeminiNanoStatus.available;
      mockNano.errorToThrow = Exception('Gemini Nano crashed');
      mockMlKit.resultToReturn = const MlKitVisionResult(
        recognizedText: 'Bonjour',
        labels: [],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Bonjour'));
      expect(response.meta.providerId, equals('mlkit'));
      // Both were tried
      expect(mockNano.describeCallCount, equals(1));
      expect(mockMlKit.analyzeCallCount, equals(1));
    });

    test('vision caches Gemini Nano availability', () async {
      mockNano.statusToReturn = GeminiNanoStatus.available;
      mockNano.descriptionToReturn = const GeminiNanoDescriptionResult(
        description: 'A street scene.',
      );

      // First call
      await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );
      // Second call — should use cached status
      await provider.vision(
        ImageData(bytes: Uint8List.fromList([4, 5, 6])),
        'describe again',
      );

      expect(mockNano.describeCallCount, equals(2));
    });

    test('vision falls back to ML Kit when Gemini Nano is downloading', () async {
      mockNano.statusToReturn = GeminiNanoStatus.downloading;
      mockMlKit.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [MlKitLabel(label: 'Cat', confidence: 0.8)],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('chat'));
      expect(mockNano.describeCallCount, equals(0));
      expect(mockMlKit.analyzeCallCount, equals(1));
    });

    test('Gemini Nano is NOT tried on iOS', () async {
      final iosProvider = LocalProvider(
        platform: TargetPlatform.iOS,
        mlKitBridge: mockMlKit,
        geminiNanoBridge: mockNano,
      );

      mockNano.statusToReturn = GeminiNanoStatus.available;
      mockNano.descriptionToReturn = const GeminiNanoDescriptionResult(
        description: 'Should not be used on iOS.',
      );
      mockMlKit.resultToReturn = const MlKitVisionResult(
        recognizedText: '',
        labels: [MlKitLabel(label: 'Dog', confidence: 0.9)],
      );

      final result = await iosProvider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('chien'));
      expect(response.meta.providerId, equals('coreml'));
      // Gemini Nano must NOT have been called on iOS
      expect(mockNano.describeCallCount, equals(0));
      expect(mockMlKit.analyzeCallCount, equals(1));
    });
  });

  group('LocalProvider — lifecycle', () {
    late MockMlKitBridge mockBridge;

    test('dispose releases bridge resources', () async {
      mockBridge = MockMlKitBridge();
      final provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockBridge,
      );

      await provider.dispose();
      expect(mockBridge.disposeCalled, isTrue);
    });

    test('dispose releases both bridges', () async {
      mockBridge = MockMlKitBridge();
      final mockNano = MockGeminiNanoBridge();
      final provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockBridge,
        geminiNanoBridge: mockNano,
      );

      await provider.dispose();
      expect(mockBridge.disposeCalled, isTrue);
      expect(mockNano.disposeCalled, isTrue);
    });

    test('dispose is safe to call multiple times', () async {
      mockBridge = MockMlKitBridge();
      final provider = LocalProvider(
        platform: TargetPlatform.android,
        mlKitBridge: mockBridge,
      );

      await provider.dispose();
      await provider.dispose(); // Should not throw
      expect(mockBridge.disposeCalled, isTrue);
    });
  });

  group('LocalProvider — iOS (CoreML)', () {
    late LocalProvider provider;
    late MockMlKitBridge mockBridge;

    setUp(() {
      mockBridge = MockMlKitBridge();
      provider = LocalProvider(
        platform: TargetPlatform.iOS,
        mlKitBridge: mockBridge,
      );
    });

    test('has correct id and displayName for iOS', () {
      expect(provider.id, equals('coreml'));
      expect(provider.displayName, equals('CoreML (iOS)'));
    });

    test('isAvailable is true on iOS', () {
      expect(provider.isAvailable, isTrue);
    });

    test('complete works on iOS', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'test'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('coreml'));
    });

    test('vision works on iOS via bridge', () async {
      mockBridge.resultToReturn = const MlKitVisionResult(
        recognizedText: 'Bonjour',
        labels: [MlKitLabel(label: 'Person', confidence: 0.9)],
      );

      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('personne'));
      expect(response.content, contains('Bonjour'));
      expect(response.meta.providerId, equals('coreml'));
    });
  });

  group('LocalProvider — unsupported platform', () {
    late LocalProvider provider;

    setUp(() {
      provider = LocalProvider(platform: TargetPlatform.linux);
    });

    test('has fallback id on unsupported platform', () {
      expect(provider.id, equals('local-fallback'));
    });

    test('isAvailable is false on unsupported platform', () {
      expect(provider.isAvailable, isFalse);
    });

    test('complete returns failure on unsupported platform', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'test'),
      );

      expect(result.isFailure, isTrue);
    });

    test('vision returns failure on unsupported platform', () async {
      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'test',
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('performance', () {
    test('complete returns in < 50ms', () async {
      final provider = LocalProvider(
        platform: TargetPlatform.android,
        geminiNanoBridge: MockGeminiNanoBridge(),
      );
      final sw = Stopwatch()..start();
      await provider.complete(
        const AIRequest(
          prompt: 'obstacle devant',
          priority: RequestPriority.critical,
        ),
      );
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('MlKitVisionResult', () {
    test('holds recognized text and labels', () {
      const result = MlKitVisionResult(
        recognizedText: 'Hello World',
        labels: [
          MlKitLabel(label: 'Text', confidence: 0.99),
        ],
      );

      expect(result.recognizedText, equals('Hello World'));
      expect(result.labels, hasLength(1));
      expect(result.labels.first.label, equals('Text'));
      expect(result.labels.first.confidence, equals(0.99));
    });
  });
}
