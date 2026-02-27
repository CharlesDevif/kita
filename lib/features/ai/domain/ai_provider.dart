import '../../../core/errors/result.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'image_data.dart';
import 'provider_tier.dart';

abstract interface class AIProvider {
  String get id;
  String get displayName;
  ProviderTier get tier;
  bool get isAvailable;

  Future<Result<AIResponse>> complete(AIRequest request);
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens});

  /// Stream text completion token by token.
  ///
  /// Providers with native streaming (Gemma) yield real tokens.
  /// Providers without streaming (cloud batch) yield the full response as
  /// a single chunk via [batchCompleteAsStream].
  ///
  /// Throws on failure (caught by [FallbackChain] for cascading).
  Stream<String> completeStream(AIRequest request);

  /// Stream vision response token by token.
  ///
  /// Providers with native streaming (Gemma) yield real tokens.
  /// Providers without streaming (cloud batch) yield the full response as
  /// a single chunk via [batchVisionAsStream].
  ///
  /// Throws on failure (caught by [FallbackChain] for cascading).
  Stream<String> visionStream(ImageData image, String prompt, {int? maxTokens});

  Future<Result<void>> validateApiKey(String key);
}

/// Helper for providers that don't support native text streaming.
///
/// Wraps a batch `complete()` call into a single-element stream.
/// Throws the [KitaFailure] on error so [FallbackChain] can cascade.
Stream<String> batchCompleteAsStream(
  Future<Result<AIResponse>> Function() batchCall,
) async* {
  final result = await batchCall();
  switch (result) {
    case Success(:final value):
      yield value.content;
    case Failure(:final failure):
      throw failure;
  }
}

/// Helper for providers that don't support native vision streaming.
///
/// Wraps a batch `vision()` call into a single-element stream.
/// Throws the [KitaFailure] on error so [FallbackChain] can cascade.
Stream<String> batchVisionAsStream(
  Future<Result<AIResponse>> Function() batchCall,
) async* {
  final result = await batchCall();
  switch (result) {
    case Success(:final value):
      yield value.content;
    case Failure(:final failure):
      throw failure;
  }
}
