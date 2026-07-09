import 'dart:async' show Completer, StreamController, Timer, unawaited;
import 'dart:collection';

import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../io/domain/haptic_service.dart';
import '../../io/domain/tts_service.dart';
import '../../shell/domain/orb_state.dart';
import '../../shell/domain/shell_mode.dart';
import '../../../shared/multi_modal/profile_adapter.dart';
import '../domain/agent_bus.dart';
import '../domain/clock.dart';
import '../domain/models/agent_ids.dart';
import '../domain/models/agent_manifest.dart';
import '../domain/models/agent_message.dart';
import '../domain/models/output_priority.dart';
import '../domain/output_handle.dart';
import 'progress_reporter.dart' show ProgressSpeaker;

// MVP: Timings (cooldown 15s, dedup 2s, presence haptic 2s) and the
// priority-to-haptic mapping are hard-coded constants. For N agents with
// diverse needs, parameterize these per-agent via AgentManifest or a
// coordinator config object. Output modalities (TTS, haptic, viewport)
// are also fixed — extend OutputHandle for new modalities (audio, braille).

/// Internal speech request queued by the [OutputCoordinator].
///
/// Private to this file — no external code should depend on this class.
class _OutputRequest implements Comparable<_OutputRequest> {
  _OutputRequest({
    required this.agentId,
    required this.text,
    required this.priority,
    required this.enqueuedAt,
    this.distance,
    this.cooldownKey,
    this.agentType,
    this.isProgressCue = false,
  });

  final String agentId;
  final String text;
  final OutputPriority priority;
  final DateTime enqueuedAt;

  /// Distance for alert cooldown exception (approaching detection).
  final double? distance;

  /// Key for alert cooldown: "{label}_{zone}".
  final String? cooldownKey;

  /// The type of the agent that made this request.
  final AgentType? agentType;

  /// Repère de progression (« Un instant. », « Je regarde. ») : prononcé en
  /// priorité `high` mais ne pilote JAMAIS l'état de l'orbe. Seul le
  /// [ProgressReporter] pilote l'orbe pendant qu'un outil travaille ; laisser
  /// un repère la remettre en `passive` ferait retomber l'orbe alors que
  /// l'analyse dure encore.
  final bool isProgressCue;

  @override
  int compareTo(_OutputRequest other) {
    // Lower level = higher priority.
    final cmp = priority.level.compareTo(other.priority.level);
    if (cmp != 0) return cmp;
    // FIFO for same priority: oldest first.
    final timeCmp = enqueuedAt.compareTo(other.enqueuedAt);
    return timeCmp != 0 ? timeCmp : hashCode.compareTo(other.hashCode);
  }
}

/// Entry tracking cooldown state for a specific alert label+zone.
class _CooldownEntry {
  _CooldownEntry({required this.lastAlertedAt, required this.lastDistance});

  DateTime lastAlertedAt;
  double lastDistance;
}

/// Arbitrates multi-modal output (TTS, haptic, visual) across concurrent agents.
///
/// The OutputCoordinator is the most critical component of the orchestrator.
/// It manages:
/// - **Priority-based TTS arbitration** (5 levels: CANCEL, CRITICAL, HIGH, STANDARD, LOW)
/// - **Alert cooldown** (same label+zone within 15s is silenced)
/// - **Approaching exception** (distance decrease > 30% bypasses cooldown)
/// - **Deduplication** (same agent + same content within 2s is dropped)
/// - **Presence haptic** (2s after CRITICAL interrupts an onDemand agent)
/// - **Viewport management** (tracks focused agent)
/// - **Shell state** (drives OrbState and ShellMode via injected callbacks)
///
/// All timings use an injectable [Clock] for deterministic testing.
class OutputCoordinator implements ProgressSpeaker {
  OutputCoordinator({
    required TTSService tts,
    required HapticService haptic,
    required ProfileAdapter profileAdapter,
    required Clock clock,
    required AgentBus bus,
    required void Function(OrbState) onOrbStateChanged,
    required void Function(ShellMode) onShellModeChanged,
    void Function(String agentId, String text)? onSpeechEnqueued,
    void Function()? onSpeechStarted,
  })  : _tts = tts,
        _haptic = haptic,
        _profileAdapter = profileAdapter,
        _clock = clock,
        _bus = bus,
        _onOrbStateChanged = onOrbStateChanged,
        _onShellModeChanged = onShellModeChanged,
        _onSpeechEnqueued = onSpeechEnqueued,
        _onSpeechStarted = onSpeechStarted;

  static final _log = KitaLogger('Orchestration');

  // -- Dependencies --
  final TTSService _tts;
  final HapticService _haptic;
  final ProfileAdapter _profileAdapter;
  final Clock _clock;
  final AgentBus _bus;
  final void Function(OrbState) _onOrbStateChanged;
  final void Function(ShellMode) _onShellModeChanged;

  /// Notified with every speech that passes dedup/cooldown — mirrors Kita's
  /// spoken output as text (conversation feed in the Shell). Optional.
  final void Function(String agentId, String text)? _onSpeechEnqueued;

  /// Notifié au tout premier mot prononcé : le Shell bascule en `responding`.
  final void Function()? _onSpeechStarted;

  // -- Queue --
  final SplayTreeSet<_OutputRequest> _queue = SplayTreeSet<_OutputRequest>();

  // -- State --
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String? _currentSpeakingAgentId;
  AgentType? _currentSpeakingAgentType;
  bool _disposed = false;

  /// The agent that currently has focus (last to have produced output).
  String? _focusedAgentId;

  /// Public getter for the focused agent ID.
  String? get focusedAgentId => _focusedAgentId;

  /// Whether the TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  // -- Cooldown tracking --
  final Map<String, _CooldownEntry> _cooldowns = {};
  static const _cooldownDuration = Duration(seconds: 15);

  // -- Deduplication tracking --
  final Map<String, DateTime> _deduplication = {};
  static const _deduplicationWindow = Duration(seconds: 2);

  // -- Timers --
  final Map<String, Timer> _activeTimers = {};

  // -- Speech event streams (one per agent) --
  final Map<String, StreamController<SpeechEvent>> _speechEventsControllers =
      {};

  // -- Completion tracking --
  /// Invariant: only ONE speech can be active at a time. [_speechCompleter]
  /// tracks the currently active speech. It MUST be completed (via
  /// [_completeSpeechCompleter]) before starting a new speech.
  Completer<void>? _speechCompleter;

  /// Returns a [Stream<SpeechEvent>] for a given agent.
  ///
  /// Creates the controller lazily if it does not exist yet.
  Stream<SpeechEvent> speechEventsFor(String agentId) {
    return _getOrCreateController(agentId).stream;
  }

  StreamController<SpeechEvent> _getOrCreateController(String agentId) {
    return _speechEventsControllers.putIfAbsent(
      agentId,
      StreamController<SpeechEvent>.broadcast,
    );
  }

  /// Removes the speech events stream for an agent (cleanup).
  void removeSpeechEvents(String agentId) {
    final controller = _speechEventsControllers.remove(agentId);
    controller?.close();
  }

  // ---------- PUBLIC API ----------

  /// Enqueue a speech request with full arbitration logic.
  ///
  /// Parameters:
  /// - [agentId]: The ID of the requesting agent.
  /// - [text]: The text to speak.
  /// - [priority]: The output priority level.
  /// - [distance]: Optional distance for cooldown approaching exception.
  /// - [cooldownKey]: Optional key for alert cooldown ("{label}_{zone}").
  /// - [agentType]: Optional agent type for presence haptic logic.
  Future<void> enqueueSpeech(
    String agentId,
    String text,
    OutputPriority priority, {
    double? distance,
    String? cooldownKey,
    AgentType? agentType,
  }) async {
    if (_disposed) return;

    // -- Deduplication: same agent + same text hash within 2s --
    final dedupKey = '$agentId:${text.hashCode}';
    final lastSeen = _deduplication[dedupKey];
    if (lastSeen != null &&
        _clock.now().difference(lastSeen) < _deduplicationWindow) {
      _log.debug('Dedup: dropping duplicate from agent $agentId');
      return;
    }
    _deduplication[dedupKey] = _clock.now();

    // -- Cooldown: same cooldownKey within 15s (except approaching) --
    if (cooldownKey != null) {
      final entry = _cooldowns[cooldownKey];
      if (entry != null &&
          _clock.now().difference(entry.lastAlertedAt) < _cooldownDuration) {
        // Check approaching exception: distance decreased > 30%.
        if (distance != null && entry.lastDistance > 0) {
          final ratio = distance / entry.lastDistance;
          if (ratio <= 0.7) {
            // Approaching exception: bypass cooldown.
            _log.debug('Cooldown bypassed: approaching exception for '
                '$cooldownKey');
          } else {
            _log.debug('Cooldown active: dropping alert $cooldownKey');
            return;
          }
        } else {
          _log.debug('Cooldown active: dropping alert $cooldownKey');
          return;
        }
      }
      // Update cooldown entry.
      _cooldowns[cooldownKey] = _CooldownEntry(
        lastAlertedAt: _clock.now(),
        lastDistance: distance ?? 0,
      );
    }

    final request = _OutputRequest(
      agentId: agentId,
      text: text,
      priority: priority,
      enqueuedAt: _clock.now(),
      distance: distance,
      cooldownKey: cooldownKey,
      agentType: agentType,
    );

    // Mirror the accepted speech as text (conversation feed) — after
    // dedup/cooldown so the feed matches what will actually be spoken.
    if (priority != OutputPriority.cancel) {
      _onSpeechEnqueued?.call(agentId, text);
    }

    // -- Route by priority --
    switch (priority) {
      case OutputPriority.cancel:
        await _handleCancel();
      case OutputPriority.critical:
        unawaited(_handleCritical(request));
      case OutputPriority.high:
        unawaited(_handleHigh(request));
      case OutputPriority.standard:
      case OutputPriority.low:
        _queue.add(request);
        _onOrbStateChanged(OrbState.processing);
        unawaited(_processQueue());
    }
  }

  /// Prononce un repère de progression (« Un instant. », « Je regarde. »).
  ///
  /// Priorité `high` : passe devant la file normale mais cède à une alerte
  /// `critical`. N'appelle PAS `_onSpeechEnqueued` : un repère est transitoire
  /// et ne doit jamais laisser de bulle dans le fil de conversation.
  @override
  Future<void> speakCue(String text) async {
    if (_disposed) return;
    final request = _OutputRequest(
      agentId: AgentIds.system,
      text: text,
      priority: OutputPriority.high,
      enqueuedAt: _clock.now(),
      isProgressCue: true,
    );
    unawaited(_handleHigh(request));
  }

  /// Enqueue a haptic request (executed immediately, no queue).
  Future<void> enqueueHaptic(
    String agentId,
    HapticPattern pattern,
  ) async {
    if (_disposed) return;

    _profileAdapter.feedback(
      haptic: () {
        _haptic.trigger(pattern);
      },
    );
  }

  /// Updates the viewport for an agent.
  void updateViewport(String agentId) {
    // Viewport management: the OutputCoordinator tracks the focused agent.
    // AlertAgent can overlay without stealing focus.
    // For now, we track focus but visual widget management
    // is handled by the Shell layer via the focused agent ID.
  }

  /// Cancel all output: stop TTS, clear queue, reset state, feedback "OK".
  Future<void> cancelAll() async {
    if (_disposed) return;

    await _tts.stop();
    _isSpeaking = false;

    // Fire interrupted for all agents with active streams.
    for (final entry in _speechEventsControllers.entries) {
      if (!entry.value.isClosed) {
        entry.value.add(SpeechEvent.interrupted);
      }
    }

    _queue.clear();

    // Cancel presence timer if active.
    _cancelTimer('presence');

    // Complete any pending speech completer.
    _completeSpeechCompleter();

    // Publish cancelAll on the bus.
    _bus.publish(AgentMessage(
      fromAgent: AgentIds.system,
      type: AgentMessageType.cancelAll,
      payload: const {},
      timestamp: _clock.now(),
    ));

    // Reset focused agent.
    _currentSpeakingAgentId = null;
    _currentSpeakingAgentType = null;
    _focusedAgentId = null;

    // Feedback "OK" via ProfileAdapter.
    _profileAdapter.feedback(
      vocal: () {
        unawaited(_tts.speak('OK').catchError((Object e) {
          _log.error('TTS speak failed in cancelAll', error: e);
          return const Result<void>.success(null);
        }));
      },
      haptic: () {
        _haptic.trigger(HapticPattern.info);
      },
    );

    // Shell state.
    _onOrbStateChanged(OrbState.passive);
    _onShellModeChanged(ShellMode.passive);

    _log.info('All output cancelled');
  }

  /// Notify the coordinator that an agent has completed its task.
  void notifyAgentComplete(String agentId) {
    removeSpeechEvents(agentId);
  }

  /// Dispose all resources.
  void dispose() {
    _disposed = true;
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    for (final controller in _speechEventsControllers.values) {
      controller.close();
    }
    _speechEventsControllers.clear();
    _completeSpeechCompleter();
  }

  // ---------- PRIVATE: CANCEL ----------

  Future<void> _handleCancel() async {
    await cancelAll();
  }

  // ---------- PRIVATE: CRITICAL ----------

  Future<void> _handleCritical(_OutputRequest request) async {
    // Track who was interrupted.
    final interruptedAgentId = _currentSpeakingAgentId;
    final interruptedAgentType = _currentSpeakingAgentType;

    // Stop TTS immediately if speaking.
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;

      // Complete any pending speech completer so _processQueue unblocks.
      _completeSpeechCompleter();

      // Fire interrupted on the interrupted agent's stream.
      if (interruptedAgentId != null) {
        _emitSpeechEvent(interruptedAgentId, SpeechEvent.interrupted);
      }
    }

    // Publish interruptRequest on the bus.
    _bus.publish(AgentMessage(
      fromAgent: request.agentId,
      type: AgentMessageType.interruptRequest,
      payload: const {},
      timestamp: _clock.now(),
    ));

    // Schedule presence haptic if the interrupted agent was onDemand.
    if (interruptedAgentType == AgentType.onDemand) {
      _schedulePresenceHaptic();
    }

    // Speak the critical message.
    _currentSpeakingAgentId = request.agentId;
    _currentSpeakingAgentType = request.agentType;
    _focusedAgentId = request.agentId;
    _isSpeaking = true;

    _onOrbStateChanged(OrbState.processing);
    _onOrbStateChanged(OrbState.responding);

    _emitSpeechEvent(request.agentId, SpeechEvent.started);

    _profileAdapter.feedback(
      vocal: () {
        unawaited(_tts.speak(request.text).catchError((Object e) {
          _log.error('TTS speak failed in critical handler', error: e);
          return const Result<void>.success(null);
        }));
      },
      haptic: () {
        _haptic.trigger(HapticPattern.danger);
      },
    );

    // Wait for speech to complete.
    _speechCompleter = Completer<void>();
    _scheduleTimer(
        'speech_timeout', const Duration(seconds: 30), _completeSpeechCompleter);

    await _speechCompleter!.future;

    if (!_disposed) {
      _isSpeaking = false;
      _emitSpeechEvent(request.agentId, SpeechEvent.completed);
      if (_queue.isEmpty) {
        _onOrbStateChanged(OrbState.passive);
      } else {
        await _processQueue();
      }
    }
  }

  // ---------- PRIVATE: HIGH ----------

  Future<void> _handleHigh(_OutputRequest request) async {
    if (_isSpeaking) {
      // Wait for current phrase to end, max 2s.
      final waitCompleter = Completer<void>();
      bool resolved = false;

      // Listen for current speech completion.
      unawaited(_speechCompleter?.future.then((_) {
        if (!resolved) {
          resolved = true;
          if (!waitCompleter.isCompleted) {
            waitCompleter.complete();
          }
        }
      }));

      // Also set a max 2s timeout.
      _scheduleTimer('high_wait', const Duration(seconds: 2), () {
        if (!resolved) {
          resolved = true;
          if (!waitCompleter.isCompleted) {
            waitCompleter.complete();
          }
        }
      });

      await waitCompleter.future;
      _cancelTimer('high_wait');

      // If still speaking after 2s, force stop.
      if (_isSpeaking && !_disposed) {
        await _tts.stop();
        _isSpeaking = false;
        _completeSpeechCompleter();
        if (_currentSpeakingAgentId != null) {
          _emitSpeechEvent(_currentSpeakingAgentId!, SpeechEvent.interrupted);
        }
      }
    }

    if (_disposed) return;

    // Speak the high-priority message.
    _currentSpeakingAgentId = request.agentId;
    _currentSpeakingAgentType = request.agentType;
    _focusedAgentId = request.agentId;
    _isSpeaking = true;

    // Un repère de progression n'est pas une réponse : il ne pilote jamais
    // l'orbe (sinon l'orbe retombe en `passive` alors qu'un outil travaille).
    if (!request.isProgressCue) {
      _onOrbStateChanged(OrbState.processing);
      _onOrbStateChanged(OrbState.responding);
    }

    _emitSpeechEvent(request.agentId, SpeechEvent.started);

    _profileAdapter.feedback(
      vocal: () {
        unawaited(_tts.speak(request.text).catchError((Object e) {
          _log.error('TTS speak failed in high handler', error: e);
          return const Result<void>.success(null);
        }));
      },
      haptic: () {
        _haptic.trigger(HapticPattern.warning);
      },
    );

    // Wait for speech to complete.
    _speechCompleter = Completer<void>();
    _scheduleTimer(
        'speech_timeout', const Duration(seconds: 30), _completeSpeechCompleter);

    await _speechCompleter!.future;

    if (!_disposed) {
      _isSpeaking = false;
      _emitSpeechEvent(request.agentId, SpeechEvent.completed);
      if (_queue.isEmpty) {
        // Un repère de progression ne remet PAS l'orbe en `passive` : c'est le
        // ProgressReporter qui gère l'orbe tant que l'outil n'a pas fini.
        if (!request.isProgressCue) {
          _onOrbStateChanged(OrbState.passive);
        }
      } else {
        await _processQueue();
      }
    }
  }

  // ---------- PRIVATE: CLEANUP EXPIRED ENTRIES ----------

  /// Removes expired entries from [_deduplication] and [_cooldowns] maps
  /// to prevent unbounded memory growth over time.
  void _cleanupExpiredEntries() {
    final now = _clock.now();
    _deduplication.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _deduplicationWindow,
    );
    _cooldowns.removeWhere(
      (_, entry) => now.difference(entry.lastAlertedAt) > _cooldownDuration,
    );
  }

  // ---------- PRIVATE: PROCESS QUEUE (STANDARD + LOW) ----------

  Future<void> _processQueue() async {
    if (_isProcessing || _disposed) return;
    _isProcessing = true;

    // Periodically clean up expired dedup and cooldown entries.
    _cleanupExpiredEntries();

    try {
      while (_queue.isNotEmpty && !_disposed) {
        final request = _queue.first;
        _queue.remove(request);

        // LOW timeout: drop if older than 10s.
        if (request.priority == OutputPriority.low) {
          final age = _clock.now().difference(request.enqueuedAt);
          if (age > const Duration(seconds: 10)) {
            _log.debug('LOW message dropped: expired after ${age.inSeconds}s');
            continue;
          }
        }

        // Speak this message.
        _currentSpeakingAgentId = request.agentId;
        _currentSpeakingAgentType = request.agentType;
        _focusedAgentId = request.agentId;
        _isSpeaking = true;

        _onOrbStateChanged(OrbState.responding);

        // Cancel presence timer if a new output starts.
        _cancelTimer('presence');

        _emitSpeechEvent(request.agentId, SpeechEvent.started);

        _profileAdapter.feedback(
          vocal: () {
            unawaited(_tts.speak(request.text).catchError((Object e) {
              _log.error('TTS speak failed in queue processing', error: e);
              return const Result<void>.success(null);
            }));
          },
          haptic: () {
            _haptic.trigger(HapticPattern.info);
          },
        );

        // Wait for speech completion.
        _speechCompleter = Completer<void>();
        _scheduleTimer('speech_timeout', const Duration(seconds: 30),
            _completeSpeechCompleter);

        await _speechCompleter!.future;

        if (_disposed) break;

        _isSpeaking = false;
        _emitSpeechEvent(request.agentId, SpeechEvent.completed);
      }
    } finally {
      _isProcessing = false;
      if (!_disposed && _queue.isEmpty && !_isSpeaking) {
        _onOrbStateChanged(OrbState.passive);
      }
    }
  }

  // ---------- PRIVATE: PRESENCE HAPTIC ----------

  void _schedulePresenceHaptic() {
    _scheduleTimer('presence', const Duration(seconds: 2), () {
      if (!_disposed) {
        _profileAdapter.feedback(
          haptic: () {
            _haptic.trigger(HapticPattern.presence);
          },
        );
        _log.debug('Presence haptic triggered post-interruption');
      }
    });
  }

  // ---------- PRIVATE: TIMER MANAGEMENT ----------

  void _scheduleTimer(
      String key, Duration duration, void Function() callback) {
    _activeTimers[key]?.cancel();
    _activeTimers[key] = _clock.delayed(duration, () {
      _activeTimers.remove(key);
      if (!_disposed) {
        callback();
      }
    });
  }

  void _cancelTimer(String key) {
    _activeTimers[key]?.cancel();
    _activeTimers.remove(key);
  }

  // ---------- PRIVATE: SPEECH EVENTS ----------

  void _emitSpeechEvent(String agentId, SpeechEvent event) {
    final controller = _speechEventsControllers[agentId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  // ---------- PRIVATE: SPEECH COMPLETER ----------

  void _completeSpeechCompleter() {
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = null;
    _cancelTimer('speech_timeout');
  }

  /// Called by the TTS callback layer to notify speech completion.
  ///
  /// This must be called by the Riverpod provider wiring (or test setup)
  /// to bridge TTS completion events to the coordinator.
  void onSpeechComplete() {
    _completeSpeechCompleter();
  }

  /// Called by the TTS callback layer to notify speech started.
  void onSpeechStart() {
    // Premier mot prononcé : le Shell bascule en `responding` et efface le
    // statut transitoire (« Réflexion… »).
    _onSpeechStarted?.call();
    // The coordinator tracks speaking state internally otherwise.
  }

  /// Called by the TTS callback layer to notify speech was cancelled.
  void onSpeechCancelled() {
    _completeSpeechCompleter();
  }
}
