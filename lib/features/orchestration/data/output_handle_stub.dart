import 'package:flutter/widgets.dart';

import '../../io/domain/haptic_service.dart';
import '../../io/domain/speech_event.dart' as tts;
import '../../io/domain/tts_service.dart';
import '../domain/models/output_priority.dart';
import '../domain/output_handle.dart';

// TODO(12.3): Replace this stub with the real OutputCoordinator-backed
// implementation in story 12.3. This stub delegates directly to TTS/Haptic
// services without priority arbitration, queueing, or deduplication.

/// Minimal [OutputHandle] stub for agent migration (story 12.2).
///
/// Delegates directly to [TTSService] and [HapticService] without
/// priority arbitration. The real implementation with full output
/// coordination will be created in story 12.3.
class StubOutputHandle implements OutputHandle {
  StubOutputHandle({
    required this.agentId,
    required TTSService ttsService,
    required HapticService hapticService,
    required void Function(String agentId) onComplete,
  })  : _ttsService = ttsService,
        _hapticService = hapticService,
        _onComplete = onComplete;

  @override
  final String agentId;

  final TTSService _ttsService;
  final HapticService _hapticService;
  final void Function(String agentId) _onComplete;

  @override
  Future<void> speak(
    String text, {
    OutputPriority priority = OutputPriority.standard,
  }) async {
    // Map OutputPriority to TTSPriority for direct delegation.
    final ttsPriority = switch (priority) {
      OutputPriority.cancel || OutputPriority.critical => TTSPriority.critical,
      OutputPriority.high => TTSPriority.urgent,
      OutputPriority.standard || OutputPriority.low => TTSPriority.standard,
    };
    await _ttsService.speak(text, priority: ttsPriority);
  }

  @override
  Future<void> haptic(
    HapticPattern pattern, {
    OutputPriority priority = OutputPriority.standard,
  }) async {
    await _hapticService.trigger(pattern);
  }

  @override
  void updateViewport(Widget widget) {
    // No-op in stub — story 12.4 will implement viewport management.
  }

  @override
  Stream<SpeechEvent> get speechEvents {
    // Map the rich TTS SpeechEvent to the simple enum used by OutputHandle.
    return _ttsService.speechEvents.map((ttsEvent) {
      return switch (ttsEvent.type) {
        tts.TtsSpeechEventType.started => SpeechEvent.started,
        tts.TtsSpeechEventType.completed => SpeechEvent.completed,
        tts.TtsSpeechEventType.interrupted => SpeechEvent.interrupted,
      };
    });
  }

  @override
  void complete() {
    _onComplete(agentId);
  }
}
