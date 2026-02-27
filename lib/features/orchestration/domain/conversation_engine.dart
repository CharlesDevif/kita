import '../../../core/errors/result.dart';

/// Response from the [ConversationEngine] after processing user input.
class ConversationResponse {
  const ConversationResponse({
    required this.text,
    this.toolCalls = const [],
  });

  /// The textual response to speak to the user.
  final String text;

  /// Tool calls the engine decided to make (e.g., "describe", "navigate").
  final List<String> toolCalls;

  /// Whether this response is empty (no text and no tool calls).
  bool get isEmpty => text.isEmpty && toolCalls.isEmpty;
}

/// Abstract interface for the conversational AI engine.
///
/// The [ConversationEngine] processes natural-language user input through
/// an LLM (local or cloud) and returns a response that may include text,
/// tool calls, or both.
///
/// This is an **optional** dependency for [InputRouter]:
/// - When available AND the LLM is ready, input is routed here.
/// - When unavailable (no API keys, Gemma not warm), [InputRouter] falls
///   back to pattern-matching via [VoiceCommandHandler].
///
/// Implementations are provided by the conversation engine feature.
abstract interface class ConversationEngine {
  /// Whether the engine is ready to process input.
  ///
  /// Returns false if the LLM is not available (no API keys configured,
  /// Gemma model not loaded yet, etc.).
  bool get isReady;

  /// Processes natural-language [input] and returns a response.
  ///
  /// The engine maintains conversation context internally.
  /// Returns [Result.failure] on LLM errors (timeout, OOM, etc.).
  Future<Result<ConversationResponse>> processInput(String input);

  /// Streams the response token by token for low-latency TTS.
  ///
  /// Falls back to [processInput] wrapped in a single-element stream
  /// if the underlying provider doesn't support streaming.
  Stream<String> processInputStream(String input);
}
