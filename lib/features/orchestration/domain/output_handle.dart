import 'package:flutter/widgets.dart';

import '../../io/domain/haptic_service.dart';
import 'models/output_priority.dart';

/// Events emitted by the output system during speech delivery.
///
/// Agents listen to these via [OutputHandle.speechEvents] to manage
/// their own behavior (e.g., starting a silence timeout after [completed]).
enum SpeechEvent {
  /// TTS has started speaking the agent's text.
  started,

  /// TTS has finished speaking the agent's text.
  completed,

  /// TTS was interrupted by a higher-priority agent.
  interrupted,
}

/// Handle through which an agent produces output (speech, haptic, visual).
///
/// Agents MUST NOT call TTS or HapticService directly. All output goes
/// through [OutputHandle], which delegates to the [OutputCoordinator]
/// for priority arbitration and delivery.
///
/// The concrete implementation is created by the [OutputCoordinator]
/// in story 12.3. This abstract class defines the contract.
abstract class OutputHandle {
  /// The ID of the agent that owns this handle.
  String get agentId;

  /// Requests speech output with the given [priority].
  ///
  /// The [OutputCoordinator] decides when (or if) the text is actually
  /// spoken, based on priority arbitration rules.
  Future<void> speak(
    String text, {
    OutputPriority priority = OutputPriority.standard,
  });

  /// Requests haptic feedback with the given [priority].
  Future<void> haptic(
    HapticPattern pattern, {
    OutputPriority priority = OutputPriority.standard,
  });

  /// Updates the visual viewport for this agent in the Shell.
  void updateViewport(Widget widget);

  /// Stream of speech delivery events for this agent.
  ///
  /// Use this to detect when speech completes (for silence timeout)
  /// or when speech is interrupted (to clean up state).
  Stream<SpeechEvent> get speechEvents;

  /// Signals that this agent has completed its task.
  ///
  /// The Supervisor will terminate the agent after this call.
  /// Typically called after a silence timeout expires.
  void complete();
}
