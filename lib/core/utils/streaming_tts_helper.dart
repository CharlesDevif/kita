import 'dart:async';

import '../../features/io/domain/tts_service.dart';
import 'sentence_buffer.dart';

/// Pipes a token stream (from LLM) to TTS sentence by sentence.
///
/// Returns the complete accumulated text when the stream is done.
/// Each complete sentence is spoken as soon as it's detected, reducing
/// perceived latency from full-completion time to first-sentence time.
Future<String> streamToTTS({
  required Stream<String> tokenStream,
  required TTSService tts,
  TTSPriority priority = TTSPriority.urgent,
}) async {
  final fullText = StringBuffer();

  final buffer = SentenceBuffer(
    onSentence: (sentence) {
      unawaited(tts.speak(sentence, priority: priority));
    },
  );

  await for (final token in tokenStream) {
    fullText.write(token);
    buffer.add(token);
  }

  // Flush any remaining partial sentence.
  buffer.flush();

  return fullText.toString();
}
