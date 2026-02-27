/// Accumulates streaming tokens and emits complete sentences.
///
/// Used to pipe LLM token streams to TTS: accumulate tokens until a sentence
/// boundary is detected, then emit the complete sentence for speech synthesis.
/// This reduces perceived latency from ~8s (full completion) to ~1.5s (first
/// sentence).
class SentenceBuffer {
  SentenceBuffer({required this.onSentence});

  /// Called when a complete sentence is detected.
  final void Function(String sentence) onSentence;

  final StringBuffer _buffer = StringBuffer();

  /// Common abbreviations that end with `.` but are NOT sentence boundaries.
  static final _abbreviations = RegExp(
    r'(?:^|\s)(?:M|Mme|Mlle|Dr|Prof|St|Mt|Jr|Sr|etc|vol|env|av|chap)\.$',
    caseSensitive: false,
  );

  /// Add a token to the buffer. If a sentence boundary is detected,
  /// emits the complete sentence via [onSentence].
  void add(String token) {
    if (token.isEmpty) return;
    _buffer.write(token);

    // Check for sentence boundaries in the accumulated text.
    _tryEmit();
  }

  /// Flush any remaining text in the buffer, even if it doesn't end
  /// with a sentence boundary.
  void flush() {
    final remaining = _buffer.toString().trim();
    if (remaining.isNotEmpty) {
      onSentence(remaining);
    }
    _buffer.clear();
  }

  void _tryEmit() {
    // Repeatedly scan for the next sentence boundary and emit.
    while (true) {
      final text = _buffer.toString();
      final boundary = _findNextBoundary(text);
      if (boundary < 0) break;

      final sentence = text.substring(0, boundary + 1).trim();
      if (sentence.isNotEmpty) {
        onSentence(sentence);
      }
      final rest = text.substring(boundary + 1);
      _buffer.clear();
      _buffer.write(rest);
    }
  }

  /// Returns the index of the next sentence boundary in [text], or -1.
  int _findNextBoundary(String text) {
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '!' || ch == '?' || ch == '\n') {
        return i;
      } else if (ch == '.') {
        final prefix = text.substring(0, i + 1);
        if (!_abbreviations.hasMatch(prefix)) {
          if (i + 1 >= text.length || text[i + 1] == ' ' || text[i + 1] == '\n') {
            return i;
          }
        }
      }
    }
    return -1;
  }
}
