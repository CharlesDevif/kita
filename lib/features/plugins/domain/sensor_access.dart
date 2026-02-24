import '../../../core/errors/result.dart';
import '../../ai/domain/image_data.dart';
import '../../io/domain/location_service.dart';
import '../../io/domain/motion_service.dart';

abstract interface class SensorAccess {
  Future<Result<ImageData>> capturePhoto();
  Future<Result<Position>> getCurrentPosition();
  Future<Result<MotionState>> getMotionState();
}
