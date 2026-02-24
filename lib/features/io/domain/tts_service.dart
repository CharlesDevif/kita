import '../../../core/errors/result.dart';

enum TTSPriority { critical, urgent, standard }

abstract interface class TTSService {
  bool get isSpeaking;
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  });
  Future<Result<void>> stop();
}
