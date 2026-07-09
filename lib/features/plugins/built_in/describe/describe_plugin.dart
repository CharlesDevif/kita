import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/sentence_buffer.dart';
import '../../../ai/domain/image_data.dart';
import '../../../orchestration/domain/kita_agent.dart';
import '../../../orchestration/domain/models/agent_input.dart';
import '../../../orchestration/domain/models/agent_manifest.dart';
import '../../../orchestration/domain/models/agent_message.dart';
import '../../../orchestration/domain/models/agent_output.dart';
import '../../../orchestration/domain/models/output_priority.dart';
import '../../../orchestration/domain/output_handle.dart';
import '../../domain/trust_level.dart';
import '../../domain/voice_command.dart';
import 'describe_state.dart';
import 'describe_viewport.dart';

/// KitaDescribePlugin — Photo description vocale avec enchainement.
///
/// Pipeline: capture photo -> strip EXIF -> AI vision -> output.speak().
/// Supports chaining: "plus de details", "repete", "merci" / silence timeout.
///
/// ## Output pattern: Agent -> OutputHandle -> OutputCoordinator -> TTS
///
/// This agent uses [OutputHandle] for all output. It never calls TTS or
/// HapticService directly. The OutputHandle delegates to the
/// OutputCoordinator (story 12.3) for priority arbitration.
///
/// ## Silence timeout
///
/// After speech completes (via [OutputHandle.speechEvents]), the agent
/// starts a silence timer of [silenceTimeout] via [Clock.delayed]. When
/// the timer expires, it calls [OutputHandle.complete()] to signal
/// the Supervisor to terminate this agent.
class KitaDescribePlugin implements KitaAgent {
  static final _log = KitaLogger('Plugin.Describe');

  /// Prompt de description par défaut : bref, et surtout **première phrase très
  /// courte**. Le SentenceBuffer n'émet qu'une phrase terminée : une première
  /// phrase de 45 tokens = 25 s de silence mesurées sur device.
  ///
  /// La lecture du texte visible est conservée : pour une personne aveugle,
  /// lire un panneau ou une étiquette vaut plus que la brièveté.
  static const describePrompt = '''
Décris cette image en français pour une personne aveugle.
Commence par une phrase très courte (5 à 8 mots) nommant l'élément principal.
Puis ajoute 1 ou 2 phrases de détails : situe les objets (gauche, droite,
devant) et signale le texte visible important. Sois concret.
N'identifie jamais les personnes. Ne mentionne pas que c'est une image.''';

  /// Prompt for detailed description (5-8 sentences).
  static const detailedPrompt = '''
Décris cette image en détail en français pour une personne aveugle.
Sois exhaustif et précis. Inclus :
- La scène complète : lieu, moment de la journée, ambiance
- Tous les objets visibles et leur position relative (gauche, droite, devant, derrière, haut, bas)
- Les personnes présentes : nombre, posture, activité, vêtements (sans les identifier)
- Tout le texte visible : panneaux, étiquettes, écrans, affiches
- Les couleurs, textures et matériaux
- Les obstacles ou dangers potentiels
- Les sons ou mouvements qu'on pourrait deviner (vent, eau, foule)

Réponds en 5-8 phrases. Pas de formule d'introduction.''';

  /// Duration of silence before auto-returning to passive mode.
  static const silenceTimeout = Duration(seconds: 5);

  /// Whether the agent has been terminated, to prevent timer callbacks
  /// from modifying state after termination.
  bool _terminated = false;

  /// Current conversation state.
  DescribeState _state = DescribeState.idle;

  /// Timer for auto-return to passive mode after silence.
  Timer? _silenceTimer;

  /// Subscription to speech events from OutputHandle.
  StreamSubscription<SpeechEvent>? _speechSubscription;

  /// The agent context, set during onSpawn.
  AgentContext? _context;

  /// Expose state for testing.
  DescribeState get state => _state;

  @override
  AgentManifest get manifest => const AgentManifest(
        id: 'com.kita.describe',
        name: 'Kita Describe',
        version: '1.0.0',
        description: 'Description visuelle de scenes par IA',
        trustLevel: TrustLevel.official,
        agentType: AgentType.onDemand,
        priority: AgentPriority.standard,
        permissions: ['camera', 'ai.vision'],
        capabilities: ['vision', 'text'],
        compatibleProfiles: ['blind', 'low_vision', 'standard'],
        subscriptions: {
          AgentMessageType.cancelAll,
          AgentMessageType.interruptRequest,
          AgentMessageType.userCommand,
        },
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
  Future<void> onSpawn(AgentContext context) async {
    _terminated = false;
    _context = context;
    _state = DescribeState.idle;

    // Subscribe to speech events for the silence timer.
    _speechSubscription = context.output.speechEvents.listen((event) {
      if (_terminated) return;
      if (event == SpeechEvent.completed) {
        _startSilenceTimer();
      } else if (event == SpeechEvent.interrupted) {
        _silenceTimer?.cancel();
        _silenceTimer = null;
      }
    });

    _log.info('Describe agent spawned');
  }

  @override
  Future<void> onSuspend() async {
    // No-op for onDemand agents.
    _log.info('Describe agent suspended');
  }

  @override
  Future<void> onResume() async {
    // No-op for onDemand agents.
    _log.info('Describe agent resumed');
  }

  @override
  Future<void> onTerminate() async {
    _terminated = true;

    // 1. Cancel timers (synchronous)
    _silenceTimer?.cancel();
    _silenceTimer = null;

    // 2. Cancel stream subscriptions (async)
    await _speechSubscription?.cancel();
    _speechSubscription = null;

    // 3. Reset state
    _state = DescribeState.idle;

    // 4. Nullify context (last, after all cleanup)
    _context = null;

    _log.info('Describe agent terminated');
  }

  @override
  void onBusMessage(AgentMessage message) {
    if (_terminated) return;

    switch (message.type) {
      case AgentMessageType.interruptRequest:
        _log.info('Interrupt request received, cancelling silence timer');
        _silenceTimer?.cancel();
        _silenceTimer = null;

      case AgentMessageType.cancelAll:
        _log.info('Cancel all received, cancelling silence timer');
        _silenceTimer?.cancel();
        _silenceTimer = null;

      default:
        break;
    }
  }

  @override
  Future<Result<AgentOutput>> handleInput(AgentInput input) async {
    _silenceTimer?.cancel();

    final command = input.command;
    _log.info('Handling command: $command');

    return switch (command) {
      'decris' || 'describe' => _handleDescribe(),
      'plus de details' || 'details' || 'detaille' => _handleMoreDetails(),
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
  ///
  /// Uses streaming vision when available: tokens are piped through
  /// [SentenceBuffer] to [OutputHandle.speak()] sentence-by-sentence,
  /// reducing perceived latency from ~8s to ~1.5s for the first sentence.
  Future<Result<AgentOutput>> _handleDescribe() async {
    final context = _context;
    if (context == null) {
      return Result.failure(PluginFailure(
        userMessage: "L'agent n'est pas prêt.",
        logMessage: 'Describe: handleDescribe called without context',
        pluginId: manifest.id,
      ));
    }

    _log.info('Starting describe pipeline');

    // Step 1: Capture photo via sandboxed sensor access
    final captureResult = await context.sensors.capturePhoto();
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

        // EXIF metadata is stripped by the sandbox (SandboxedSensorAccess)
        // so the image is already privacy-safe at this point.
        final imageToSend = value;

        // Step 2: Stream AI vision tokens → SentenceBuffer → TTS
        return _streamVision(
          context: context,
          image: imageToSend,
          prompt: describePrompt,
          updateState: (content, isOffline) {
            _state = _state.withDescription(imageToSend, content, offline: isOffline);
          },
        );
    }
  }

  /// Handle "plus de details": re-send same image with enriched prompt.
  Future<Result<AgentOutput>> _handleMoreDetails() async {
    final context = _context;
    if (context == null || _state.imageData == null) {
      _log.warning('More details requested but no image in state');
      return Result.failure(PluginFailure(
        userMessage: "Dis 'décris' d'abord pour prendre une photo.",
        logMessage: 'Describe: more details without prior image',
        pluginId: manifest.id,
      ));
    }

    _log.info('Requesting detailed description');

    return _streamVision(
      context: context,
      image: _state.imageData!,
      prompt: detailedPrompt,
      updateState: (content, isOffline) {
        _state = _state.withDetailedDescription(content, offline: isOffline);
      },
      extraMetadata: const {'detailed': true},
    );
  }

  /// Handle "repete": re-read last description without calling AI.
  Future<Result<AgentOutput>> _handleRepeat() async {
    final lastDesc = _state.lastDescription;
    if (lastDesc == null) {
      _log.warning('Repeat requested but no description in state');
      return Result.failure(PluginFailure(
        userMessage: "Il n'y a rien à répéter.",
        logMessage: 'Describe: repeat without prior description',
        pluginId: manifest.id,
      ));
    }

    _log.info('Repeating last description');

    if (!_terminated && _context != null) {
      await _context!.output.speak(
        lastDesc,
        priority: OutputPriority.standard,
      );
    }

    return Result.success(AgentOutput(
      type: AgentOutputType.text,
      content: lastDesc,
      metadata: const {'repeated': true},
    ));
  }

  /// Handle "merci": return to passive mode.
  Future<Result<AgentOutput>> _handleThanks() async {
    _log.info('Returning to passive mode (merci)');
    _silenceTimer?.cancel();
    // Transition through completed before returning to idle.
    _state = _state.toCompleted();
    _state = DescribeState.idle;

    // Signal completion to supervisor
    if (!_terminated && _context != null) {
      _context!.output.complete();
    }

    return const Result.success(AgentOutput(
      type: AgentOutputType.text,
      content: '',
      metadata: {'action': 'return_passive'},
    ));
  }

  /// Stream AI vision tokens through [SentenceBuffer] → [OutputHandle].
  ///
  /// Shared by [_handleDescribe] and [_handleMoreDetails]. Streams tokens
  /// from the AI, speaks each sentence as it's detected, and returns the
  /// full accumulated text as an [AgentOutput].
  Future<Result<AgentOutput>> _streamVision({
    required AgentContext context,
    required ImageData image,
    required String prompt,
    required void Function(String content, bool isOffline) updateState,
    Map<String, Object> extraMetadata = const {},
  }) async {
    try {
      final fullText = StringBuffer();
      final buffer = SentenceBuffer(
        onSentence: (sentence) {
          if (!_terminated) {
            unawaited(context.output.speak(
              sentence,
              priority: OutputPriority.standard,
            ));
          }
        },
      );

      await for (final token in context.ai.visionStream(image, prompt)) {
        if (_terminated) break;
        fullText.write(token);
        buffer.add(token);
      }

      buffer.flush();

      final content = fullText.toString();
      if (content.isEmpty) {
        _log.warning('Vision stream returned empty content');
        return Result.failure(PluginFailure(
          userMessage: "Je n'ai pas pu analyser l'image.",
          logMessage: 'Describe: vision stream returned empty',
          pluginId: manifest.id,
        ));
      }

      _log.info('Streaming description complete (${content.length} chars)');

      updateState(content, false);

      return Result.success(AgentOutput(
        type: AgentOutputType.text,
        content: content,
        metadata: {
          'streaming': true,
          ...extraMetadata,
        },
      ));
    } on KitaFailure catch (failure) {
      _log.error('Vision stream failed: ${failure.logMessage}');
      return Result.failure(PluginFailure(
        userMessage: "Je n'ai pas pu analyser l'image.",
        logMessage: 'Describe: vision stream failed: ${failure.logMessage}',
        pluginId: manifest.id,
      ));
    } on Exception catch (e, stack) {
      _log.error('Vision stream failed', error: e, stackTrace: stack);
      return Result.failure(PluginFailure(
        userMessage: "Je n'ai pas pu analyser l'image.",
        logMessage: 'Describe: vision stream error: $e',
        pluginId: manifest.id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  /// Start the silence timer via [Clock.delayed].
  ///
  /// After [silenceTimeout], calls [OutputHandle.complete()] to signal
  /// that this agent is done and should be terminated by the Supervisor.
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = _context?.clock.delayed(silenceTimeout, () {
      if (_terminated) return;
      _log.info('Silence timeout, signaling completion');
      _state = DescribeState.idle;
      _context?.output.complete();
    });
  }

  @override
  Widget? buildViewport(BuildContext context) {
    if (_state.phase == DescribePhase.idle) return null;
    return DescribeViewport(state: _state);
  }
}
