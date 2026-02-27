import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/data/fallback_chain.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

/// Phase 4 Integration Gate — AC5: Offline fallback
///
/// Tests the behavior when network is unavailable:
/// - Cloud providers fail -> fallback to local
/// - All providers fail -> brute alert (never-fail)
/// - Network restored -> cloud providers become available again
///
/// Uses mock AI providers with controllable availability and failure states.

/// A configurable mock AI provider for offline testing.
class _ConfigurableMockProvider implements AIProvider {
  _ConfigurableMockProvider({
    required this.id,
    required this.tier,
    this.isAvailable = true,
    String? responseContent,
  }) : responseContent = responseContent ?? 'Response from provider';

  @override
  final String id;

  @override
  String get displayName => 'Mock $id';

  @override
  final ProviderTier tier;

  @override
  bool isAvailable;

  String responseContent;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    if (!isAvailable) {
      return Result.failure(
        NetworkFailure.noConnection(),
      );
    }
    return Result.success(AIResponse(
      content: responseContent,
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 100),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(
    ImageData image,
    String prompt, {
    int? maxTokens,
  }) async {
    if (!isAvailable) {
      return Result.failure(
        NetworkFailure.noConnection(),
      );
    }
    return Result.success(AIResponse(
      content: 'Vision: $responseContent',
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 200),
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
  Future<Result<void>> validateApiKey(String key) async {
    return const Result.success(null);
  }
}

void main() {
  late _ConfigurableMockProvider cloudPowerful;
  late _ConfigurableMockProvider cloudFast;
  late _ConfigurableMockProvider localProvider;
  late FallbackChain fallbackChain;
  late List<LogEntry> logEntries;

  setUp(() {
    logEntries = [];
    KitaLogger.testLogHandler = logEntries.add;

    cloudPowerful = _ConfigurableMockProvider(
      id: 'claude',
      tier: ProviderTier.cloudPowerful,
    );
    cloudPowerful.responseContent = 'Claude response';

    cloudFast = _ConfigurableMockProvider(
      id: 'openai',
      tier: ProviderTier.cloudFast,
    );
    cloudFast.responseContent = 'OpenAI response';

    localProvider = _ConfigurableMockProvider(
      id: 'ml-kit',
      tier: ProviderTier.local,
    );
    localProvider.responseContent = 'Local ML Kit response';

    fallbackChain = FallbackChain(
      providers: [cloudPowerful, cloudFast, localProvider],
    );
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
  });

  group('Phase 4 Gate — AC5: Offline fallback', () {
    test('online: standard request routes to cloudPowerful first', () async {
      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe what I see',
          priority: RequestPriority.standard,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, 'Claude response');
      expect(response.meta.providerId, 'claude');
      expect(response.meta.tier, ProviderTier.cloudPowerful);
    });

    test('network cut: cloud providers fail -> fallback to local', () async {
      // Simulate network cutoff
      cloudPowerful.isAvailable = false;
      cloudFast.isAvailable = false;

      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe what I see',
          priority: RequestPriority.standard,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, 'Local ML Kit response');
      expect(response.meta.providerId, 'ml-kit');
      expect(response.meta.tier, ProviderTier.local);
    });

    test(
      'total failure: all providers fail -> brute alert (never-fail)',
      () async {
        // All providers unavailable
        cloudPowerful.isAvailable = false;
        cloudFast.isAvailable = false;
        localProvider.isAvailable = false;

        final result = await fallbackChain.execute(
          const AIRequest(
            prompt: 'Describe what I see',
            priority: RequestPriority.standard,
          ),
        );

        // The chain NEVER returns failure — brute alert is the last resort
        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.content, contains('Attention'));
        expect(response.meta.providerId, 'brute-alert');
        expect(response.status, AIResponseStatus.degraded);
      },
    );

    test('critical request skips cloud -> goes directly to local', () async {
      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Obstacle detected',
          priority: RequestPriority.critical,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      // Critical requests go to local tier only
      expect(response.meta.providerId, 'ml-kit');
      expect(response.meta.tier, ProviderTier.local);
    });

    test('network restored: cloud providers become available again', () async {
      // Phase 1: Network down
      cloudPowerful.isAvailable = false;
      cloudFast.isAvailable = false;

      var result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe',
          priority: RequestPriority.standard,
        ),
      );

      expect(result.isSuccess, isTrue);
      var response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, 'ml-kit',
          reason: 'During outage, local provider should be used');

      // Phase 2: Network restored
      cloudPowerful.isAvailable = true;
      cloudFast.isAvailable = true;

      result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe again',
          priority: RequestPriority.standard,
        ),
      );

      expect(result.isSuccess, isTrue);
      response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, 'claude',
          reason: 'After restoration, cloud provider should be used again');
    });

    test('partial failure: powerful fails -> fast succeeds', () async {
      cloudPowerful.isAvailable = false;
      // cloudFast still available

      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe what I see',
          priority: RequestPriority.standard,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, 'openai');
      expect(response.meta.tier, ProviderTier.cloudFast);
    });

    test('urgent requests try cloudFast first', () async {
      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Quick question',
          priority: RequestPriority.urgent,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      // Urgent: cloudFast -> cloudPowerful -> local
      expect(response.meta.providerId, 'openai');
      expect(response.meta.tier, ProviderTier.cloudFast);
    });

    test('fallback chain guarantees never-fail contract', () async {
      // Even with all providers failing, the chain returns success
      cloudPowerful.isAvailable = false;
      cloudFast.isAvailable = false;
      localProvider.isAvailable = false;

      // Run multiple times to ensure consistency
      for (var i = 0; i < 10; i++) {
        final result = await fallbackChain.execute(
          AIRequest(
            prompt: 'Request $i',
            priority: RequestPriority.standard,
          ),
        );

        expect(result.isSuccess, isTrue,
            reason: 'Request $i should not fail');
        expect(result.isFailure, isFalse,
            reason: 'Never-fail contract violated on request $i');
      }
    });

    test('degraded response contains informative content', () async {
      cloudPowerful.isAvailable = false;
      cloudFast.isAvailable = false;
      localProvider.isAvailable = false;

      final result = await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe',
          priority: RequestPriority.standard,
        ),
      );

      final response = (result as Success<AIResponse>).value;
      expect(response.content.isNotEmpty, isTrue);
      expect(response.status, AIResponseStatus.degraded);
      // The brute alert should convey that something was detected
      // but details are unavailable
      expect(response.content, contains('Attention'));
    });

    test('zero PII in logs during offline fallback', () async {
      cloudPowerful.isAvailable = false;
      cloudFast.isAvailable = false;

      await fallbackChain.execute(
        const AIRequest(
          prompt: 'Describe my surroundings',
          priority: RequestPriority.standard,
        ),
      );

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('phone')));
      }
    });
  });
}
