import 'dart:typed_data';

import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/io/domain/camera_service.dart';

class MockCameraService implements CameraService {
  bool shouldFail = false;

  @override
  bool get isAvailable => !shouldFail;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    if (shouldFail) {
      return Result.failure(
        PermissionFailure.denied('camera'),
      );
    }
    return Result.success(ImageData(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
      width: 640,
      height: 480,
    ));
  }

  @override
  Future<Result<void>> startStream(
    void Function(ImageData frame) onFrame,
  ) async {
    if (shouldFail) {
      return Result.failure(
        PermissionFailure.denied('camera'),
      );
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopStream() async {
    return const Result.success(null);
  }
}
