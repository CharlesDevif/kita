import 'provider_tier.dart';

enum AIResponseStatus { success, degraded, error }

class AIResponseMeta {
  const AIResponseMeta({
    required this.providerId,
    required this.latency,
    required this.tier,
    this.cached = false,
  });

  final String providerId;
  final Duration latency;
  final ProviderTier tier;
  final bool cached;
}

class AIResponse {
  const AIResponse({
    required this.content,
    required this.meta,
    required this.status,
  });

  final String content;
  final AIResponseMeta meta;
  final AIResponseStatus status;
}
