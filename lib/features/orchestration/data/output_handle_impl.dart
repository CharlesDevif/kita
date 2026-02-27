import 'package:flutter/widgets.dart';

import '../../io/domain/haptic_service.dart';
import '../domain/models/agent_manifest.dart';
import '../domain/models/output_priority.dart';
import '../domain/output_handle.dart';
import 'output_coordinator.dart';

/// Concrete implementation of [OutputHandle] that delegates to [OutputCoordinator].
///
/// Each agent receives its own [OutputHandleImpl] at spawn time.
/// All output requests go through the coordinator for priority arbitration.
class OutputHandleImpl implements OutputHandle {
  OutputHandleImpl({
    required this.agentId,
    required OutputCoordinator coordinator,
    required void Function(String agentId) onComplete,
    this.agentType,
  })  : _coordinator = coordinator,
        _onComplete = onComplete;

  @override
  final String agentId;

  /// The type of the agent owning this handle, for presence haptic logic.
  final AgentType? agentType;

  final OutputCoordinator _coordinator;
  final void Function(String agentId) _onComplete;

  @override
  Future<void> speak(
    String text, {
    OutputPriority priority = OutputPriority.standard,
    double? distance,
    String? cooldownKey,
  }) {
    return _coordinator.enqueueSpeech(
      agentId,
      text,
      priority,
      distance: distance,
      cooldownKey: cooldownKey,
      agentType: agentType,
    );
  }

  @override
  Future<void> haptic(
    HapticPattern pattern, {
    OutputPriority priority = OutputPriority.standard,
  }) {
    return _coordinator.enqueueHaptic(agentId, pattern);
  }

  @override
  void updateViewport(Widget widget) {
    _coordinator.updateViewport(agentId);
  }

  @override
  Stream<SpeechEvent> get speechEvents =>
      _coordinator.speechEventsFor(agentId);

  @override
  void complete() {
    _coordinator.notifyAgentComplete(agentId);
    _onComplete(agentId);
  }
}
