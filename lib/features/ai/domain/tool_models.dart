/// Domain models for LLM tool use / function calling.
library;

import 'ai_response.dart';

/// Specification of a tool that can be offered to an LLM.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// Unique tool name (e.g. `'describe_scene'`).
  final String name;

  /// Human-readable description used by the LLM to decide when to call.
  final String description;

  /// JSON Schema describing the tool's input parameters.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'type': 'object',
  ///   'properties': {
  ///     'query': {'type': 'string', 'description': 'Search query'},
  ///   },
  ///   'required': ['query'],
  /// }
  /// ```
  final Map<String, dynamic> parameters;
}

/// A tool invocation requested by the LLM.
class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  /// Provider-assigned call ID (used for sending results back).
  final String id;

  /// Name of the tool the LLM wants to call.
  final String name;

  /// Parsed arguments for the tool call.
  final Map<String, dynamic> arguments;
}

/// A message in a multi-turn conversation.
///
/// Used to send conversation history (including tool results) back to the LLM.
class ConversationMessage {
  const ConversationMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
  });

  /// Creates a user message.
  const ConversationMessage.user(String text)
      : role = ConversationRole.user,
        content = text,
        toolCallId = null,
        toolCalls = null;

  /// Creates an assistant message (text only).
  const ConversationMessage.assistant(String text)
      : role = ConversationRole.assistant,
        content = text,
        toolCallId = null,
        toolCalls = null;

  /// Creates an assistant message that contains tool calls.
  const ConversationMessage.assistantToolCalls(List<ToolCall> calls)
      : role = ConversationRole.assistant,
        content = null,
        toolCallId = null,
        toolCalls = calls;

  /// Creates a tool result message.
  const ConversationMessage.toolResult({
    required String callId,
    required String result,
  })  : role = ConversationRole.tool,
        content = result,
        toolCallId = callId,
        toolCalls = null;

  final ConversationRole role;

  /// Text content. Null for assistant messages that only contain tool calls.
  final String? content;

  /// For [ConversationRole.tool] messages: the ID of the tool call this
  /// result corresponds to.
  final String? toolCallId;

  /// For assistant messages that request tool calls.
  final List<ToolCall>? toolCalls;
}

enum ConversationRole { user, assistant, tool }

/// Response from an LLM that may include tool calls.
class AIToolResponse {
  const AIToolResponse({
    this.text,
    this.toolCalls = const [],
    required this.meta,
  });

  /// Text content (if any). May be null when the LLM only returns tool calls.
  final String? text;

  /// Tool calls requested by the LLM (empty if none).
  final List<ToolCall> toolCalls;

  /// Provider metadata (latency, provider ID, tier).
  final AIResponseMeta meta;

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get hasText => text != null && text!.isNotEmpty;
}
