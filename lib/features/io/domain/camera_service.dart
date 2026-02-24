import '../../../core/errors/result.dart';
import '../../ai/domain/image_data.dart';

abstract interface class CameraService {
  bool get isAvailable;
  Future<Result<ImageData>> capturePhoto();
  Future<Result<void>> startStream(void Function(ImageData frame) onFrame);
  Future<Result<void>> stopStream();
}
