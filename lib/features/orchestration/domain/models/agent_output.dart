/// The type of output produced by an agent.
enum AgentOutputType {
  /// Plain text response.
  text,

  /// Image or visual content.
  image,

  /// Alert notification (obstacle, warning).
  alert,

  /// Rich content with metadata (structured response).
  rich,

  /// No content -- agent handled the input silently.
  empty,
}

/// The result of an agent handling an input.
///
/// Replaces the former [PluginResponse] with a simpler model.
/// Actual output delivery (TTS, haptic, viewport) happens through
/// [OutputHandle], not through the response object.
class AgentOutput {
  /// Creates an [AgentOutput].
  const AgentOutput({
    required this.type,
    required this.content,
    this.metadata,
  });

  /// Factory for an empty output (agent handled input silently).
  const AgentOutput.empty()
      : type = AgentOutputType.empty,
        content = '',
        metadata = null;

  /// The type of output produced.
  final AgentOutputType type;

  /// The main content of the response.
  final String content;

  /// Optional metadata associated with the output.
  final Map<String, dynamic>? metadata;

  @override
  String toString() => 'AgentOutput(type: $type, content: ${content.length} chars)';
}
