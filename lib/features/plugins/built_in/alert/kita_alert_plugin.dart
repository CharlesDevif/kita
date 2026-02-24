import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../../io/domain/haptic_service.dart';
import '../../../orchestration/domain/kita_agent.dart';
import '../../../orchestration/domain/models/agent_input.dart';
import '../../../orchestration/domain/models/agent_manifest.dart';
import '../../../orchestration/domain/models/agent_message.dart';
import '../../../orchestration/domain/models/agent_output.dart';
import '../../../orchestration/domain/models/output_priority.dart';
import '../../domain/trust_level.dart';
import '../../domain/voice_command.dart';
import '../../../../shared/widgets/kita_alert.dart';
import 'alert_models.dart';
import 'alert_viewport.dart';

/// Minimum confidence to trigger an alert.
const double _minConfidence = 0.80;

/// Auto-dismiss delay for alerts.
const Duration _autoDismissDelay = Duration(seconds: 5);

/// Window for "C'est quoi ?" to reference the last detection.
const Duration _descriptionWindow = Duration(seconds: 10);

/// Built-in agent for obstacle detection alerts.
///
/// Consumes detections from [ObstacleDetector], classifies urgency,
/// and produces synchronized multi-modal alerts via [OutputHandle].
///
/// This agent is persistent: it runs as long as Kita is active.
/// It never calls TTS/Haptic/ProfileAdapter directly — all output
/// goes through [context.output].
class KitaAlertPlugin implements KitaAgent {
  static final _log = KitaLogger('Plugin.Alert');

  // Agent state
  AgentContext? _context;
  bool _terminated = false;

  // Alert state
  AlertViewportState? _currentAlertState;
  ObstacleDetection? _lastDetection;
  DateTime? _lastDetectionTime;
  Timer? _alertTimer;

  @override
  AgentManifest get manifest => const AgentManifest(
        id: 'com.kita.alert',
        name: 'Alert',
        version: '1.0.0',
        description: 'Detection et alerte d obstacles en temps reel',
        trustLevel: TrustLevel.official,
        agentType: AgentType.persistent,
        priority: AgentPriority.critical,
        permissions: ['camera', 'haptic', 'tts'],
        capabilities: ['obstacle_detection', 'real_time_alert'],
        subscriptions: {
          AgentMessageType.cancelAll,
          AgentMessageType.userCommand,
        },
      );

  @override
  List<VoiceCommand> get voiceCommands => const [
        VoiceCommand(
          trigger: 'ok',
          description: "Fermer l'alerte en cours",
          aliases: ['d accord', 'compris', 'merci'],
        ),
        VoiceCommand(
          trigger: "c'est quoi",
          description: 'Decrire l obstacle detecte en detail',
          aliases: ['quoi', 'quel obstacle', 'decris obstacle'],
        ),
      ];

  @override
  Future<void> onSpawn(AgentContext context) async {
    _context = context;
    _terminated = false;
    _log.info('Alert agent spawned');
  }

  @override
  Future<void> onSuspend() async {
    // Persistent agent: suspend stops detection processing.
    _dismissAlert();
    _log.info('Alert agent suspended');
  }

  @override
  Future<void> onResume() async {
    // Resume detection processing.
    _log.info('Alert agent resumed');
  }

  @override
  Future<void> onTerminate() async {
    _terminated = true;

    // 1. Cancel timers (synchronous)
    _dismissAlert();

    // 2. Nullify context (last)
    _context = null;

    _log.info('Alert agent terminated');
  }

  @override
  void onBusMessage(AgentMessage message) {
    if (_terminated) return;

    switch (message.type) {
      case AgentMessageType.cancelAll:
        _log.info('Cancel all received, dismissing alert');
        _dismissAlert();
      default:
        break;
    }
  }

  @override
  Future<Result<AgentOutput>> handleInput(AgentInput input) async {
    if (_terminated || _context == null) {
      return const Result.failure(PluginFailure(
        userMessage: 'Le plugin Alert n est pas actif.',
        logMessage: 'KitaAlertPlugin: handleInput called while inactive',
        pluginId: 'com.kita.alert',
      ));
    }

    switch (input.command) {
      case 'obstacle_detected':
        return _handleObstacleDetected(input.params);
      case 'ok':
      case 'dismiss':
        _dismissAlert();
        return const Result.success(AgentOutput(
          type: AgentOutputType.text,
          content: 'Alerte fermee',
        ));
      case "c'est quoi":
      case 'describe_obstacle':
        return _handleDescribeObstacle();
      default:
        _log.warning('Unknown command: ${input.command}');
        return Result.failure(PluginFailure(
          userMessage: 'Commande non reconnue.',
          logMessage:
              'KitaAlertPlugin: unknown command ${input.command}',
          pluginId: 'com.kita.alert',
        ));
    }
  }

  @override
  Widget? buildViewport(BuildContext context) {
    final state = _currentAlertState;
    if (state == null) return null;
    return AlertViewport(
      message: state.message,
      severity: state.severity,
      onDismiss: _dismissAlert,
    );
  }

  Future<Result<AgentOutput>> _handleObstacleDetected(
    Map<String, dynamic> params,
  ) async {
    final detection = ObstacleDetection.fromParams(params);

    // Filter low confidence
    if (detection.confidence <= _minConfidence) {
      _log.debug('Detection ignored: confidence ${detection.confidence}');
      return const Result.success(AgentOutput(
        type: AgentOutputType.text,
        content: 'Detection ignoree: confiance insuffisante',
      ));
    }

    // Classify urgency
    final urgency = classifyUrgency(detection.distance);

    if (urgency == AlertUrgency.ignored) {
      _log.debug('Detection ignored: distance ${detection.distance}m');
      return const Result.success(AgentOutput(
        type: AgentOutputType.text,
        content: 'Detection ignoree: trop loin',
      ));
    }

    // Race condition handling: if immediate alert in progress, ignore preventive
    if (_currentAlertState != null &&
        _currentAlertState!.severity == AlertSeverity.immediate &&
        urgency == AlertUrgency.preventive) {
      _log.debug('Preventive ignored: immediate alert in progress');
      return const Result.success(AgentOutput(
        type: AgentOutputType.text,
        content: 'Alerte immediate en cours',
      ));
    }

    // Build message
    final message =
        buildAlertMessage(urgency, detection.type, detection.distance);
    final severity = urgency == AlertUrgency.immediate
        ? AlertSeverity.immediate
        : AlertSeverity.preventive;
    final outputPriority = urgency == AlertUrgency.immediate
        ? OutputPriority.critical
        : OutputPriority.high;

    // Store detection
    _lastDetection = detection;
    _lastDetectionTime = _context!.clock.now();

    // Cancel previous alert timer
    _alertTimer?.cancel();

    // Trigger multi-modal alert via OutputHandle
    await _triggerAlert(message, severity, outputPriority, urgency);

    // Start auto-dismiss timer
    _alertTimer = Timer(_autoDismissDelay, _dismissAlert);

    _log.info('Alert triggered: ${urgency.name} - ${detection.type}');

    return Result.success(AgentOutput(
      type: AgentOutputType.alert,
      content: message,
      metadata: {
        'urgency': urgency.name,
        'type': detection.type,
        'distance': detection.distance,
      },
    ));
  }

  Future<void> _triggerAlert(
    String message,
    AlertSeverity severity,
    OutputPriority outputPriority,
    AlertUrgency urgency,
  ) async {
    final context = _context;
    if (context == null || _terminated) return;

    // Speak via OutputHandle (OutputCoordinator handles TTS interruption in 12.3)
    await context.output.speak(message, priority: outputPriority);

    // Haptic via OutputHandle
    if (urgency == AlertUrgency.immediate) {
      await context.output.haptic(
        HapticPattern.danger,
        priority: outputPriority,
      );
    } else {
      await context.output.haptic(
        HapticPattern.warning,
        priority: outputPriority,
      );
    }

    // Update visual state
    _currentAlertState = AlertViewportState(
      message: message,
      severity: severity,
    );
  }

  Future<Result<AgentOutput>> _handleDescribeObstacle() async {
    final context = _context;
    if (context == null || _terminated) {
      return const Result.failure(PluginFailure(
        userMessage: 'Le plugin Alert n est pas actif.',
        logMessage: 'KitaAlertPlugin: describe obstacle called while inactive',
        pluginId: 'com.kita.alert',
      ));
    }

    final detection = _lastDetection;
    final detectionTime = _lastDetectionTime;

    if (detection != null &&
        detectionTime != null &&
        context.clock.now().difference(detectionTime) < _descriptionWindow) {
      final description = buildDetailedDescription(detection);
      await context.output.speak(description, priority: OutputPriority.high);
      _log.info('Obstacle description provided');
      return Result.success(AgentOutput(
        type: AgentOutputType.text,
        content: description,
      ));
    }

    const noObstacleMessage = 'Aucun obstacle recent';
    await context.output.speak(noObstacleMessage);
    return const Result.success(AgentOutput(
      type: AgentOutputType.text,
      content: noObstacleMessage,
    ));
  }

  void _dismissAlert() {
    _alertTimer?.cancel();
    _alertTimer = null;
    _currentAlertState = null;
    _log.debug('Alert dismissed');
  }
}
