import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../../ai/domain/ai_response.dart';
import '../../../io/data/exif_stripper.dart';
import '../../domain/kita_plugin.dart';
import '../../domain/plugin_manifest.dart';
import '../../domain/plugin_request.dart';
import '../../domain/plugin_response.dart';
import '../../domain/trust_level.dart';
import '../../domain/voice_command.dart';
import 'describe_state.dart';
import 'describe_viewport.dart';

/// KitaDescribePlugin — Photo description vocale avec enchainement.
///
/// Pipeline: capture photo -> strip EXIF -> AI vision -> PluginResponse.text.
/// Supports chaining: "plus de details", "repete", "merci" / silence timeout.
/// The TTS output is handled by the Shell via ProfileAdapter.
class KitaDescribePlugin implements KitaPlugin {
  static final _log = KitaLogger('Plugin.Describe');

  /// Prompt for initial concise description (2-3 sentences).
  static const describePrompt = '''
Decris cette image en francais pour une personne aveugle.
Sois precis et utile. Inclus :
- Les objets principaux et leur position relative (gauche, droite, devant, derriere)
- Les personnes presentes (nombre, posture, activite) sans les identifier
- Le texte visible (panneaux, etiquettes, ecrans)
- Les couleurs dominantes et l'ambiance (interieur/exterieur, luminosite)
- Les obstacles ou dangers potentiels

Reponds en 2-3 phrases concises. Pas de formule d'introduction.''';

  /// Prompt for detailed description (5-8 sentences).
  static const detailedPrompt = '''
Decris cette image en detail en francais pour une personne aveugle.
Sois exhaustif et precis. Inclus :
- La scene complete : lieu, moment de la journee, ambiance
- Tous les objets visibles et leur position relative (gauche, droite, devant, derriere, haut, bas)
- Les personnes presentes : nombre, posture, activite, vetements (sans les identifier)
- Tout le texte visible : panneaux, etiquettes, ecrans, affiches
- Les couleurs, textures et materiaux
- Les obstacles ou dangers potentiels
- Les sons ou mouvements qu'on pourrait deviner (vent, eau, foule)

Reponds en 5-8 phrases. Pas de formule d'introduction.''';

  /// Duration of silence before auto-returning to passive mode.
  static const silenceTimeout = Duration(seconds: 5);

  /// Current conversation state.
  DescribeState _state = DescribeState.idle;

  /// Timer for auto-return to passive mode after silence.
  Timer? _silenceTimer;

  /// Optional callback invoked when the plugin auto-returns to passive mode
  /// after the silence timeout expires. Allows the Shell to react to the
  /// transition without polling the plugin state.
  void Function()? onReturnPassive;

  /// Expose state for testing.
  DescribeState get state => _state;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'com.kita.describe',
        name: 'Kita Describe',
        version: '1.0.0',
        description: 'Description visuelle de scenes par IA',
        trustLevel: TrustLevel.official,
        permissions: ['camera', 'ai.vision'],
        capabilities: ['vision', 'text'],
        compatibleProfiles: ['blind', 'low_vision', 'standard'],
        voiceCommands: ['decris', 'describe', 'plus de details', 'repete', 'merci'],
      );

  @override
  List<VoiceCommand> get voiceCommands => const [
        VoiceCommand(
          trigger: 'decris',
          description: 'Decrit ce que la camera voit',
          aliases: ['describe', 'decrit', 'decrivez'],
        ),
        VoiceCommand(
          trigger: 'plus de details',
          description: 'Description approfondie de la scene',
          aliases: ['detaille', 'details', 'approfondir', 'en detail'],
        ),
      ];

  @override
  Future<void> onActivate() async {
    _log.info('Describe plugin activated');
  }

  @override
  Future<void> onDeactivate() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _state = DescribeState.idle;
    _log.info('Describe plugin deactivated');
  }

  @override
  Future<Result<PluginResponse>> handleRequest(PluginRequest request) async {
    _silenceTimer?.cancel();

    final command = request.command;
    _log.info('Handling command: $command');

    return switch (command) {
      'decris' || 'describe' => _handleDescribe(request),
      'plus de details' || 'details' || 'detaille' => _handleMoreDetails(request),
      'repete' => _handleRepeat(),
      'merci' => _handleThanks(),
      _ => Future.value(Result.failure(PluginFailure(
        userMessage: 'Commande non reconnue.',
        logMessage: 'Describe: unknown command: $command',
        pluginId: manifest.id,
      ))),
    };
  }

  /// Handle initial "decris" command: capture -> strip EXIF -> AI vision.
  Future<Result<PluginResponse>> _handleDescribe(PluginRequest request) async {
    _log.info('Starting describe pipeline');

    // Step 1: Capture photo via sandboxed sensor access
    final captureResult = await request.sensors.capturePhoto();
    switch (captureResult) {
      case Failure(:final failure):
        _log.error('Photo capture failed: ${failure.logMessage}');
        return Result.failure(PluginFailure(
          userMessage: 'Impossible de prendre la photo.',
          logMessage: 'Describe: camera capture failed: ${failure.logMessage}',
          pluginId: manifest.id,
        ));
      case Success(:final value):
        _log.info('Photo captured: ${value.bytes.length} bytes');

        // Step 2: Strip EXIF metadata for privacy
        final imageToSend = switch (ExifStripper.strip(value)) {
          Success(:final value) => value,
          Failure(:final failure) => () {
              _log.warning(
                'EXIF strip failed, using original image: ${failure.logMessage}',
              );
              return value;
            }(),
        };

        // Step 3: Send to AI vision via sandboxed AI access
        final aiResult = await request.ai.vision(imageToSend, describePrompt);
        switch (aiResult) {
          case Failure(:final failure):
            _log.error('AI vision failed: ${failure.logMessage}');
            return Result.failure(PluginFailure(
              userMessage: "Je n'ai pas pu analyser l'image.",
              logMessage:
                  'Describe: AI vision failed: ${failure.logMessage}',
              pluginId: manifest.id,
            ));
          case Success(:final value):
            final isOffline = value.status == AIResponseStatus.degraded;
            _log.info('Description received (${value.content.length} chars, offline=$isOffline)');

            // Update state for chaining
            _state = _state.withDescription(
              imageToSend,
              value.content,
              offline: isOffline,
            );

            _startSilenceTimer();

            final content = isOffline
                ? 'Mode local, la description est simplifiee. ${value.content}'
                : value.content;

            return Result.success(PluginResponse(
              type: PluginResponseType.text,
              content: content,
              metadata: {
                'provider': value.meta.providerId,
                'latency_ms': value.meta.latency.inMilliseconds,
                'tier': value.meta.tier.name,
                if (isOffline) 'offline': true,
              },
            ));
        }
    }
  }

  /// Handle "plus de details": re-send same image with enriched prompt.
  Future<Result<PluginResponse>> _handleMoreDetails(
      PluginRequest request) async {
    if (_state.imageData == null) {
      _log.warning('More details requested but no image in state');
      return Result.failure(PluginFailure(
        userMessage: "Dis 'decris' d'abord pour prendre une photo.",
        logMessage: 'Describe: more details without prior image',
        pluginId: manifest.id,
      ));
    }

    _log.info('Requesting detailed description');

    final aiResult =
        await request.ai.vision(_state.imageData!, detailedPrompt);
    switch (aiResult) {
      case Failure(:final failure):
        _log.error('AI vision (detailed) failed: ${failure.logMessage}');
        return Result.failure(PluginFailure(
          userMessage: "Je n'ai pas pu obtenir plus de details.",
          logMessage: 'Describe: AI vision (detailed) failed: ${failure.logMessage}',
          pluginId: manifest.id,
        ));
      case Success(:final value):
        final isOffline = value.status == AIResponseStatus.degraded;
        _log.info(
            'Detailed description received (${value.content.length} chars)');

        _state = _state.withDetailedDescription(
          value.content,
          offline: isOffline,
        );

        _startSilenceTimer();

        final content = isOffline
            ? 'Mode local, la description est simplifiee. ${value.content}'
            : value.content;

        return Result.success(PluginResponse(
          type: PluginResponseType.text,
          content: content,
          metadata: {
            'provider': value.meta.providerId,
            'latency_ms': value.meta.latency.inMilliseconds,
            'tier': value.meta.tier.name,
            'detailed': true,
            if (isOffline) 'offline': true,
          },
        ));
    }
  }

  /// Handle "repete": re-read last description without calling AI.
  Future<Result<PluginResponse>> _handleRepeat() async {
    final lastDesc = _state.lastDescription;
    if (lastDesc == null) {
      _log.warning('Repeat requested but no description in state');
      return Result.failure(PluginFailure(
        userMessage: "Il n'y a rien a repeter.",
        logMessage: 'Describe: repeat without prior description',
        pluginId: manifest.id,
      ));
    }

    _log.info('Repeating last description');
    _startSilenceTimer();

    return Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: lastDesc,
      metadata: {'repeated': true},
    ));
  }

  /// Handle "merci": return to passive mode.
  ///
  /// Returns a [PluginResponse] with `metadata['action'] == 'return_passive'`
  /// to signal to the Shell that the plugin is done and wants to yield control.
  /// This is the explicit-command counterpart to the silence timer's
  /// [onReturnPassive] callback.
  Future<Result<PluginResponse>> _handleThanks() async {
    _log.info('Returning to passive mode (merci)');
    _silenceTimer?.cancel();
    _state = DescribeState.idle;

    return const Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: '',
      metadata: {'action': 'return_passive'},
    ));
  }

  /// Start the silence timer. After [silenceTimeout], auto-return to passive.
  /// Calls [onReturnPassive] if set, so the Shell can react to the transition.
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () {
      _log.info('Silence timeout, returning to passive mode');
      _state = DescribeState.idle;
      onReturnPassive?.call();
    });
  }

  @override
  Widget? buildViewport(BuildContext context) {
    if (_state.phase == DescribePhase.idle) return null;
    return DescribeViewport(state: _state);
  }
}
