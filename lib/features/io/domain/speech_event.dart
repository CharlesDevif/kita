/// Events emitted by [TTSService] during speech delivery.
///
/// Internal TTS-level events with rich metadata (text, timestamp).
/// Agents should use the simpler [SpeechEvent] enum from output_handle.dart.
enum TtsSpeechEventType {
  /// TTS has started speaking.
  started,

  /// TTS has finished speaking naturally.
  completed,

  /// TTS was interrupted (via stop() or a higher-priority message).
  interrupted,
}

/// A speech lifecycle event emitted by [TTSService.speechEvents].
class TtsSpeechEvent {
  /// Creates a [TtsSpeechEvent] with [started] type.
  TtsSpeechEvent.started({required this.text})
      : type = TtsSpeechEventType.started,
        timestamp = DateTime.now();

  /// Creates a [TtsSpeechEvent] with [completed] type.
  TtsSpeechEvent.completed({required this.text})
      : type = TtsSpeechEventType.completed,
        timestamp = DateTime.now();

  /// Creates a [TtsSpeechEvent] with [interrupted] type.
  TtsSpeechEvent.interrupted({required this.text})
      : type = TtsSpeechEventType.interrupted,
        timestamp = DateTime.now();

  /// The type of this speech event.
  final TtsSpeechEventType type;

  /// The text that was being spoken.
  final String text;

  /// When this event occurred.
  final DateTime timestamp;

  @override
  String toString() => 'TtsSpeechEvent($type, text: ${text.length} chars)';
}
