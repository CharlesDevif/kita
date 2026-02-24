/// The source of an input routed to an agent.
enum InputSource {
  /// Voice input via STT.
  voice,

  /// Text input from the keyboard.
  text,

  /// Sensor data (camera detection, motion, etc.).
  sensor,

  /// System-generated event (timer, lifecycle, etc.).
  system,
}

/// An input routed to an agent by the [InputRouter].
///
/// Replaces the former [PluginRequest] with a simpler, agent-oriented model.
/// The agent receives its tools (sensors, AI, memory, output) through
/// [AgentContext] at spawn time, not per-request.
class AgentInput {
  /// Creates an [AgentInput].
  const AgentInput({
    required this.command,
    required this.params,
    required this.source,
    required this.timestamp,
  });

  /// The command being routed (e.g., "describe", "alert", "stop").
  final String command;

  /// Parameters associated with this input.
  final Map<String, dynamic> params;

  /// Where this input originated from.
  final InputSource source;

  /// When this input was created.
  final DateTime timestamp;

  @override
  String toString() => 'AgentInput(command: $command, source: $source)';
}
