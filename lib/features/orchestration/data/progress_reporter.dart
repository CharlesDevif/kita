import 'dart:async';

import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../io/domain/haptic_service.dart';
import '../../shell/domain/orb_state.dart';
import '../domain/clock.dart';
import '../domain/progress_phase.dart';

/// Ce dont [ProgressReporter] a besoin pour parler, sans dépendre de tout
/// l'OutputCoordinator (facilite le test et évite un cycle d'import).
abstract interface class ProgressSpeaker {
  /// Prononce un repère de progression court, prioritaire mais non critique.
  Future<void> speakCue(String text);
}

/// Concentre TOUTE la politique de restitution de progression : orbe,
/// haptique, voix, texte de statut.
///
/// Les agents n'appellent jamais ce composant : l'InputRouter, la
/// ConversationEngine et l'OutputCoordinator émettent des [ProgressPhase],
/// et c'est ici — et ici seulement — qu'on décide quoi montrer et quand se
/// taire. Un futur module hérite donc du bon comportement sans rien écrire.
class ProgressReporter {
  ProgressReporter({
    required ProgressSpeaker speaker,
    required HapticService haptic,
    required Clock clock,
    required void Function(OrbState) onOrbStateChanged,
    required void Function(String? status) onStatusChanged,
    this.spokenCueDelay = const Duration(milliseconds: 2500),
  })  : _speaker = speaker,
        _haptic = haptic,
        _clock = clock,
        _onOrbStateChanged = onOrbStateChanged,
        _onStatusChanged = onStatusChanged;

  /// Repère vocal quand le LLM tarde. Accentué : lu par le TTS.
  static const String cueThinking = 'Un instant.';

  /// Repère vocal quand un outil démarre (photo, analyse).
  static const String cueWorking = 'Je regarde.';

  static const String _statusThinking = 'Réflexion…';
  static const String _statusWorking = 'Je regarde…';

  static final _log = KitaLogger('Orchestration.Progress');

  final ProgressSpeaker _speaker;
  final HapticService _haptic;
  final Clock _clock;
  final void Function(OrbState) _onOrbStateChanged;
  final void Function(String? status) _onStatusChanged;

  /// Délai avant d'annoncer vocalement que ça réfléchit encore.
  final Duration spokenCueDelay;

  Timer? _thinkingCueTimer;
  bool _thinkingCueSpoken = false;
  bool _workingCueSpoken = false;
  bool _disposed = false;

  /// Réarme les drapeaux « une seule fois » pour une nouvelle requête.
  void beginRequest() {
    if (_disposed) return;
    _cancelThinkingCue();
    _thinkingCueSpoken = false;
    _workingCueSpoken = false;
  }

  void report(ProgressPhase phase) {
    if (_disposed) return;
    _log.info('Phase: ${phase.name}');

    switch (phase) {
      case ProgressPhase.thinking:
        _onOrbStateChanged(OrbState.processing);
        _onStatusChanged(_statusThinking);
        _tick();
        _armThinkingCue();

      case ProgressPhase.working:
        _cancelThinkingCue();
        _onOrbStateChanged(OrbState.processing);
        _onStatusChanged(_statusWorking);
        _tick();
        if (!_workingCueSpoken) {
          _workingCueSpoken = true;
          _speakCue(cueWorking);
        }

      case ProgressPhase.responding:
        // La réponse elle-même EST le retour : on se tait et on efface le
        // statut transitoire.
        _cancelThinkingCue();
        _onOrbStateChanged(OrbState.responding);
        _onStatusChanged(null);

      case ProgressPhase.done:
        _cancelThinkingCue();
        _onOrbStateChanged(OrbState.passive);
        _onStatusChanged(null);
        _tick();

      case ProgressPhase.failed:
        _cancelThinkingCue();
        _onOrbStateChanged(OrbState.error);
        _onStatusChanged(null);
        _fireHaptic(_haptic.warning());
    }
  }

  void endRequest({required bool success}) {
    if (_disposed) return;
    report(success ? ProgressPhase.done : ProgressPhase.failed);
  }

  void dispose() {
    _cancelThinkingCue();
    _disposed = true;
  }

  /// Vibration brève : le seul signal disponible pour un utilisateur aveugle
  /// qui n'a pas encore de son. Best-effort, mais un échec doit se voir dans
  /// le Journal (Réglages) pour rester diagnosticable.
  void _tick() => _fireHaptic(_haptic.info());

  void _fireHaptic(Future<Result<void>> future) {
    unawaited(future.then((result) {
      if (result.isFailure) _log.warning('Haptic feedback failed');
    }).catchError((Object e) {
      _log.warning('Haptic feedback threw', error: e);
    }));
  }

  void _armThinkingCue() {
    // Ne jamais repousser un compte à rebours déjà en cours : des
    // `report(thinking)` répétés priveraient l'utilisateur du repère vocal,
    // soit exactement le silence que ce composant corrige.
    if (_thinkingCueSpoken || _thinkingCueTimer != null) return;
    _thinkingCueTimer = _clock.delayed(spokenCueDelay, () {
      if (_disposed || _thinkingCueSpoken) return;
      _thinkingCueSpoken = true;
      _speakCue(cueThinking);
    });
  }

  /// Un repère de progression est best-effort : un échec du TTS ne doit
  /// jamais remonter en erreur non gérée (règle CLAUDE.md).
  void _speakCue(String text) {
    unawaited(_speaker.speakCue(text).catchError((Object e, StackTrace st) {
      _log.warning('speakCue failed', error: e, stackTrace: st);
    }));
  }

  void _cancelThinkingCue() {
    _thinkingCueTimer?.cancel();
    _thinkingCueTimer = null;
  }
}
