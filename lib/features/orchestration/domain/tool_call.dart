/// Represents an LLM's decision to invoke a tool.
///
/// When the conversational LLM determines that it needs to perform an
/// action (e.g., take a photo and describe it), it returns a [ToolCall]
/// instead of plain text. The [ConversationEngine] then executes the
/// corresponding action via the agent system.
///
/// ## Parsing
///
/// Each AI provider adapter is responsible for parsing tool calls from
/// the provider's native format:
/// - **Claude**: `tool_use` content blocks with `name` and `input`
/// - **OpenAI**: `tool_calls` array with `function.name` and `function.arguments`
/// - **Gemma/local**: parsed from `<tool_call>{"name":...}</tool_call>` text
class ToolCall {
  const ToolCall({
    required this.toolName,
    this.arguments = const {},
  });

  /// The name of the tool to call (must match a [ToolSpec.name]).
  final String toolName;

  /// Arguments provided by the LLM for this tool call.
  /// Keys match [ToolSpec.parameters] names, values are dynamic
  /// (strings, numbers, booleans as returned by the LLM).
  final Map<String, dynamic> arguments;

  @override
  String toString() => 'ToolCall(tool: $toolName, args: ${arguments.length} params)';
}
