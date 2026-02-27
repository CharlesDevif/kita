import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/fallback_chain.dart';
import 'package:kita/features/ai/domain/ai_provider.dart' show AIProvider, batchCompleteAsStream, batchVisionAsStream;
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';
import 'package:kita/features/ai/domain/tool_models.dart';

/// Test helper: configurable fake AI provider.
class FakeAIProvider implements AIProvider {
  FakeAIProvider({
    required this.id,
    required this.tier,
    this.isAvailable = true,
    this.shouldFail = false,
    this.shouldThrow = false,
    this.delayMs = 0,
  });

  @override
  final String id;

  @override
  String get displayName => 'Fake $id';

  @override
  final ProviderTier tier;

  @override
  bool isAvailable;

  bool shouldFail;
  bool shouldThrow;
  int delayMs;
  int callCount = 0;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    callCount++;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (shouldThrow) {
      throw Exception('Provider $id crashed');
    }
    if (shouldFail) {
      return Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur',
          logMessage: 'Fake $id failure',
          providerId: id,
        ),
      );
    }
    return Result.success(AIResponse(
      content: 'Response from $id',
      meta: AIResponseMeta(
        providerId: id,
        latency: Duration(milliseconds: delayMs),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    callCount++;
    if (shouldFail) {
      return Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur vision',
          logMessage: 'Fake $id vision failure',
          providerId: id,
        ),
      );
    }
    return Result.success(AIResponse(
      content: 'Vision from $id',
      meta: AIResponseMeta(
        providerId: id,
        latency: Duration.zero,
        tier: tier,
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
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    callCount++;
    if (shouldThrow) {
      throw Exception('Provider $id tool-use crashed');
    }
    if (shouldFail) {
      return Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur',
          logMessage: 'Fake $id tool-use failure',
          providerId: id,
        ),
      );
    }
    return Result.success(AIToolResponse(
      text: 'Tool response from $id',
      meta: AIResponseMeta(
        providerId: id,
        latency: Duration(milliseconds: delayMs),
        tier: tier,
      ),
    ));
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    return const Result.success(null);
  }
}

void main() {
  late FakeAIProvider cloudPowerful;
  late FakeAIProvider cloudFast;
  late FakeAIProvider localProvider;

  setUp(() {
    cloudPowerful = FakeAIProvider(
      id: 'claude',
      tier: ProviderTier.cloudPowerful,
    );
    cloudFast = FakeAIProvider(
      id: 'openai',
      tier: ProviderTier.cloudFast,
    );
    localProvider = FakeAIProvider(
      id: 'mlkit',
      tier: ProviderTier.local,
    );
  });

  FallbackChain makeChain() {
    return FallbackChain(
      providers: [cloudPowerful, cloudFast, localProvider],
    );
  }

  group('FallbackChain', () {
    group('standard priority — full cascade', () {
      test('succeeds on first provider (cloud-powerful)', () async {
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'describe this',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('claude'));
        expect(cloudPowerful.callCount, equals(1));
        expect(cloudFast.callCount, equals(0));
        expect(localProvider.callCount, equals(0));
      });

      test('falls back to cloud-fast when cloud-powerful fails', () async {
        cloudPowerful.shouldFail = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'describe this',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('openai'));
        expect(cloudPowerful.callCount, equals(1));
        expect(cloudFast.callCount, equals(1));
      });

      test('falls back to local when both cloud providers fail', () async {
        cloudPowerful.shouldFail = true;
        cloudFast.shouldFail = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'describe this',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('mlkit'));
      });

      test('returns brute alert when ALL providers fail', () async {
        cloudPowerful.shouldFail = true;
        cloudFast.shouldFail = true;
        localProvider.shouldFail = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'describe this',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('brute-alert'));
        expect(response.status, equals(AIResponseStatus.degraded));
        expect(response.content, contains('Attention'));
      });
    });

    group('critical priority — local only', () {
      test('skips cloud and goes directly to local', () async {
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'obstacle ahead',
          priority: RequestPriority.critical,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('mlkit'));
        expect(cloudPowerful.callCount, equals(0));
        expect(cloudFast.callCount, equals(0));
        expect(localProvider.callCount, equals(1));
      });

      test('returns brute alert if local fails on critical', () async {
        localProvider.shouldFail = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'danger',
          priority: RequestPriority.critical,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('brute-alert'));
        expect(cloudPowerful.callCount, equals(0));
        expect(cloudFast.callCount, equals(0));
      });
    });

    group('urgent priority', () {
      test('tries cloud-fast first, then cloud-powerful, then local',
          () async {
        cloudFast.shouldFail = true;
        cloudPowerful.shouldFail = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'decris ca',
          priority: RequestPriority.urgent,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('mlkit'));
        // Verify both cloud providers were attempted before falling back to local
        expect(cloudFast.callCount, greaterThanOrEqualTo(1));
        expect(cloudPowerful.callCount, greaterThanOrEqualTo(1));
      });
    });

    group('exception handling', () {
      test('catches provider exceptions and continues fallback', () async {
        cloudPowerful.shouldThrow = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'test',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('openai'));
      });

      test('skips unavailable providers', () async {
        cloudPowerful.isAvailable = false;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'test',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('openai'));
        expect(cloudPowerful.callCount, equals(0));
      });
    });

    group('vision requests', () {
      test('routes vision requests through fallback chain', () async {
        cloudPowerful.shouldFail = true;
        final chain = makeChain();
        final request = AIRequest(
          prompt: 'describe image',
          imageData: ImageData(bytes: Uint8List.fromList([1, 2, 3])),
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('openai'));
        expect(response.content, contains('Vision'));
      });
    });

    group('executeWithTools — tool-use cascade', () {
      test('succeeds on first provider', () async {
        final chain = makeChain();
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.meta.providerId, equals('claude'));
        expect(cloudPowerful.callCount, equals(1));
        expect(cloudFast.callCount, equals(0));
        expect(localProvider.callCount, equals(0));
      });

      test('falls back when first provider fails', () async {
        cloudPowerful.shouldFail = true;
        final chain = makeChain();
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.meta.providerId, equals('openai'));
      });

      test('falls back to local when both cloud providers fail', () async {
        cloudPowerful.shouldFail = true;
        cloudFast.shouldFail = true;
        final chain = makeChain();
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.meta.providerId, equals('mlkit'));
      });

      test('returns brute alert when all providers fail', () async {
        cloudPowerful.shouldFail = true;
        cloudFast.shouldFail = true;
        localProvider.shouldFail = true;
        final chain = makeChain();
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.meta.providerId, equals('brute-alert'));
        expect(response.hasText, isTrue);
        expect(response.hasToolCalls, isFalse);
        expect(response.text, contains('Attention'));
      });

      test('catches exceptions and continues cascade', () async {
        cloudPowerful.shouldThrow = true;
        final chain = makeChain();
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.meta.providerId, equals('openai'));
      });

      test('passes history through to providers', () async {
        final chain = makeChain();
        final history = [
          const ConversationMessage.user('Hello'),
          const ConversationMessage.assistant('Hi there'),
        ];
        final result = await chain.executeWithTools(
          const AIRequest(prompt: 'Weather?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
          history: history,
        );

        expect(result.isSuccess, isTrue);
      });
    });

    group('never-fail guarantee', () {
      test('brute alert is ALWAYS Success even with no providers', () async {
        final chain = FallbackChain(providers: []);
        final request = const AIRequest(
          prompt: 'help',
          priority: RequestPriority.critical,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('brute-alert'));
      });

      test('brute alert is Success after all tiers fail', () async {
        cloudPowerful.shouldThrow = true;
        cloudFast.shouldThrow = true;
        localProvider.shouldThrow = true;
        final chain = makeChain();
        final request = const AIRequest(
          prompt: 'describe',
          priority: RequestPriority.standard,
        );

        final result = await chain.execute(request);

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.meta.providerId, equals('brute-alert'));
        expect(response.status, equals(AIResponseStatus.degraded));
      });
    });
  });
}
