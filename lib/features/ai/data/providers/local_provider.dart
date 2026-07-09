import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import 'dart:convert';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_request.dart';
import '../../domain/ai_response.dart';
import '../../domain/image_data.dart';
import '../../domain/provider_tier.dart';
import '../../domain/tool_models.dart';
import 'gemma_bridge.dart';
import 'gemini_nano_bridge.dart';
import 'ml_kit_bridge.dart';

/// Résultat brut d'un parsing d'appel d'outil local.
class ParsedToolCall {
  const ParsedToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;

  /// Première valeur d'argument (le format compact n'en porte qu'une).
  String? get firstArg =>
      arguments.isEmpty ? null : arguments.values.first as String?;
}

/// Outils connus. Un `TOOL <nom>` inconnu est traité comme du texte.
const Set<String> _knownTools = {'describe', 'alert'};

/// Nom du premier paramètre de chaque outil, pour mapper le format compact.
/// `describe` n'a plus de paramètre (voir Task 4).
const Map<String, String> _firstParamOf = {'alert': 'action'};

/// Parse une réponse Gemma en appel d'outil.
///
/// Accepte le format **compact** `TOOL <nom> [valeur]` (peu de tokens à
/// décoder : ~15 s gagnées sur device) et, en repli, le **JSON legacy**
/// `{"tool_call": {...}}` au cas où le modèle, instruction-tuné au JSON,
/// ignore la consigne. Retourne `null` si ce n'est pas un appel d'outil.
ParsedToolCall? parseLocalToolResponse(String text) {
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('TOOL ')) continue;
    final parts = line.substring(5).trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) continue;
    final name = parts.first;
    // Ligne `TOOL <inconnu>` : on l'ignore et on poursuit le scan (lignes
    // suivantes puis repli JSON) au lieu d'abandonner tout le parsing. Ainsi
    // `TOOL foobar\nTOOL describe` produit bien un appel `describe`.
    if (!_knownTools.contains(name)) continue;
    final args = <String, dynamic>{};
    if (parts.length > 1 && _firstParamOf[name] != null) {
      args[_firstParamOf[name]!] = parts[1];
    }
    return ParsedToolCall(name: name, arguments: args);
  }

  // Repli JSON legacy.
  final trimmed = text.trim();
  final jsonStart = trimmed.indexOf('{');
  final jsonEnd = trimmed.lastIndexOf('}');
  if (jsonStart >= 0 && jsonEnd > jsonStart) {
    try {
      final parsed =
          jsonDecode(trimmed.substring(jsonStart, jsonEnd + 1))
              as Map<String, dynamic>;
      final toolCall = parsed['tool_call'] as Map<String, dynamic>?;
      final name = toolCall?['name'] as String?;
      if (name != null && _knownTools.contains(name)) {
        return ParsedToolCall(
          name: name,
          arguments: (toolCall!['arguments'] as Map<String, dynamic>?) ?? {},
        );
      }
    } catch (_) {
      // Pas du JSON valide : ce n'est pas un appel d'outil.
    }
  }
  return null;
}

/// Coupe la réponse dès que le modèle invente un tour de dialogue.
///
/// Le prompt d'outillage est un dialogue few-shot : le modèle poursuit
/// volontiers en fabriquant la réplique suivante. Sans cette coupe, Kita lit
/// à voix haute une question que l'utilisateur n'a jamais posée.
String stripHallucinatedTurns(String text) {
  const turnMarkers = ['Utilisateur :', 'Kita :'];
  final lines = text.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (turnMarkers.any(trimmed.startsWith)) break;
    kept.add(line);
  }
  return kept.join('\n').trim();
}

/// Rend un outil pour le prompt, sans JSON Schema : un modèle 2B suit mieux
/// une phrase qu'un objet.
String _formatToolForPrompt(ToolSpec tool) {
  final buffer = StringBuffer('- ${tool.name} : ${tool.description}');
  final properties = tool.parameters['properties'];
  if (properties is Map<String, dynamic>) {
    for (final entry in properties.entries) {
      final schema = entry.value;
      final values = schema is Map<String, dynamic> ? schema['enum'] : null;
      final choices =
          values is List && values.isNotEmpty ? ' (${values.join(' ou ')})' : '';
      buffer.write('\n  argument : ${entry.key}$choices');
    }
  }
  return buffer.toString();
}

/// Rend un message d'historique, ou `null` s'il ne doit pas être montré.
String? _formatHistoryLine(ConversationMessage msg) {
  switch (msg.role) {
    case ConversationRole.user:
      final text = msg.content?.trim() ?? '';
      return text.isEmpty ? null : 'Utilisateur : $text';

    case ConversationRole.assistant:
      final calls = msg.toolCalls;
      if (calls != null && calls.isNotEmpty) {
        // Jamais sous la forme `TOOL x` ni « (tool call) » : rendu tel quel,
        // le modèle recopiait la ligne au tour suivant et redéclenchait la
        // caméra, quoi que dise l'utilisateur (observé sur device).
        final names = calls.map((c) => c.name).join(', ');
        return 'Kita : (a utilisé $names)';
      }
      final text = msg.content?.trim() ?? '';
      return text.isEmpty ? null : 'Kita : $text';

    case ConversationRole.tool:
      // Résultat interne (« Description en cours. ») : sans valeur pour la
      // décision, et autant de tokens de prefill en moins.
      return null;
  }
}

/// Construit le prompt de décision tool-use pour Gemma.
///
/// La conversation est le comportement par défaut, l'appel d'outil
/// l'exception. Les exemples négatifs valent mieux qu'une consigne
/// abstraite : un modèle 2B imite ce qu'il voit.
String buildLocalToolPrompt(
  String userMessage,
  List<ToolSpec> tools,
  List<ConversationMessage> history,
) {
  final toolDescriptions = tools.map(_formatToolForPrompt).join('\n');
  final historyText =
      history.map(_formatHistoryLine).whereType<String>().join('\n');

  return '''[Instructions]
Tu es Kita, une assistante vocale française pour personnes déficientes
visuelles. Tu réponds brièvement, en français, comme à l'oral.

Par défaut, tu réponds par du texte. N'appelle un outil que si l'utilisateur
demande explicitement cette action, maintenant.

Outils disponibles :
$toolDescriptions

Pour appeler un outil, réponds par cette seule ligne, sans rien d'autre :
TOOL describe
TOOL alert start

[Exemples]
Utilisateur : qu'est-ce qu'il y a devant moi ?
Kita : TOOL describe
Utilisateur : salut, ça va ?
Kita : Bonjour ! Ça va, et toi ?
Utilisateur : préviens-moi s'il y a un obstacle
Kita : TOOL alert start
Utilisateur : je ne t'ai pas demandé ça
Kita : Désolée. Que puis-je faire pour toi ?
Utilisateur : tu en penses quoi ?
Kita : Je n'ai pas encore d'avis. Dis-m'en plus.

${historyText.isNotEmpty ? '[Conversation]\n$historyText\n' : ''}Utilisateur : $userMessage
Kita :''';
}

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
/// Three-tier architecture:
/// 1. **Gemma** (bundled LLM) — rich text completion and vision via
///    flutter_gemma with Gemma3n E2B model.
/// 2. **Gemini Nano** (Android, AICore devices) — vision fallback via
///    ML Kit GenAI Image Description API.
/// 3. **ML Kit fallback** (Android/iOS) — OCR + image labels for a basic
///    "Je vois : personne, table, chaise" response.
///
/// For text: Gemma first, then keyword matching fallback.
/// For vision: Gemma first, then Gemini Nano, then ML Kit.
///
/// Always returns [ProviderTier.local] and works 100% offline.
class LocalProvider implements AIProvider {
  LocalProvider({
    TargetPlatform? platform,
    MlKitBridge? mlKitBridge,
    GeminiNanoBridge? geminiNanoBridge,
    GemmaBridge? gemmaBridge,
  })  : _platform = platform ?? defaultTargetPlatform,
        _mlKitBridge = mlKitBridge,
        _geminiNanoBridge = geminiNanoBridge,
        _gemmaBridge = gemmaBridge;

  static final _log = KitaLogger('AI');

  final TargetPlatform _platform;

  /// Injected ML Kit bridge for testability. When null, a real
  /// [MlKitBridgeImpl] is lazily created on first vision call.
  MlKitBridge? _mlKitBridge;

  /// Injected Gemini Nano bridge for testability. When null, a real
  /// [GeminiNanoBridgeImpl] is lazily created on first vision call
  /// (Android only).
  GeminiNanoBridge? _geminiNanoBridge;

  /// Injected Gemma bridge for testability.
  GemmaBridge? _gemmaBridge;

  /// Cached Gemma model status. Avoids re-checking on every call.
  GemmaModelStatus? _gemmaStatus;

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

    final stopwatch = Stopwatch()..start();

    // Tier 1: Try Gemma LLM for rich text responses.
    final gemmaResult = await _tryGemmaComplete(request, stopwatch);
    if (gemmaResult != null) return gemmaResult;

    // Tier 2: Fall back to keyword matching.
    stopwatch.stop();
    return Result.success(AIResponse(
      content: _localResponse(request.prompt),
      meta: AIResponseMeta(
        providerId: id,
        latency: stopwatch.elapsed,
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

    // Tier 1: Try Gemma vision (bundled LLM, all platforms).
    final gemmaResult = await _tryGemmaVision(image, prompt, stopwatch);
    if (gemmaResult != null) return gemmaResult;

    // Tier 2: Try Gemini Nano (Android only, AICore devices).
    if (_platform == TargetPlatform.android) {
      final nanoResult = await _tryGeminiNano(image, stopwatch);
      if (nanoResult != null) return nanoResult;
    }

    // Tier 3: Fall back to ML Kit (labels + OCR).
    return _tryMlKit(image, stopwatch);
  }

  @override
  Stream<String> visionStream(
    ImageData image,
    String prompt, {
    int? maxTokens,
  }) async* {
    if (!isAvailable) {
      throw AIProviderFailure(
        userMessage: 'IA locale non disponible sur cette plateforme.',
        logMessage: 'Local vision stream not available on $_platform',
        providerId: id,
      );
    }

    _log.debug('Processing local vision stream request');

    // Tier 1: Try Gemma streaming vision (native token-by-token).
    if (_gemmaBridge != null) {
      try {
        final status = await _checkGemmaStatus();
        if (status == GemmaModelStatus.ready) {
          var hasYielded = false;
          await for (final token
              in _gemmaBridge!.describeImageStream(image.bytes, prompt: prompt)) {
            hasYielded = true;
            yield token;
          }
          if (hasYielded) return;
        }
      } on Exception catch (e, stack) {
        _log.warning(
          'Gemma vision streaming failed, falling back',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // Tier 2: Try Gemini Nano (batch, yields full result as one chunk).
    if (_platform == TargetPlatform.android) {
      try {
        final bridge = _getOrCreateNanoBridge();
        final status = await _checkNanoAvailability(bridge);
        if (status == GeminiNanoStatus.available) {
          final result = await bridge.describeImage(image.bytes);
          if (result.description.isNotEmpty) {
            yield result.description;
            return;
          }
        }
      } on Exception catch (e, stack) {
        _log.warning(
          'Gemini Nano vision streaming failed, falling back',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // Tier 3: ML Kit fallback (batch, yields full result as one chunk).
    try {
      final bridge = _getOrCreateMlKitBridge();
      final result = await bridge.analyzeImage(
        image.bytes,
        width: image.width,
        height: image.height,
      );
      yield _formatVisionResult(result);
    } on Exception catch (e, stack) {
      _log.error('ML Kit vision stream failed', error: e, stackTrace: stack);
      throw AIProviderFailure(
        userMessage: 'Analyse d\'image locale échouée.',
        logMessage: 'ML Kit vision stream error: ${e.runtimeType}',
        providerId: id,
        cause: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    // Local provider has no API key — always valid.
    return const Result.success(null);
  }

  @override
  Stream<String> completeStream(AIRequest request) async* {
    if (_gemmaBridge == null) return;

    try {
      final status = await _checkGemmaStatus();
      if (status != GemmaModelStatus.ready) {
        _log.debug('Gemma not ready for streaming, returning empty stream');
        return;
      }

      yield* _gemmaBridge!.completeStream(request.prompt, maxTokens: request.maxTokens);
    } on Exception catch (e, stack) {
      _log.warning(
        'Gemma streaming failed',
        error: e,
        stackTrace: stack,
      );
      // Return empty stream on error — caller should handle absence.
    }
  }

  @override
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    if (!isAvailable) {
      return Result.failure(AIProviderFailure(
        userMessage: 'IA locale non disponible sur cette plateforme.',
        logMessage: 'Local provider not available for tool use on $_platform',
        providerId: id,
      ));
    }

    _log.debug('Processing local tool-use request via prompt engineering');

    final stopwatch = Stopwatch()..start();

    // Try Gemma with prompt-engineered tool use.
    if (_gemmaBridge != null) {
      try {
        final status = await _checkGemmaStatus();
        if (status == GemmaModelStatus.ready) {
          final toolPrompt = buildLocalToolPrompt(request.prompt, tools, history);
          final result = await _gemmaBridge!.complete(toolPrompt);
          stopwatch.stop();

          if (result.text.isNotEmpty) {
            final toolResponse = _parseGemmaToolResponse(
              result.text,
              stopwatch.elapsed,
            );
            if (toolResponse != null) {
              _log.info('Gemma tool-use completion done');
              return Result.success(toolResponse);
            }
          }
        }
      } on Exception catch (e, stack) {
        _log.warning(
          'Gemma tool-use completion failed',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // Fallback: return the text response without tool calls.
    stopwatch.stop();
    return Result.success(AIToolResponse(
      text: _localResponse(request.prompt),
      meta: AIResponseMeta(
        providerId: id,
        latency: stopwatch.elapsed,
        tier: ProviderTier.local,
      ),
    ));
  }

  /// Parse une réponse Gemma en appel d'outil, OU en réponse texte.
  ///
  /// Retourner `null` ici ferait retomber [completeWithTools] sur
  /// `_localResponse`, un répondeur en conserve : la vraie réponse
  /// conversationnelle du modèle serait perdue (régression observée).
  AIToolResponse? _parseGemmaToolResponse(String text, Duration latency) {
    final parsed = parseLocalToolResponse(text);
    final meta = AIResponseMeta(
      providerId: 'gemma',
      latency: latency,
      tier: ProviderTier.local,
    );
    if (parsed == null) {
      final trimmed = stripHallucinatedTurns(text);
      if (trimmed.isEmpty) return null;
      return AIToolResponse(text: trimmed, meta: meta);
    }
    return AIToolResponse(
      toolCalls: [
        ToolCall(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          name: parsed.name,
          arguments: parsed.arguments,
        ),
      ],
      meta: meta,
    );
  }

  /// Releases native resources. Must be called when the provider
  /// is no longer needed (e.g. via `ref.onDispose`).
  Future<void> dispose() async {
    await _gemmaBridge?.dispose();
    _gemmaBridge = null;
    await _geminiNanoBridge?.dispose();
    _geminiNanoBridge = null;
    await _mlKitBridge?.dispose();
    _mlKitBridge = null;
  }

  // ---------------------------------------------------------------------------
  // Gemma LLM (Tier 1)
  // ---------------------------------------------------------------------------

  /// Attempts Gemma text completion. Returns null if unavailable or failed
  /// (caller should fall through to keyword matching).
  Future<Result<AIResponse>?> _tryGemmaComplete(
    AIRequest request,
    Stopwatch stopwatch,
  ) async {
    if (_gemmaBridge == null) return null;

    try {
      final status = await _checkGemmaStatus();
      if (status != GemmaModelStatus.ready) {
        _log.debug('Gemma not ready (status: ${status.name}), '
            'falling back to keyword matching');
        return null;
      }

      final result = await _gemmaBridge!.complete(
        request.prompt,
        maxTokens: request.maxTokens,
      );
      stopwatch.stop();

      if (result.text.isEmpty) return null;

      _log.info('Gemma text completion done');
      return Result.success(AIResponse(
        content: result.text,
        meta: AIResponseMeta(
          providerId: 'gemma',
          latency: stopwatch.elapsed,
          tier: ProviderTier.local,
        ),
        status: AIResponseStatus.degraded,
      ));
    } on Exception catch (e, stack) {
      _log.warning(
        'Gemma text completion failed, falling back to keywords',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Attempts Gemma vision. Returns null if unavailable or failed
  /// (caller should fall through to Gemini Nano / ML Kit).
  Future<Result<AIResponse>?> _tryGemmaVision(
    ImageData image,
    String prompt,
    Stopwatch stopwatch,
  ) async {
    if (_gemmaBridge == null) return null;

    try {
      final status = await _checkGemmaStatus();
      if (status != GemmaModelStatus.ready) {
        _log.debug('Gemma not ready (status: ${status.name}), '
            'falling back to other vision providers');
        return null;
      }

      final result = await _gemmaBridge!.describeImage(
        image.bytes,
        prompt: prompt,
      );
      stopwatch.stop();

      if (result.description.isEmpty) return null;

      _log.info('Gemma vision completed');
      return Result.success(AIResponse(
        content: result.description,
        meta: AIResponseMeta(
          providerId: 'gemma',
          latency: stopwatch.elapsed,
          tier: ProviderTier.local,
        ),
        status: AIResponseStatus.degraded,
      ));
    } on Exception catch (e, stack) {
      _log.warning(
        'Gemma vision failed, falling back to other providers',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Check and cache Gemma model status.
  Future<GemmaModelStatus> _checkGemmaStatus() async {
    if (_gemmaStatus == GemmaModelStatus.ready) return GemmaModelStatus.ready;
    _gemmaStatus = await _gemmaBridge!.checkStatus();
    return _gemmaStatus!;
  }

  // ---------------------------------------------------------------------------
  // Gemini Nano (Tier 2)
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
        userMessage: 'Analyse d\'image locale échouée.',
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
      return 'Attention ! Obstacle potentiel détecté.';
    }

    if (lower.contains('heure') || lower.contains('time')) {
      return 'Je ne peux pas lire l\'heure en mode hors-ligne.';
    }

    if (lower.contains('lis') ||
        lower.contains('texte') ||
        lower.contains('read') ||
        lower.contains('lire')) {
      return 'Texte détecté mais lecture détaillée non disponible hors-ligne.';
    }

    if (lower.contains('aide') || lower.contains('help')) {
      return 'Mode hors-ligne : je peux détecter des obstacles et lire du texte avec la caméra.';
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
      return 'Pour décrire une image, utilisez la caméra. Analyse locale disponible.';
    }

    return 'Réponse locale limitée. Connectez-vous pour une réponse complète.';
  }
}
