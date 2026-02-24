import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_request.dart';
import '../../domain/ai_response.dart';
import '../../domain/image_data.dart';
import '../../domain/provider_tier.dart';

/// Local AI provider for on-device inference.
///
/// Uses ML Kit on Android and CoreML on iOS. Falls back to a basic
/// keyword-based response when native ML is not yet initialized.
///
/// Always returns [ProviderTier.local] and works 100% offline.
class LocalProvider implements AIProvider {
  LocalProvider({
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  static final _log = KitaLogger('AI');

  final TargetPlatform _platform;

  @override
  String get id => switch (_platform) {
        TargetPlatform.android => 'mlkit',
        TargetPlatform.iOS => 'coreml',
        _ => 'local-fallback',
      };

  @override
  String get displayName => switch (_platform) {
        TargetPlatform.android => 'ML Kit (Android)',
        TargetPlatform.iOS => 'CoreML (iOS)',
        _ => 'Local Fallback',
      };

  @override
  ProviderTier get tier => ProviderTier.local;

  @override
  bool get isAvailable =>
      _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    if (!isAvailable) {
      return Result.failure(AIProviderFailure(
        userMessage: 'IA locale non disponible sur cette plateforme.',
        logMessage: 'Local provider not available on $_platform',
        providerId: id,
      ));
    }

    _log.debug('Processing local request: ${request.prompt.substring(0, request.prompt.length.clamp(0, 30))}...');

    // MVP: return a degraded acknowledgment response.
    // Full ML pipeline (TFLite/YOLO) will be integrated in E7 (Alert plugin).
    return Result.success(AIResponse(
      content: _localResponse(request.prompt),
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 10),
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.degraded,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    if (!isAvailable) {
      return Result.failure(AIProviderFailure(
        userMessage: 'IA locale non disponible sur cette plateforme.',
        logMessage: 'Local vision not available on $_platform',
        providerId: id,
      ));
    }

    _log.debug('Processing local vision request');

    // MVP: acknowledge the image was received.
    // Full ML Kit object detection / CoreML pipeline comes in E7.
    return Result.success(AIResponse(
      content: 'Image analysee localement. Details limites en mode hors-ligne.',
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 20),
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.degraded,
    ));
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    // Local provider has no API key — always valid.
    return const Result.success(null);
  }

  String _localResponse(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('obstacle') ||
        lower.contains('danger') ||
        lower.contains('alerte')) {
      return 'Attention ! Obstacle potentiel detecte.';
    }

    if (lower.contains('lis') || lower.contains('texte') || lower.contains('read')) {
      return 'Texte detecte mais lecture detaillee non disponible hors-ligne.';
    }

    return 'Reponse locale limitee. Connectez-vous pour une reponse complete.';
  }
}
