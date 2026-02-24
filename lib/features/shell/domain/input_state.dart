/// States for the KitaInput widget.
enum InputState {
  /// Default — placeholder visible, ready for interaction.
  idle,

  /// Microphone active, STT transcription in progress.
  listening,

  /// User typing text with keyboard.
  typing,

  /// Input disabled during AI processing.
  disabled,
}
