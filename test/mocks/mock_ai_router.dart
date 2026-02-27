import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/ai_router.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/tool_models.dart';

class MockAIRouter implements AIRouter {
  bool shouldFail = false;

  @override
  List<AIProvider> get availableProviders => [];

  @override
  Stream<String> routeStream(AIRequest request) async* {
    if (shouldFail) throw Exception('Mock stream failure');
    yield 'Routed stream response';
  }

  @override
  Stream<String> routeVisionStream(ImageData image, String prompt, {int? maxTokens}) async* {
    if (shouldFail) throw Exception('Mock vision stream failure');
    yield 'Routed vision stream response';
  }

  @override
  Future<Result<AIResponse>> route(AIRequest request) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Aucun fournisseur disponible',
          logMessage: 'No providers available',
          providerId: 'router',
        ),
      );
    }
    return const Result.success(AIResponse(
      content: 'Routed response',
      meta: AIResponseMeta(
        providerId: 'mock-provider',
        latency: Duration(milliseconds: 150),
        tier: ProviderTier.cloudFast,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIToolResponse>> routeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Aucun fournisseur disponible',
          logMessage: 'No providers available',
          providerId: 'router',
        ),
      );
    }
    return const Result.success(AIToolResponse(
      text: 'Routed tool response',
      meta: AIResponseMeta(
        providerId: 'mock-provider',
        latency: Duration(milliseconds: 150),
        tier: ProviderTier.cloudFast,
      ),
    ));
  }
}
