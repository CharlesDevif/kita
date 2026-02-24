import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/image_data.dart';
import '../domain/camera_service.dart';

/// Implementation of [CameraService] using the `camera` Flutter package.
///
/// Provides photo capture and throttled video streaming from the rear camera.
/// Handles lifecycle (init/dispose) and error mapping to [KitaFailure].
class CameraServiceImpl implements CameraService {
  CameraServiceImpl({
    this.streamFps = 15,
    CameraDescription? cameraDescription,
    CameraController? controller,
  })  : _cameraDescription = cameraDescription,
        _controller = controller;

  static final _log = KitaLogger('IO');

  /// Target FPS for the video stream. Frames exceeding this rate are dropped.
  final int streamFps;

  CameraDescription? _cameraDescription;
  CameraController? _controller;
  bool _isStreaming = false;
  bool _processingFrame = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get isAvailable => _controller?.value.isInitialized ?? false;

  /// Whether the camera is currently streaming frames.
  bool get isStreaming => _isStreaming;

  /// Lazily initializes the camera controller if not already done.
  ///
  /// Selects the rear camera by default. Returns a [PermissionFailure] if
  /// no cameras are available or initialization fails.
  Future<Result<void>> _ensureInitialized() async {
    if (_controller?.value.isInitialized == true) {
      return const Result.success(null);
    }

    try {
      if (_cameraDescription == null) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          _log.warning('No cameras available on device');
          return const Result.failure(
            PermissionFailure(
              userMessage: 'Aucune camera disponible.',
              logMessage: 'No cameras found on device',
              permission: 'camera',
            ),
          );
        }
        _cameraDescription = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      }

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      _log.info('Camera initialized: ${_cameraDescription!.name}');
      return const Result.success(null);
    } on CameraException catch (e, stack) {
      _log.error('Camera init failed: ${e.code}', error: e, stackTrace: stack);
      return Result.failure(_mapCameraException(e, stack));
    } catch (e, stack) {
      _log.error('Camera init unexpected error', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Camera initialization failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<ImageData>> capturePhoto() async {
    // Must stop streaming before taking a picture (hardware constraint).
    if (_isStreaming) {
      final stopResult = await stopStream();
      if (stopResult.isFailure) {
        return Result.failure((stopResult as Failure<void>).failure);
      }
    }

    final initResult = await _ensureInitialized();
    if (initResult.isFailure) {
      return Result.failure((initResult as Failure<void>).failure);
    }

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();

      _log.info('Photo captured: ${bytes.length} bytes');
      return Result.success(ImageData(
        bytes: Uint8List.fromList(bytes),
        mimeType: 'image/jpeg',
      ));
    } on CameraException catch (e, stack) {
      _log.error('Photo capture failed: ${e.code}', error: e, stackTrace: stack);
      return Result.failure(_mapCameraException(e, stack));
    } catch (e, stack) {
      _log.error('Photo capture unexpected error', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Photo capture failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> startStream(
    void Function(ImageData frame) onFrame,
  ) async {
    if (_isStreaming) {
      _log.warning('Stream already active, ignoring startStream');
      return const Result.success(null);
    }

    final initResult = await _ensureInitialized();
    if (initResult.isFailure) {
      return Result.failure((initResult as Failure<void>).failure);
    }

    try {
      final frameDuration = Duration(
        milliseconds: (1000 / streamFps).round(),
      );

      await _controller!.startImageStream((CameraImage image) {
        if (_processingFrame) return;
        final now = DateTime.now();
        if (now.difference(_lastFrameTime) < frameDuration) {
          return; // Throttle: skip frame
        }
        _processingFrame = true;
        _lastFrameTime = now;

        final imageData = _convertCameraImage(image);
        onFrame(imageData);
        _processingFrame = false;
      });

      _isStreaming = true;
      _log.info('Camera stream started at $streamFps FPS target');
      return const Result.success(null);
    } on CameraException catch (e, stack) {
      _log.error('Stream start failed: ${e.code}', error: e, stackTrace: stack);
      return Result.failure(_mapCameraException(e, stack));
    } catch (e, stack) {
      _log.error('Stream start unexpected error', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Stream start failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> stopStream() async {
    if (!_isStreaming) {
      return const Result.success(null);
    }

    try {
      if (_controller?.value.isStreamingImages == true) {
        await _controller!.stopImageStream();
      }
      _isStreaming = false;
      _log.info('Camera stream stopped');
      return const Result.success(null);
    } on CameraException catch (e, stack) {
      _log.error('Stream stop failed: ${e.code}', error: e, stackTrace: stack);
      _isStreaming = false;
      return Result.failure(_mapCameraException(e, stack));
    } catch (e, stack) {
      _log.error('Stream stop unexpected error', error: e, stackTrace: stack);
      _isStreaming = false;
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Stream stop failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Releases the camera controller and all native resources.
  Future<void> dispose() async {
    if (_isStreaming) {
      await stopStream();
    }
    await _controller?.dispose();
    _controller = null;
    _log.info('Camera disposed');
  }

  /// Converts a [CameraImage] to [ImageData] with raw plane bytes.
  ///
  /// For stream frames, we pass concatenated plane bytes rather than
  /// encoding to JPEG (which is CPU-intensive). ML models typically
  /// accept raw YUV/BGRA data directly.
  ImageData _convertCameraImage(CameraImage image) {
    // Concatenate all planes into a single byte buffer.
    int totalBytes = 0;
    for (final plane in image.planes) {
      totalBytes += plane.bytes.length;
    }

    final allBytes = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in image.planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    return ImageData(
      bytes: allBytes,
      mimeType: 'image/raw',
      width: image.width,
      height: image.height,
    );
  }

  /// Maps a [CameraException] to the appropriate [KitaFailure].
  KitaFailure _mapCameraException(CameraException e, StackTrace stack) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return PermissionFailure(
          userMessage: 'Permission camera refusee. Activez-la dans les reglages.',
          logMessage: 'Camera permission denied: ${e.code}',
          permission: 'camera',
          cause: e,
          stackTrace: stack,
        );
      case 'CameraNotFound':
        return PermissionFailure(
          userMessage: 'Camera non trouvee sur cet appareil.',
          logMessage: 'Camera not found: ${e.code}',
          permission: 'camera',
          cause: e,
          stackTrace: stack,
        );
      default:
        return UnexpectedFailure(
          logMessage: 'Camera error: ${e.code} - ${e.description}',
          cause: e,
          stackTrace: stack,
        );
    }
  }
}
