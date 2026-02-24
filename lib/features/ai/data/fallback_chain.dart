import '../../../core/config/app_config.dart';
import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_request.dart';
import '../domain/ai_response.dart';
import '../domain/provider_tier.dart';
import '../domain/request_priority.dart';

/// Never-fail fallback chain for AI requests.
///
/// Cascades through providers by tier: cloudPowerful -> cloudFast -> local.
/// If all providers fail, returns a brute alert response that CANNOT fail.
/// Critical requests skip cloud providers entirely.
class FallbackChain {
  FallbackChain({required List<AIProvider> providers})
      : _providers = List.unmodifiable(providers);

  static final _log = KitaLogger('AI');

  final List<AIProvider> _providers;

  static const _bruteAlertContent =
      'Attention ! Situation détectée mais impossible de fournir plus de détails.';

  /// Execute the request through the fallback chain.
  ///
  /// Returns [Result.success] guaranteed — the brute alert is the last resort.
  Future<Result<AIResponse>> execute(AIRequest request) async {
    final tiers = _tiersForPriority(request.priority ?? RequestPriority.standard);

    for (final tier in tiers) {
      final providersForTier =
          _providers.where((p) => p.tier == tier && p.isAvailable).toList();

      for (final provider in providersForTier) {
        final result = await _tryProvider(provider, request, tier);
        if (result.isSuccess) return result;
      }
    }

    // All providers failed — return brute alert (never fails).
    _log.critical('All providers failed, returning brute alert');
    return Result.success(_bruteAlertResponse());
  }

  /// Returns the tier order for a given priority.
  /// Critical requests skip cloud — go directly to local.
  List<ProviderTier> _tiersForPriority(RequestPriority priority) {
    return switch (priority) {
      RequestPriority.critical => [ProviderTier.local],
      RequestPriority.urgent => [
          ProviderTier.cloudFast,
          ProviderTier.cloudPowerful,
          ProviderTier.local,
        ],
      RequestPriority.standard => [
          ProviderTier.cloudPowerful,
          ProviderTier.cloudFast,
          ProviderTier.local,
        ],
      RequestPriority.background => [
          ProviderTier.cloudPowerful,
          ProviderTier.cloudFast,
          ProviderTier.local,
        ],
    };
  }

  Future<Result<AIResponse>> _tryProvider(
    AIProvider provider,
    AIRequest request,
    ProviderTier tier,
  ) async {
    final timeout = _timeoutForTier(tier);

    try {
      final future = request.imageData != null
          ? provider.vision(request.imageData!, request.prompt, maxTokens: request.maxTokens)
          : provider.complete(request);

      final result = await future.timeout(timeout, onTimeout: () {
        _log.warning(
          'Provider ${provider.id} timed out after ${timeout.inMilliseconds}ms',
        );
        return Result.failure(
          AIProviderFailure(
            userMessage: 'Le fournisseur IA a mis trop de temps.',
            logMessage:
                'Provider ${provider.id} timeout after ${timeout.inMilliseconds}ms',
            providerId: provider.id,
          ),
        );
      });

      if (result.isSuccess) {
        return result;
      }

      _log.warning(
        'Provider ${provider.id} failed, falling back to next tier',
      );
      return result;
    } catch (e, stack) {
      _log.warning(
        'Provider ${provider.id} threw exception, falling back',
        error: e,
        stackTrace: stack,
      );
      return Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur du fournisseur IA.',
          logMessage: 'Provider ${provider.id} exception: $e',
          providerId: provider.id,
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  Duration _timeoutForTier(ProviderTier tier) {
    return switch (tier) {
      ProviderTier.cloudPowerful => AppConfig.aiCloudTimeout,
      ProviderTier.cloudFast => AppConfig.aiCloudTimeout,
      ProviderTier.local => AppConfig.aiLocalTimeout,
    };
  }

  AIResponse _bruteAlertResponse() {
    return const AIResponse(
      content: _bruteAlertContent,
      meta: AIResponseMeta(
        providerId: 'brute-alert',
        latency: Duration.zero,
        tier: ProviderTier.local,
        cached: false,
      ),
      status: AIResponseStatus.degraded,
    );
  }
}
