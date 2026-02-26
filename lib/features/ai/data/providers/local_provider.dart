import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_request.dart';
import '../../domain/ai_response.dart';
import '../../domain/image_data.dart';
import '../../domain/provider_tier.dart';
import 'gemini_nano_bridge.dart';
import 'ml_kit_bridge.dart';

/// Label translation map: common ML Kit English labels to French.
const _labelTranslations = <String, String>{
  'Person': 'personne',
  'Table': 'table',
  'Car': 'voiture',
  'Chair': 'chaise',
  'Dog': 'chien',
  'Cat': 'chat',
  'Food': 'nourriture',
  'Tree': 'arbre',
  'Building': 'batiment',
  'Door': 'porte',
  'Window': 'fenetre',
  'Phone': 'telephone',
  'Book': 'livre',
  'Bottle': 'bouteille',
  'Cup': 'tasse',
  'Flower': 'fleur',
  'Furniture': 'meuble',
  'Plant': 'plante',
  'Animal': 'animal',
  'Vehicle': 'vehicule',
  'Street': 'rue',
  'Sign': 'panneau',
  'Sky': 'ciel',
  'Water': 'eau',
  'Stairs': 'escalier',
  'Wall': 'mur',
  'Floor': 'sol',
  'Shoe': 'chaussure',
  'Bag': 'sac',
  'Glasses': 'lunettes',
  'Hat': 'chapeau',
  'Bicycle': 'velo',
  'Bus': 'bus',
  'Truck': 'camion',
  'Motorcycle': 'moto',
  'Pedestrian': 'pieton',
  'Road': 'route',
  'Sidewalk': 'trottoir',
  'Crosswalk': 'passage pieton',
};

/// Local AI provider for on-device inference.
///
/// Two-tier vision architecture:
/// 1. **Gemini Nano** (Android, AICore devices) — rich natural language
///    descriptions via ML Kit GenAI Image Description API.
/// 2. **ML Kit fallback** (Android/iOS) — OCR + image labels for a basic
///    "Je vois : personne, table, chaise" response.
///
/// The provider tries Gemini Nano first (if available), then falls back to
/// ML Kit. Text-only requests always use keyword matching (no LLM needed).
///
/// Always returns [ProviderTier.local] and works 100% offline.
class LocalProvider implements AIProvider {
  LocalProvider({
    TargetPlatform? platform,
    MlKitBridge? mlKitBridge,
    GeminiNanoBridge? geminiNanoBridge,
  })  : _platform = platform ?? defaultTargetPlatform,
        _mlKitBridge = mlKitBridge,
        _geminiNanoBridge = geminiNanoBridge;

  static final _log = KitaLogger('AI');

  final TargetPlatform _platform;

  /// Injected ML Kit bridge for testability. When null, a real
  /// [MlKitBridgeImpl] is lazily created on first vision call.
  MlKitBridge? _mlKitBridge;

  /// Injected Gemini Nano bridge for testability. When null, a real
  /// [GeminiNanoBridgeImpl] is lazily created on first vision call
  /// (Android only).
  GeminiNanoBridge? _geminiNanoBridge;

  /// Cached result of Gemini Nano availability check.
  /// Avoids re-checking on every vision call.
  GeminiNanoStatus? _geminiNanoStatus;

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

    _log.debug('Processing local request');

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
  Future<Result<AIResponse>> vision(
    ImageData image,
    String prompt, {
    int? maxTokens,
  }) async {
    if (!isAvailable) {
      return Result.failure(AIProviderFailure(
        userMessage: 'IA locale non disponible sur cette plateforme.',
        logMessage: 'Local vision not available on $_platform',
        providerId: id,
      ));
    }

    _log.debug('Processing local vision request');

    final stopwatch = Stopwatch()..start();

    // Tier 1: Try Gemini Nano (Android only, AICore devices).
    if (_platform == TargetPlatform.android) {
      final nanoResult = await _tryGeminiNano(image, stopwatch);
      if (nanoResult != null) return nanoResult;
    }

    // Tier 2: Fall back to ML Kit (labels + OCR).
    return _tryMlKit(image, stopwatch);
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    // Local provider has no API key — always valid.
    return const Result.success(null);
  }

  /// Releases native resources. Must be called when the provider
  /// is no longer needed (e.g. via `ref.onDispose`).
  Future<void> dispose() async {
    await _geminiNanoBridge?.dispose();
    _geminiNanoBridge = null;
    await _mlKitBridge?.dispose();
    _mlKitBridge = null;
  }

  // ---------------------------------------------------------------------------
  // Gemini Nano (Tier 1)
  // ---------------------------------------------------------------------------

  /// Attempts Gemini Nano vision. Returns null if unavailable or failed
  /// (caller should fall through to ML Kit).
  Future<Result<AIResponse>?> _tryGeminiNano(
    ImageData image,
    Stopwatch stopwatch,
  ) async {
    try {
      final bridge = _getOrCreateNanoBridge();
      final status = await _checkNanoAvailability(bridge);

      if (status != GeminiNanoStatus.available) {
        _log.debug('Gemini Nano not available (status: ${status.name}), '
            'falling back to ML Kit');
        return null;
      }

      final result = await bridge.describeImage(image.bytes);
      stopwatch.stop();

      _log.info('Gemini Nano vision completed');

      return Result.success(AIResponse(
        content: result.description,
        meta: AIResponseMeta(
          providerId: 'gemini-nano',
          latency: stopwatch.elapsed,
          tier: ProviderTier.local,
        ),
        // Gemini Nano gives rich descriptions — still local but higher quality.
        status: AIResponseStatus.degraded,
      ));
    } on Exception catch (e, stack) {
      _log.warning(
        'Gemini Nano vision failed, falling back to ML Kit',
        error: e,
        stackTrace: stack,
      );
      return null; // Let caller fall through to ML Kit
    }
  }

  /// Check and cache Gemini Nano availability.
  Future<GeminiNanoStatus> _checkNanoAvailability(
    GeminiNanoBridge bridge,
  ) async {
    if (_geminiNanoStatus == GeminiNanoStatus.available) {
      return GeminiNanoStatus.available;
    }
    _geminiNanoStatus = await bridge.checkAvailability();
    return _geminiNanoStatus!;
  }

  GeminiNanoBridge _getOrCreateNanoBridge() {
    return _geminiNanoBridge ??= GeminiNanoBridgeImpl();
  }

  // ---------------------------------------------------------------------------
  // ML Kit fallback (Tier 2)
  // ---------------------------------------------------------------------------

  /// ML Kit vision: labels + OCR.
  Future<Result<AIResponse>> _tryMlKit(
    ImageData image,
    Stopwatch stopwatch,
  ) async {
    try {
      final bridge = _getOrCreateMlKitBridge();
      final result = await bridge.analyzeImage(
        image.bytes,
        width: image.width,
        height: image.height,
      );
      stopwatch.stop();

      final content = _formatVisionResult(result);

      _log.info('ML Kit vision analysis completed');

      return Result.success(AIResponse(
        content: content,
        meta: AIResponseMeta(
          providerId: id,
          latency: stopwatch.elapsed,
          tier: ProviderTier.local,
        ),
        status: AIResponseStatus.degraded,
      ));
    } on Exception catch (e, stack) {
      stopwatch.stop();
      _log.error('ML Kit vision failed', error: e, stackTrace: stack);
      return Result.failure(AIProviderFailure(
        userMessage: 'Analyse d\'image locale echouee.',
        logMessage: 'ML Kit vision error: ${e.runtimeType}',
        providerId: id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  MlKitBridge _getOrCreateMlKitBridge() {
    return _mlKitBridge ??= MlKitBridgeImpl();
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatVisionResult(MlKitVisionResult result) {
    final hasText = result.recognizedText.trim().isNotEmpty;
    final hasLabels = result.labels.isNotEmpty;

    if (!hasText && !hasLabels) {
      return 'Image analysee mais aucun element reconnu.';
    }

    final parts = <String>[];

    if (hasLabels) {
      final translatedLabels = result.labels
          .take(5)
          .map((l) => _translateLabel(l.label))
          .toList();
      parts.add('Je vois : ${translatedLabels.join(', ')}.');
    }

    if (hasText) {
      parts.add('Texte detecte : ${result.recognizedText.trim()}');
    }

    return parts.join(' ');
  }

  String _translateLabel(String englishLabel) {
    return _labelTranslations[englishLabel] ?? englishLabel.toLowerCase();
  }

  String _localResponse(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('obstacle') ||
        lower.contains('danger') ||
        lower.contains('alerte')) {
      return 'Attention ! Obstacle potentiel detecte.';
    }

    if (lower.contains('heure') || lower.contains('time')) {
      return 'Je ne peux pas lire l\'heure en mode hors-ligne.';
    }

    if (lower.contains('lis') ||
        lower.contains('texte') ||
        lower.contains('read') ||
        lower.contains('lire')) {
      return 'Texte detecte mais lecture detaillee non disponible hors-ligne.';
    }

    if (lower.contains('aide') || lower.contains('help')) {
      return 'Mode hors-ligne : je peux detecter des obstacles et lire du texte avec la camera.';
    }

    if (lower.contains('ou') ||
        lower.contains('where') ||
        lower.contains('direction')) {
      return 'Navigation non disponible en mode hors-ligne.';
    }

    if (lower.contains('decris') ||
        lower.contains('describe') ||
        lower.contains('voir') ||
        lower.contains('see') ||
        lower.contains('photo') ||
        lower.contains('image')) {
      return 'Pour decrire une image, utilisez la camera. Analyse locale disponible.';
    }

    return 'Reponse locale limitee. Connectez-vous pour une reponse complete.';
  }
}
