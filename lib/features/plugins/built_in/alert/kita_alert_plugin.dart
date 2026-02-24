import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../../io/domain/haptic_service.dart';
import '../../../io/domain/tts_service.dart';
import '../../../plugins/domain/kita_plugin.dart';
import '../../../plugins/domain/plugin_manifest.dart';
import '../../../plugins/domain/plugin_request.dart';
import '../../../plugins/domain/plugin_response.dart';
import '../../../plugins/domain/trust_level.dart';
import '../../../plugins/domain/voice_command.dart';
import '../../../../shared/multi_modal/profile_adapter.dart';
import '../../../../shared/widgets/kita_alert.dart';
import 'alert_models.dart';
import 'alert_viewport.dart';

/// Minimum confidence to trigger an alert.
const double _minConfidence = 0.80;

/// Auto-dismiss delay for alerts.
const Duration _autoDismissDelay = Duration(seconds: 5);

/// Window for "C'est quoi ?" to reference the last detection.
const Duration _descriptionWindow = Duration(seconds: 10);

/// Built-in plugin for obstacle detection alerts.
///
/// Consumes detections from [ObstacleDetector], classifies urgency,
/// and produces synchronized multi-modal alerts via [ProfileAdapter].
class KitaAlertPlugin implements KitaPlugin {
  KitaAlertPlugin({
    required this.ttsService,
    required this.hapticService,
    required this.profileAdapter,
  });

  final TTSService ttsService;
  final HapticService hapticService;
  final ProfileAdapter profileAdapter;

  static final _log = KitaLogger('Plugin.Alert');

  // Alert state
  AlertViewportState? _currentAlertState;
  ObstacleDetection? _lastDetection;
  DateTime? _lastDetectionTime;
  Timer? _alertTimer;
  bool _active = false;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'com.kita.alert',
        name: 'Alert',
        version: '1.0.0',
        description: 'Detection et alerte d obstacles en temps reel',
        trustLevel: TrustLevel.official,
        permissions: ['camera', 'haptic', 'tts'],
        capabilities: ['obstacle_detection', 'real_time_alert'],
        voiceCommands: ['ok', "c'est quoi"],
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
  Future<void> onActivate() async {
    _active = true;
    _log.info('Plugin activated');
  }

  @override
  Future<void> onDeactivate() async {
    _dismissAlert();
    _active = false;
    _log.info('Plugin deactivated');
  }

  @override
  Future<Result<PluginResponse>> handleRequest(PluginRequest request) async {
    if (!_active) {
      return const Result.failure(PluginFailure(
        userMessage: 'Le plugin Alert n est pas actif.',
        logMessage: 'KitaAlertPlugin: handleRequest called while inactive',
        pluginId: 'com.kita.alert',
      ));
    }

    switch (request.command) {
      case 'obstacle_detected':
        return _handleObstacleDetected(request.params);
      case 'ok':
      case 'dismiss':
        _dismissAlert();
        return const Result.success(PluginResponse(
          type: PluginResponseType.text,
          content: 'Alerte fermee',
        ));
      case "c'est quoi":
      case 'describe_obstacle':
        return _handleDescribeObstacle();
      default:
        _log.warning('Unknown command: ${request.command}');
        return Result.failure(PluginFailure(
          userMessage: 'Commande non reconnue.',
          logMessage:
              'KitaAlertPlugin: unknown command ${request.command}',
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

  Future<Result<PluginResponse>> _handleObstacleDetected(
    Map<String, dynamic> params,
  ) async {
    final detection = ObstacleDetection.fromParams(params);

    // Filter low confidence
    if (detection.confidence <= _minConfidence) {
      _log.debug('Detection ignored: confidence ${detection.confidence}');
      return const Result.success(PluginResponse(
        type: PluginResponseType.text,
        content: 'Detection ignoree: confiance insuffisante',
      ));
    }

    // Classify urgency
    final urgency = classifyUrgency(detection.distance);

    if (urgency == AlertUrgency.ignored) {
      _log.debug('Detection ignored: distance ${detection.distance}m');
      return const Result.success(PluginResponse(
        type: PluginResponseType.text,
        content: 'Detection ignoree: trop loin',
      ));
    }

    // Race condition handling: if immediate alert in progress, ignore preventive
    if (_currentAlertState != null &&
        _currentAlertState!.severity == AlertSeverity.immediate &&
        urgency == AlertUrgency.preventive) {
      _log.debug('Preventive ignored: immediate alert in progress');
      return const Result.success(PluginResponse(
        type: PluginResponseType.text,
        content: 'Alerte immediate en cours',
      ));
    }

    // Build message
    final message = buildAlertMessage(urgency, detection.type, detection.distance);
    final severity = urgency == AlertUrgency.immediate
        ? AlertSeverity.immediate
        : AlertSeverity.preventive;
    final ttsPriority = urgency == AlertUrgency.immediate
        ? TTSPriority.critical
        : TTSPriority.urgent;

    // Store detection
    _lastDetection = detection;
    _lastDetectionTime = DateTime.now();

    // Cancel previous alert timer
    _alertTimer?.cancel();

    // Trigger multi-modal alert via ProfileAdapter
    _triggerAlert(message, severity, ttsPriority, urgency);

    // Start auto-dismiss timer
    _alertTimer = Timer(_autoDismissDelay, _dismissAlert);

    _log.info('Alert triggered: ${urgency.name} - ${detection.type}');

    return Result.success(PluginResponse(
      type: PluginResponseType.alert,
      content: message,
      metadata: {
        'urgency': urgency.name,
        'type': detection.type,
        'distance': detection.distance,
      },
    ));
  }

  void _triggerAlert(
    String message,
    AlertSeverity severity,
    TTSPriority ttsPriority,
    AlertUrgency urgency,
  ) {
    // Stop any ongoing TTS to avoid queuing
    unawaited(ttsService.stop());

    profileAdapter.feedback(
      vocal: () => unawaited(
        ttsService.speak(message, priority: ttsPriority),
      ),
      haptic: () {
        if (urgency == AlertUrgency.immediate) {
          unawaited(hapticService.danger());
        } else {
          unawaited(hapticService.warning());
        }
      },
      visual: () {
        _currentAlertState = AlertViewportState(
          message: message,
          severity: severity,
        );
      },
    );

    // Always set the alert state (even if visual callback was skipped by ProfileAdapter)
    // so buildViewport can return it
    _currentAlertState ??= AlertViewportState(
      message: message,
      severity: severity,
    );
  }

  Future<Result<PluginResponse>> _handleDescribeObstacle() async {
    final detection = _lastDetection;
    final detectionTime = _lastDetectionTime;

    if (detection != null &&
        detectionTime != null &&
        DateTime.now().difference(detectionTime) < _descriptionWindow) {
      final description = buildDetailedDescription(detection);
      unawaited(
        ttsService.speak(description, priority: TTSPriority.urgent),
      );
      _log.info('Obstacle description provided');
      return Result.success(PluginResponse(
        type: PluginResponseType.text,
        content: description,
      ));
    }

    const noObstacleMessage = 'Aucun obstacle recent';
    unawaited(ttsService.speak(noObstacleMessage));
    return const Result.success(PluginResponse(
      type: PluginResponseType.text,
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
