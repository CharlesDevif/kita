import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/tts_service.dart';

class MockTTSService implements TTSService {
  bool shouldFail = false;
  bool _isSpeaking = false;
  String? lastSpokenText;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    if (shouldFail) {
      return const Result.failure(
        UnexpectedFailure(logMessage: 'TTS engine unavailable'),
      );
    }
    _isSpeaking = true;
    lastSpokenText = text;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _isSpeaking = false;
    return const Result.success(null);
  }
}
