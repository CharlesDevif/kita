import '../../../core/errors/result.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'image_data.dart';

abstract interface class AIRouter {
  Future<Result<AIResponse>> route(AIRequest request);

  /// Stream text completion token by token through the fallback chain.
  ///
  /// Used by the onboarding and other features that pipe tokens to TTS
  /// via [SentenceBuffer] for low-latency speech output.
  Stream<String> routeStream(AIRequest request);

  /// Stream vision response token by token through the fallback chain.
  ///
  /// Used by agents (e.g. DescribePlugin) that pipe tokens to TTS via
  /// [SentenceBuffer] for low-latency speech output.
  Stream<String> routeVisionStream(ImageData image, String prompt, {int? maxTokens});

  List<AIProvider> get availableProviders;
}
