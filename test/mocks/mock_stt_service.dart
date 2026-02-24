import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/stt_service.dart';

class MockSTTService implements STTService {
  bool shouldFail = false;
  bool _isListening = false;

  @override
  bool get isAvailable => !shouldFail;

  @override
  bool get isListening => _isListening;

  @override
  Future<Result<void>> startRecognition({
    required STTResultCallback onResult,
  }) async {
    if (shouldFail) {
      return Result.failure(
        PermissionFailure.denied('microphone'),
      );
    }
    _isListening = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopRecognition() async {
    _isListening = false;
    return const Result.success(null);
  }
}
