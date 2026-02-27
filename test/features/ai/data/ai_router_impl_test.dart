import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/ai_router_impl.dart';
import 'package:kita/features/ai/data/request_classifier_impl.dart';
import 'package:kita/features/ai/domain/ai_provider.dart' show AIProvider, batchCompleteAsStream, batchVisionAsStream;
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

/// Reusable fake provider for router tests.
class FakeProvider implements AIProvider {
  FakeProvider({
    required this.id,
    required this.tier,
    this.isAvailable = true,
    this.shouldFail = false,
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
  int callCount = 0;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    callCount++;
    if (shouldFail) {
      return Result.failure(AIProviderFailure(
        userMessage: 'Erreur',
        logMessage: '$id failed',
        providerId: id,
      ));
    }
    return Result.success(AIResponse(
      content: 'Response from $id',
      meta: AIResponseMeta(
        providerId: id,
        latency: Duration.zero,
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    callCount++;
    if (shouldFail) {
      return Result.failure(AIProviderFailure(
        userMessage: 'Erreur',
        logMessage: '$id vision failed',
        providerId: id,
      ));
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
  Future<Result<void>> validateApiKey(String key) async =>
      const Result.success(null);
}

void main() {
  late FakeProvider cloudPowerful;
  late FakeProvider cloudFast;
  late FakeProvider localProvider;
  late RequestClassifierImpl classifier;

  setUp(() {
    classifier = RequestClassifierImpl();
    cloudPowerful = FakeProvider(
      id: 'claude',
      tier: ProviderTier.cloudPowerful,
    );
    cloudFast = FakeProvider(
      id: 'openai',
      tier: ProviderTier.cloudFast,
    );
    localProvider = FakeProvider(
      id: 'mlkit',
      tier: ProviderTier.local,
    );
  });

  AIRouterImpl makeRouter() {
    return AIRouterImpl(
      classifier: classifier,
      providers: [cloudPowerful, cloudFast, localProvider],
    );
  }

  group('AIRouterImpl', () {
    test('routes standard request to cloud-powerful first', () async {
      final router = makeRouter();
      const request = AIRequest(
        prompt: 'bonjour',
        priority: RequestPriority.standard,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('claude'));
    });

    test('classifies prompt and routes critical to local', () async {
      final router = makeRouter();
      // "obstacle" triggers critical classification — default priority is standard
      // so the classifier will re-classify it
      const request = AIRequest(prompt: 'obstacle devant');

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      // Critical requests should go to local provider
      expect(response.meta.providerId, equals('mlkit'));
      expect(cloudPowerful.callCount, equals(0));
    });

    test('respects explicit non-default priority', () async {
      final router = makeRouter();
      const request = AIRequest(
        prompt: 'whatever text with obstacle',
        priority: RequestPriority.urgent,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      // Urgent priority starts with cloud-fast
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('openai'));
    });

    test('response has accurate latency measurement', () async {
      final router = makeRouter();
      const request = AIRequest(
        prompt: 'test',
        priority: RequestPriority.standard,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      // Latency should be non-negative
      expect(response.meta.latency.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('availableProviders returns only available providers', () {
      cloudFast.isAvailable = false;
      final router = makeRouter();

      expect(router.availableProviders, hasLength(2));
      expect(
        router.availableProviders.map((p) => p.id),
        containsAll(['claude', 'mlkit']),
      );
    });

    test('uses fallback chain when providers fail', () async {
      cloudPowerful.shouldFail = true;
      cloudFast.shouldFail = true;
      final router = makeRouter();
      const request = AIRequest(
        prompt: 'test',
        priority: RequestPriority.standard,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('mlkit'));
    });

    test('returns brute alert when all providers fail', () async {
      cloudPowerful.shouldFail = true;
      cloudFast.shouldFail = true;
      localProvider.shouldFail = true;
      final router = makeRouter();
      const request = AIRequest(
        prompt: 'test',
        priority: RequestPriority.standard,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('brute-alert'));
      expect(response.status, equals(AIResponseStatus.degraded));
    });

    test('works with empty provider list', () async {
      final router = AIRouterImpl(
        classifier: classifier,
        providers: [],
      );
      const request = AIRequest(
        prompt: 'test',
        priority: RequestPriority.standard,
      );

      final result = await router.route(request);

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('brute-alert'));
    });
  });
}
