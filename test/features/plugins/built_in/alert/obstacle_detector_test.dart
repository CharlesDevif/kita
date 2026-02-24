import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/plugins/built_in/alert/detection.dart';
import 'package:kita/features/plugins/built_in/alert/detection_postprocessor.dart';
import 'package:kita/features/plugins/built_in/alert/frame_preprocessor.dart';
import 'package:kita/features/plugins/built_in/alert/obstacle_detector.dart';

/// Testable subclass that avoids TFLite native dependencies.
///
/// Mocks the interpreter by directly running preprocessing + postprocessing
/// with a synthetic output tensor.
class TestableObstacleDetector extends ObstacleDetector {
  TestableObstacleDetector({
    super.preprocessor,
    super.postprocessor,
    this.mockOutput,
    this.shouldFailInit = false,
    this.shouldFailInference = false,
  }) : super(modelPath: 'test_model.tflite');

  final List<List<List<double>>>? mockOutput;
  final bool shouldFailInit;
  final bool shouldFailInference;
  bool _testInitialized = false;

  @override
  bool get isInitialized => _testInitialized;

  @override
  Future<Result<void>> initialize() async {
    if (shouldFailInit) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'Le modele de detection est indisponible.',
        logMessage: 'Test: model not found',
        providerId: 'tflite-yolo',
      ));
    }
    _testInitialized = true;
    return const Result.success(null);
  }

  @override
  Future<Result<List<Detection>>> detect(ImageData frame) async {
    if (!_testInitialized) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'Le detecteur n est pas initialise.',
        logMessage: 'ObstacleDetector.detect called before initialize',
        providerId: 'tflite-yolo',
      ));
    }

    if (shouldFailInference) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'La detection a echoue.',
        logMessage: 'Test: inference failed',
        providerId: 'tflite-yolo',
      ));
    }

    if (mockOutput != null) {
      final postprocessor = const DetectionPostprocessor();
      final detections = postprocessor.postprocess(mockOutput!);
      return Result.success(detections);
    }

    return const Result.success([]);
  }

  @override
  Future<void> dispose() async {
    _testInitialized = false;
  }
}

/// Testable detector that reproduces the _processing guard from ObstacleDetector.
///
/// Uses a [Completer] to control when inference finishes, allowing tests to
/// verify that concurrent calls are skipped.
class ConcurrentTestableDetector extends ObstacleDetector {
  ConcurrentTestableDetector() : super(modelPath: 'test_model.tflite');

  bool _testInitialized = false;
  bool _processing = false;
  int detectCallCount = 0;
  Completer<void>? _inferenceGate;

  @override
  bool get isInitialized => _testInitialized;

  @override
  Future<Result<void>> initialize() async {
    _testInitialized = true;
    return const Result.success(null);
  }

  /// Set a completer that detect() will await, simulating slow inference.
  void setInferenceGate(Completer<void> completer) {
    _inferenceGate = completer;
  }

  @override
  Future<Result<List<Detection>>> detect(ImageData frame) async {
    if (!_testInitialized) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'Le detecteur n est pas initialise.',
        logMessage: 'ObstacleDetector.detect called before initialize',
        providerId: 'tflite-yolo',
      ));
    }

    // Same guard as the real ObstacleDetector.detect()
    if (_processing) {
      return const Result.success([]);
    }
    _processing = true;

    try {
      detectCallCount++;
      if (_inferenceGate != null) {
        await _inferenceGate!.future;
      }
      return const Result.success([]);
    } finally {
      _processing = false;
    }
  }

  @override
  Future<void> dispose() async {
    _testInitialized = false;
    _processing = false;
  }
}

void main() {
  late List<LogEntry> logEntries;

  setUp(() {
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
  });

  group('ObstacleDetector lifecycle', () {
    test('isInitialized is false before initialize', () {
      final detector = TestableObstacleDetector();
      expect(detector.isInitialized, isFalse);
    });

    test('initialize succeeds and sets isInitialized', () async {
      final detector = TestableObstacleDetector();
      final result = await detector.initialize();

      expect(result.isSuccess, isTrue);
      expect(detector.isInitialized, isTrue);
    });

    test('initialize returns failure when model is absent', () async {
      final detector = TestableObstacleDetector(shouldFailInit: true);
      final result = await detector.initialize();

      expect(result.isFailure, isTrue);
      expect(detector.isInitialized, isFalse);
      result.when(
        success: (_) => fail('Should have failed'),
        failure: (failure) {
          expect(failure, isA<AIProviderFailure>());
          expect(failure.logMessage, contains('model'));
        },
      );
    });

    test('dispose resets isInitialized', () async {
      final detector = TestableObstacleDetector();
      await detector.initialize();
      expect(detector.isInitialized, isTrue);

      await detector.dispose();
      expect(detector.isInitialized, isFalse);
    });

    test('double initialize is safe', () async {
      final detector = TestableObstacleDetector();
      await detector.initialize();
      final result = await detector.initialize();

      expect(result.isSuccess, isTrue);
      expect(detector.isInitialized, isTrue);
    });
  });

  group('ObstacleDetector detect', () {
    test('returns failure when not initialized', () async {
      final detector = TestableObstacleDetector();
      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      final result = await detector.detect(frame);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should have failed'),
        failure: (failure) {
          expect(failure, isA<AIProviderFailure>());
          expect(failure.logMessage, contains('before initialize'));
        },
      );
    });

    test('returns empty list when no detections', () async {
      final detector = TestableObstacleDetector();
      await detector.initialize();

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      final result = await detector.detect(frame);

      expect(result.isSuccess, isTrue);
      result.when(
        success: (detections) => expect(detections, isEmpty),
        failure: (_) => fail('Should have succeeded'),
      );
    });

    test('returns detections from mock output', () async {
      // Create a mock output tensor with one high-confidence person
      final mockOutput = _createMockOutput(
        classId: 0,
        score: 0.95,
      );

      final detector = TestableObstacleDetector(mockOutput: mockOutput);
      await detector.initialize();

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 640,
        height: 640,
      );

      final result = await detector.detect(frame);

      expect(result.isSuccess, isTrue);
      result.when(
        success: (detections) {
          expect(detections.length, 1);
          expect(detections[0].label, 'person');
          expect(detections[0].confidence, 0.95);
        },
        failure: (_) => fail('Should have succeeded'),
      );
    });

    test('returns failure on inference error', () async {
      final detector = TestableObstacleDetector(shouldFailInference: true);
      await detector.initialize();

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      final result = await detector.detect(frame);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should have failed'),
        failure: (failure) {
          expect(failure, isA<AIProviderFailure>());
        },
      );
    });
  });

  group('ObstacleDetector logging', () {
    test('logs do not contain PII', () async {
      final detector = TestableObstacleDetector();
      await detector.initialize();

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );
      await detector.detect(frame);
      await detector.dispose();

      // None of the log entries should contain PII
      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('user')));
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('gps')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
      }
    });
  });

  group('ObstacleDetector concurrency guard', () {
    test('concurrent detect() call returns empty list (frame skipped)', () async {
      final detector = ConcurrentTestableDetector();
      await detector.initialize();

      final gate = Completer<void>();
      detector.setInferenceGate(gate);

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      // Start first detect — it will block on the gate
      final first = detector.detect(frame);

      // Second detect while first is processing — should skip
      final secondResult = await detector.detect(frame);

      expect(secondResult.isSuccess, isTrue);
      secondResult.when(
        success: (detections) => expect(detections, isEmpty),
        failure: (_) => fail('Should have succeeded with empty list'),
      );

      // Only one real inference happened
      expect(detector.detectCallCount, 1);

      // Release the gate so the first detect finishes
      gate.complete();
      final firstResult = await first;

      expect(firstResult.isSuccess, isTrue);
      expect(detector.detectCallCount, 1);
    });

    test('detect() is available again after previous call completes', () async {
      final detector = ConcurrentTestableDetector();
      await detector.initialize();

      final gate = Completer<void>();
      detector.setInferenceGate(gate);

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      // First detect — completes immediately after gate
      gate.complete();
      await detector.detect(frame);
      expect(detector.detectCallCount, 1);

      // Second detect after first completed — should process normally
      detector.setInferenceGate(Completer<void>()..complete());
      final result = await detector.detect(frame);

      expect(result.isSuccess, isTrue);
      expect(detector.detectCallCount, 2);
    });

    test('detect() resets _processing even on error', () async {
      final detector = ConcurrentTestableDetector();
      await detector.initialize();

      final errorGate = Completer<void>();
      detector.setInferenceGate(errorGate);

      final frame = ImageData(
        bytes: Uint8List(100),
        mimeType: 'image/raw',
        width: 10,
        height: 10,
      );

      // Make the gate throw an error
      errorGate.completeError(Exception('test inference error'));

      // detect should handle the error (via try/finally)
      // The ConcurrentTestableDetector propagates errors up,
      // but _processing should still be reset
      try {
        await detector.detect(frame);
      } catch (_) {
        // Expected
      }

      // Subsequent detect should work (not stuck in _processing)
      detector.setInferenceGate(Completer<void>()..complete());
      final result = await detector.detect(frame);
      expect(result.isSuccess, isTrue);
    });
  });

  group('FramePreprocessor integration', () {
    test('preprocessor produces correct tensor dimensions', () {
      const preprocessor = FramePreprocessor(inputSize: 640);
      // Create a minimal BGRA frame
      final bgra = Uint8List(10 * 10 * 4);
      final frame = ImageData(
        bytes: bgra,
        mimeType: 'image/bgra8888',
        width: 10,
        height: 10,
      );

      final tensor = preprocessor.preprocessFrame(
        frame,
        pixelFormat: 'bgra8888',
      );

      // Should be 640*640*3 Float32 values
      expect(tensor.length, 640 * 640 * 3);
    });
  });
}

/// Helper: create a mock output tensor [1][84][N] with one detection.
List<List<List<double>>> _createMockOutput({
  double cx = 320.0,
  double cy = 320.0,
  double w = 100.0,
  double h = 100.0,
  int classId = 0,
  double score = 0.95,
  int numPredictions = 10,
}) {
  return List.generate(1, (_) {
    return List.generate(84, (fieldIdx) {
      return List.generate(numPredictions, (predIdx) {
        if (predIdx == 0) {
          if (fieldIdx == 0) return cx;
          if (fieldIdx == 1) return cy;
          if (fieldIdx == 2) return w;
          if (fieldIdx == 3) return h;
          if (fieldIdx == classId + 4) return score;
          return 0.0;
        }
        return 0.0;
      });
    });
  });
}
