import '../../../core/utils/logger.dart';
import '../domain/camera_service.dart';
import '../domain/motion_service.dart';

/// Target FPS settings for each motion state.
class FpsConfig {
  const FpsConfig({
    required this.immobileFps,
    required this.walkingFps,
    required this.runningFps,
  });

  /// Default configuration matching the < 5%/h battery target.
  static const standard = FpsConfig(
    immobileFps: 0, // camera OFF
    walkingFps: 15,
    runningFps: 30,
  );

  /// Low battery configuration (camera always OFF).
  static const lowBattery = FpsConfig(
    immobileFps: 0,
    walkingFps: 0,
    runningFps: 0,
  );

  final int immobileFps;
  final int walkingFps;
  final int runningFps;

  int fpsForState(MotionState state) => switch (state) {
        MotionState.immobile => immobileFps,
        MotionState.walking => walkingFps,
        MotionState.running => runningFps,
      };
}

/// Controls camera streaming with adaptive FPS based on motion state.
///
/// Uses a temporal gate to limit frame processing rate — the camera
/// package does not support direct FPS configuration on CameraX.
/// Includes a `_processing` guard to prevent concurrent ML inference.
class AdaptiveSensorController {
  AdaptiveSensorController({
    required CameraService cameraService,
    FpsConfig fpsConfig = FpsConfig.standard,
  })  : _camera = cameraService,
        _fpsConfig = fpsConfig;

  static final _log = KitaLogger('PassiveMode');

  final CameraService _camera;
  FpsConfig _fpsConfig;

  int _targetFps = 0;
  int _lastFrameMs = 0;
  bool _processing = false;
  bool _cameraActive = false;
  void Function(dynamic frame)? _frameHandler;

  /// Whether the camera stream is currently active.
  bool get isCameraActive => _cameraActive;

  /// Current target FPS (0 = camera OFF).
  int get targetFps => _targetFps;

  /// Whether a frame is currently being processed.
  bool get isProcessing => _processing;

  /// Update the FPS configuration (e.g., switch to low battery mode).
  void updateConfig(FpsConfig config) {
    _fpsConfig = config;
  }

  /// Adapt sensor activity based on the current motion state.
  ///
  /// Adjusts the camera FPS or turns the camera off.
  Future<void> adaptToMotion(MotionState state) async {
    final newFps = _fpsConfig.fpsForState(state);

    if (newFps == _targetFps) return;

    final oldFps = _targetFps;
    _targetFps = newFps;

    if (newFps == 0 && _cameraActive) {
      await _stopCamera();
      _log.info('Camera stopped (motion: ${state.name})');
    } else if (newFps > 0 && !_cameraActive) {
      await _startCamera();
      _log.info('Camera started at $newFps FPS (motion: ${state.name})');
    } else if (newFps > 0 && oldFps > 0) {
      _log.debug('Camera FPS changed: $oldFps -> $newFps');
    }
  }

  /// Register a frame handler for processed frames that pass the FPS gate.
  void setFrameHandler(void Function(dynamic frame) handler) {
    _frameHandler = handler;
  }

  /// Stop the camera and release resources.
  Future<void> dispose() async {
    _frameHandler = null;
    if (_cameraActive) {
      await _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_cameraActive) return;

    final result = await _camera.startStream(_onImageAvailable);
    if (result.isSuccess) {
      _cameraActive = true;
    } else {
      _log.warning('Camera stream start failed');
    }
  }

  Future<void> _stopCamera() async {
    if (!_cameraActive) return;

    final result = await _camera.stopStream();
    if (result.isSuccess) {
      _cameraActive = false;
      _processing = false;
    }
  }

  void _onImageAvailable(dynamic image) {
    if (_targetFps == 0) return;

    // Temporal gate: skip frames that arrive faster than target FPS
    final now = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = 1000 ~/ _targetFps;
    if (now - _lastFrameMs < intervalMs) return;
    _lastFrameMs = now;

    // Concurrent processing guard
    if (_processing) return;
    _processing = true;

    final handler = _frameHandler;
    if (handler != null) {
      // The handler MUST call markProcessingComplete() when done.
      handler(image);
    } else {
      // No handler registered — release the guard immediately.
      _processing = false;
    }
  }

  /// Mark the current frame processing as complete.
  /// Call this from async frame handlers.
  void markProcessingComplete() {
    _processing = false;
  }
}
