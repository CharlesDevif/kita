import '../../../core/errors/result.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_response.dart';
import '../../ai/domain/image_data.dart';

abstract interface class AIAccess {
  Future<Result<AIResponse>> complete(AIRequest request);
  Future<Result<AIResponse>> vision(ImageData image, String prompt);

  /// Stream vision response token by token.
  ///
  /// Used by agents that pipe tokens to TTS for low-latency speech.
  /// Throws on failure (permission denied, all providers failed, etc.).
  Stream<String> visionStream(ImageData image, String prompt);
}
