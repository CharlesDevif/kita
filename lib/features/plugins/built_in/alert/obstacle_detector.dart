import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../../ai/domain/image_data.dart';
import 'detection.dart';
import 'detection_postprocessor.dart';
import 'frame_preprocessor.dart';

/// Detects obstacles in camera frames using a YOLOv8 nano TFLite model.
///
/// Runs inference on a dedicated [IsolateInterpreter] to avoid blocking
/// the UI thread. Preprocessing and post-processing happen in the main
/// isolate, which is acceptable for < 15ms overhead.
class ObstacleDetector {
  ObstacleDetector({
    String modelPath = 'assets/models/yolo_v8_nano.tflite',
    FramePreprocessor? preprocessor,
    DetectionPostprocessor? postprocessor,
  })  : _modelPath = modelPath,
        _preprocessor = preprocessor ?? const FramePreprocessor(),
        _postprocessor = postprocessor ?? const DetectionPostprocessor();

  final String _modelPath;
  final FramePreprocessor _preprocessor;
  final DetectionPostprocessor _postprocessor;
  static final _log = KitaLogger('Alert');

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  bool _initialized = false;
  bool _processing = false;

  // Pre-allocated buffers to reduce GC pressure
  Float32List? _inputBuffer;
  List<List<List<double>>>? _outputBuffer;

  bool get isInitialized => _initialized;

  /// Load the TFLite model and create the isolate interpreter.
  ///
  /// Returns [Result.failure] if the model file is not found or invalid.
  Future<Result<void>> initialize() async {
    if (_initialized) {
      return const Result.success(null);
    }

    try {
      final options = _createOptions();
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );

      // Pre-allocate buffers
      _inputBuffer = Float32List(1 * 640 * 640 * 3);
      _outputBuffer = List.generate(
        1,
        (_) => List.generate(84, (_) => List.filled(8400, 0.0)),
      );

      _initialized = true;
      _log.info('Model loaded from $_modelPath');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Failed to load model', error: e, stackTrace: stack);
      return Result.failure(AIProviderFailure(
        userMessage: 'Le modele de detection est indisponible.',
        logMessage: 'ObstacleDetector init failed: $e',
        providerId: 'tflite-yolo',
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  /// Detect obstacles in a camera frame.
  ///
  /// Returns a list of [Detection]s with confidence > threshold.
  /// The frame's pixel format is inferred from the platform.
  Future<Result<List<Detection>>> detect(ImageData frame) async {
    if (!_initialized || _isolateInterpreter == null) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'Le detecteur n est pas initialise.',
        logMessage: 'ObstacleDetector.detect called before initialize',
        providerId: 'tflite-yolo',
      ));
    }

    // Guard against concurrent access to shared buffers (_inputBuffer,
    // _outputBuffer). At 15+ FPS, overlapping detect() calls would corrupt
    // the pre-allocated buffers. We skip the frame instead of queuing.
    if (_processing) {
      _log.debug('Frame skipped: inference already in progress');
      return const Result.success([]);
    }
    _processing = true;

    try {
      final stopwatch = Stopwatch()..start();

      // Determine pixel format from platform
      final pixelFormat = _resolvePixelFormat(frame);

      // Preprocess into pre-allocated buffer
      _preprocessor.preprocessFrameInto(
        frame,
        pixelFormat: pixelFormat,
        buffer: _inputBuffer!,
      );

      // Reset output buffer
      _resetOutputBuffer();

      // Run inference on isolate
      await _isolateInterpreter!.run(
        _inputBuffer!.reshape([1, 640, 640, 3]),
        _outputBuffer!,
      );

      // Post-process
      final detections = _postprocessor.postprocess(_outputBuffer!);

      stopwatch.stop();
      _log.debug(
        'Detection completed in ${stopwatch.elapsedMilliseconds}ms, '
        '${detections.length} obstacles found',
      );

      return Result.success(detections);
    } catch (e, stack) {
      _log.error('Inference failed', error: e, stackTrace: stack);
      return Result.failure(AIProviderFailure(
        userMessage: 'La detection a echoue.',
        logMessage: 'ObstacleDetector inference error: $e',
        providerId: 'tflite-yolo',
        cause: e,
        stackTrace: stack,
      ));
    } finally {
      _processing = false;
    }
  }

  /// Release all resources.
  Future<void> dispose() async {
    if (_isolateInterpreter != null) {
      await _isolateInterpreter!.close();
      _isolateInterpreter = null;
    }
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
    _inputBuffer = null;
    _outputBuffer = null;
    _processing = false;
    _initialized = false;
    _log.info('ObstacleDetector disposed');
  }

  String _resolvePixelFormat(ImageData frame) {
    if (frame.mimeType == 'image/yuv420') return 'yuv420';
    if (frame.mimeType == 'image/bgra8888') return 'bgra8888';
    // Fallback: infer from platform
    if (Platform.isAndroid) return 'yuv420';
    if (Platform.isIOS) return 'bgra8888';
    return 'rgb';
  }

  InterpreterOptions _createOptions() {
    if (Platform.isAndroid) {
      return InterpreterOptions()..addDelegate(GpuDelegateV2());
    } else if (Platform.isIOS) {
      return InterpreterOptions()..addDelegate(CoreMlDelegate());
    }
    return InterpreterOptions();
  }

  void _resetOutputBuffer() {
    if (_outputBuffer == null) return;
    for (int i = 0; i < 84; i++) {
      for (int j = 0; j < 8400; j++) {
        _outputBuffer![0][i][j] = 0.0;
      }
    }
  }
}
