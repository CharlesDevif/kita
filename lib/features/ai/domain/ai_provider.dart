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
  Future<Result<void>> validateApiKey(String key);
}
