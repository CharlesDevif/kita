import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/audio_service.dart';

class MockAudioService implements AudioService {
  bool shouldFail = false;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<Result<void>> startListening({
    void Function(List<int> audioData)? onData,
  }) async {
    if (shouldFail) {
      return const Result.failure(
        UnexpectedFailure(logMessage: 'Audio service unavailable'),
      );
    }
    _isListening = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopListening() async {
    _isListening = false;
    return const Result.success(null);
  }
}
