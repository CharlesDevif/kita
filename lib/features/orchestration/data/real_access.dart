import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_response.dart';
import '../../ai/domain/ai_router.dart';
import '../../ai/domain/image_data.dart';
import '../../io/domain/camera_service.dart';
import '../../io/domain/location_service.dart';
import '../../io/domain/motion_service.dart';
import '../../plugins/domain/ai_access.dart';
import '../../plugins/domain/sensor_access.dart';

/// Real [SensorAccess] that delegates to actual device services.
///
/// Wraps [CameraService], [LocationService], and [MotionService] to provide
/// real sensor data to plugins via the sandbox.
class RealSensorAccess implements SensorAccess {
  RealSensorAccess({
    required CameraService cameraService,
    required LocationService locationService,
    required MotionService motionService,
  })  : _camera = cameraService,
        _location = locationService,
        _motion = motionService;

  static final _log = KitaLogger('Orchestration.SensorAccess');

  final CameraService _camera;
  final LocationService _location;
  final MotionService _motion;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    _log.debug('Capturing photo via real camera service');
    return _camera.capturePhoto();
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    _log.debug('Getting position via real location service');
    return _location.getCurrentPosition();
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    _log.debug('Getting motion state via real motion service');
    return Result.success(_motion.currentState);
  }
}

/// Real [AIAccess] that delegates to the [AIRouter] fallback chain.
///
/// Routes AI requests through the full provider hierarchy
/// (cloud powerful -> cloud fast -> local) with timeout and fallback.
class RealAIAccess implements AIAccess {
  RealAIAccess({required AIRouter aiRouter}) : _router = aiRouter;

  static final _log = KitaLogger('Orchestration.AIAccess');

  final AIRouter _router;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    _log.debug('Routing AI complete request via real router');
    return _router.route(request);
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    _log.debug('Routing AI vision request via real router');
    return _router.route(AIRequest(
      prompt: prompt,
      imageData: image,
    ));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt) {
    _log.debug('Routing AI vision stream request via real router');
    return _router.routeVisionStream(image, prompt);
  }
}
