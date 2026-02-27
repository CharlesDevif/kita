import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/fallback_chain.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

import 'fallback_chain_test.dart' show FakeAIProvider;

void main() {
  group('FallbackChain.executeStream', () {
    test('yields tokens from first successful provider', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
      );
      final local = FakeAIProvider(
        id: 'local',
        tier: ProviderTier.local,
      );
      final chain = FallbackChain(providers: [cloud, local]);

      const request = AIRequest(
        prompt: 'hello',
        priority: RequestPriority.standard,
      );

      final tokens = await chain.executeStream(request).toList();

      expect(tokens, isNotEmpty);
      expect(tokens.join(), equals('Response from claude'));
      expect(cloud.callCount, equals(1));
      expect(local.callCount, equals(0));
    });

    test('cascades to next provider when first throws', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
        shouldThrow: true,
      );
      final fallback = FakeAIProvider(
        id: 'openai',
        tier: ProviderTier.cloudFast,
      );
      final chain = FallbackChain(providers: [cloud, fallback]);

      const request = AIRequest(
        prompt: 'hello',
        priority: RequestPriority.standard,
      );

      final tokens = await chain.executeStream(request).toList();

      expect(tokens.join(), equals('Response from openai'));
      expect(cloud.callCount, equals(1));
      expect(fallback.callCount, equals(1));
    });

    test('cascades to next provider when first fails', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
        shouldFail: true,
      );
      final local = FakeAIProvider(
        id: 'local',
        tier: ProviderTier.local,
      );
      final chain = FallbackChain(providers: [cloud, local]);

      const request = AIRequest(
        prompt: 'hello',
        priority: RequestPriority.standard,
      );

      final tokens = await chain.executeStream(request).toList();

      // batchCompleteAsStream throws on failure, FallbackChain catches and cascades
      expect(tokens.join(), equals('Response from local'));
    });

    test('yields brute alert when all providers fail', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
        shouldFail: true,
      );
      final local = FakeAIProvider(
        id: 'local',
        tier: ProviderTier.local,
        shouldFail: true,
      );
      final chain = FallbackChain(providers: [cloud, local]);

      const request = AIRequest(
        prompt: 'hello',
        priority: RequestPriority.standard,
      );

      final tokens = await chain.executeStream(request).toList();

      expect(tokens.join(), contains('Attention'));
    });

    test('skips unavailable providers', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
        isAvailable: false,
      );
      final local = FakeAIProvider(
        id: 'local',
        tier: ProviderTier.local,
      );
      final chain = FallbackChain(providers: [cloud, local]);

      const request = AIRequest(
        prompt: 'hello',
        priority: RequestPriority.standard,
      );

      final tokens = await chain.executeStream(request).toList();

      expect(tokens.join(), equals('Response from local'));
      expect(cloud.callCount, equals(0));
    });

    test('respects critical priority (local only)', () async {
      final cloud = FakeAIProvider(
        id: 'claude',
        tier: ProviderTier.cloudPowerful,
      );
      final local = FakeAIProvider(
        id: 'local',
        tier: ProviderTier.local,
      );
      final chain = FallbackChain(providers: [cloud, local]);

      const request = AIRequest(
        prompt: 'danger',
        priority: RequestPriority.critical,
      );

      final tokens = await chain.executeStream(request).toList();

      expect(tokens.join(), equals('Response from local'));
      expect(cloud.callCount, equals(0));
      expect(local.callCount, equals(1));
    });
  });
}
