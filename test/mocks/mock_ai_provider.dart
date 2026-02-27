import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';

class MockAIProvider implements AIProvider {
  bool shouldFail = false;

  @override
  String get id => 'mock-provider';

  @override
  String get displayName => 'Mock AI Provider';

  @override
  ProviderTier get tier => ProviderTier.cloudFast;

  @override
  bool get isAvailable => !shouldFail;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur IA',
          logMessage: 'Mock provider failure',
          providerId: 'mock-provider',
        ),
      );
    }
    return Result.success(AIResponse(
      content: 'Mock response to: ${request.prompt}',
      meta: const AIResponseMeta(
        providerId: 'mock-provider',
        latency: Duration(milliseconds: 100),
        tier: ProviderTier.cloudFast,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur vision',
          logMessage: 'Mock vision failure',
          providerId: 'mock-provider',
        ),
      );
    }
    return const Result.success(AIResponse(
      content: 'A park with a large fountain',
      meta: AIResponseMeta(
        providerId: 'mock-provider',
        latency: Duration(milliseconds: 200),
        tier: ProviderTier.cloudFast,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> completeStream(AIRequest request) {
    return batchCompleteAsStream(() => complete(request));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt, {int? maxTokens}) {
    return batchVisionAsStream(() => vision(image, prompt, maxTokens: maxTokens));
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    if (shouldFail) {
      return Result.failure(
        AIProviderFailure.invalidApiKey('mock-provider'),
      );
    }
    return const Result.success(null);
  }
}
