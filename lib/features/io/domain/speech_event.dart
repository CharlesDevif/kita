/// Events emitted by [TTSService] during speech delivery.
///
/// Used by [OutputHandle.speechEvents] to notify agents of speech lifecycle
/// changes. For example, [DescribeAgent] listens for [completed] to start
/// its silence timeout timer.
enum SpeechEventType {
  /// TTS has started speaking.
  started,

  /// TTS has finished speaking naturally.
  completed,

  /// TTS was interrupted (via stop() or a higher-priority message).
  interrupted,
}

/// A speech lifecycle event emitted by [TTSService.speechEvents].
class SpeechEvent {
  /// Creates a [SpeechEvent] with [started] type.
  SpeechEvent.started({required this.text})
      : type = SpeechEventType.started,
        timestamp = DateTime.now();

  /// Creates a [SpeechEvent] with [completed] type.
  SpeechEvent.completed({required this.text})
      : type = SpeechEventType.completed,
        timestamp = DateTime.now();

  /// Creates a [SpeechEvent] with [interrupted] type.
  SpeechEvent.interrupted({required this.text})
      : type = SpeechEventType.interrupted,
        timestamp = DateTime.now();

  /// The type of this speech event.
  final SpeechEventType type;

  /// The text that was being spoken.
  final String text;

  /// When this event occurred.
  final DateTime timestamp;

  @override
  String toString() => 'SpeechEvent($type, text: ${text.length} chars)';
}
