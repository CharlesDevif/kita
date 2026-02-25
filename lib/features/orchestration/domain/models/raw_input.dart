import '../clock.dart';
import 'agent_input.dart';

/// Raw input arriving from the user or system before classification.
///
/// This is the entry point for all inputs into the orchestrator.
/// The [InputRouter] classifies and routes [RawInput] to the appropriate
/// agent or system handler.
///
/// Use the named factories for convenience:
/// - [RawInput.text] for keyboard input
/// - [RawInput.voice] for STT transcript
/// - [RawInput.sensor] for sensor data (e.g., obstacle detection)
class RawInput {
  const RawInput._({
    required this.source,
    required this.timestamp,
    this.transcript,
    this.sensorData,
  });

  /// Creates a [RawInput] from text keyboard input.
  factory RawInput.text(String transcript, {required Clock clock}) =>
      RawInput._(
        source: InputSource.text,
        transcript: transcript,
        timestamp: clock.now(),
      );

  /// Creates a [RawInput] from voice (STT) transcript.
  factory RawInput.voice(String transcript, {required Clock clock}) =>
      RawInput._(
        source: InputSource.voice,
        transcript: transcript,
        timestamp: clock.now(),
      );

  /// Creates a [RawInput] from sensor data (e.g., obstacle detection).
  factory RawInput.sensor(
    Map<String, dynamic> data, {
    required Clock clock,
  }) =>
      RawInput._(
        source: InputSource.sensor,
        sensorData: data,
        timestamp: clock.now(),
      );

  /// Creates a [RawInput] from a system event.
  factory RawInput.system(
    String event, {
    required Clock clock,
  }) =>
      RawInput._(
        source: InputSource.system,
        transcript: event,
        timestamp: clock.now(),
      );

  /// Where this input originated from.
  final InputSource source;

  /// The text transcript (for voice/text inputs).
  final String? transcript;

  /// Sensor data payload (for sensor inputs).
  final Map<String, dynamic>? sensorData;

  /// When this input was created.
  final DateTime timestamp;

  @override
  String toString() => 'RawInput(source: $source, '
      'transcript: ${transcript != null ? "${transcript!.length} chars" : "null"})';
}
