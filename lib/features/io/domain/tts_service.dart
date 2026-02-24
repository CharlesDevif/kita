import '../../../core/errors/result.dart';
import 'speech_event.dart';

enum TTSPriority { critical, urgent, standard }

abstract interface class TTSService {
  bool get isSpeaking;
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  });
  Future<Result<void>> stop();

  /// Stream of speech lifecycle events (started, completed, interrupted).
  ///
  /// Broadcast stream — multiple listeners are supported.
  /// Used by agents via [OutputHandle.speechEvents] to manage behavior
  /// (e.g., DescribeAgent starts silence timeout on [completed]).
  Stream<SpeechEvent> get speechEvents;
}
