/// Who produced a line of the conversation feed.
enum ConversationSpeaker {
  /// The user (voice transcript or typed text).
  user,

  /// Kita (spoken output, mirrored as text).
  kita,
}

/// One line of the on-screen conversation feed.
///
/// Session-only by design: the feed is never persisted (privacy-first).
class ConversationEntry {
  const ConversationEntry({
    required this.speaker,
    required this.text,
    required this.timestamp,
  });

  final ConversationSpeaker speaker;
  final String text;
  final DateTime timestamp;
}
