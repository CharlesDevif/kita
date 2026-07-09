import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/progress_reporter.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/models/agent_ids.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/progress_phase.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// ==========================================================================
// Minimal fakes (real OutputCoordinator, no mock DB / no StreamProvider).
// ==========================================================================

class _FakeTts implements TTSService {
  final List<String> spoken = [];
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents =>
      const Stream<TtsSpeechEvent>.empty();

  @override
  Future<Result<void>> speak(String text,
      {TTSPriority priority = TTSPriority.standard}) async {
    spoken.add(text);
    _speaking = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _speaking = false;
    return const Result.success(null);
  }
}

class _FakeHaptic implements HapticService {
  @override
  Future<Result<void>> trigger(HapticPattern pattern) async =>
      const Result.success(null);
  @override
  Future<Result<void>> info() async => const Result.success(null);
  @override
  Future<Result<void>> warning() async => const Result.success(null);
  @override
  Future<Result<void>> danger() async => const Result.success(null);
  @override
  Future<Result<void>> presence() async => const Result.success(null);
}

/// Blind profile: routes both vocal and haptic callbacks (as production does).
class _FakeProfileAdapter implements ProfileAdapter {
  @override
  String get activeProfile => 'blind';

  @override
  void feedback({
    void Function()? visual,
    void Function()? vocal,
    void Function()? haptic,
  }) {
    vocal?.call();
    haptic?.call();
  }
}

class _FakeBus implements AgentBus {
  @override
  void publish(AgentMessage message) {}
  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}
  @override
  void unsubscribe(String agentId) {}
  @override
  Stream<AgentMessage> streamFor(String agentId) =>
      const Stream<AgentMessage>.empty();
}

/// Speaker minimal : capture les repères sans dépendre de l'OutputCoordinator.
class _FakeProgressSpeaker implements ProgressSpeaker {
  final List<String> cues = [];
  @override
  Future<void> speakCue(String text) async => cues.add(text);
}

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.microtask(() {});
  }
}

void main() {
  test('les repères vocaux sont des constantes accentuées et courtes', () {
    // Lus par le TTS : les accents sont obligatoires (règle projet).
    expect(ProgressReporter.cueThinking, 'Un instant.');
    expect(ProgressReporter.cueWorking, 'Je regarde.');
    expect(ProgressReporter.cueThinking.length, lessThan(20));
    expect(ProgressReporter.cueWorking.length, lessThan(20));
  });

  group('OutputCoordinator.speakCue', () {
    late _FakeTts tts;
    late OutputCoordinator coordinator;
    late List<String> feedTexts;
    late List<OrbState> orbStates;

    setUp(() {
      tts = _FakeTts();
      feedTexts = [];
      orbStates = [];
      coordinator = OutputCoordinator(
        tts: tts,
        haptic: _FakeHaptic(),
        profileAdapter: _FakeProfileAdapter(),
        clock: FakeClock(),
        bus: _FakeBus(),
        onOrbStateChanged: orbStates.add,
        onShellModeChanged: (_) {},
        // Le hook qui alimente le fil de conversation du Shell.
        onSpeechEnqueued: (agentId, text) => feedTexts.add(text),
      );
    });

    tearDown(() => coordinator.dispose());

    test('prononce le repère mais ne laisse AUCUNE bulle dans le fil',
        () async {
      await coordinator.speakCue(ProgressReporter.cueWorking);
      await _flush();

      // Il a bien été prononcé…
      expect(tts.spoken, contains('Je regarde.'));
      // … mais le fil de conversation reste vierge (exigence non négociable).
      expect(feedTexts, isEmpty);
    });

    test('une parole normale, elle, alimente bien le fil (contre-preuve)',
        () async {
      await coordinator.enqueueSpeech(
        AgentIds.system,
        'Bonjour Marie.',
        OutputPriority.standard,
      );
      await _flush();

      expect(feedTexts, contains('Bonjour Marie.'));
    });

    test('speakCue est inerte après dispose', () async {
      coordinator.dispose();
      await coordinator.speakCue(ProgressReporter.cueThinking);
      await _flush();

      expect(tts.spoken, isEmpty);
      expect(feedTexts, isEmpty);
    });

    test('un repère ne pilote JAMAIS l\'état de l\'orbe', () async {
      // Le repère de progression est prononcé, mais l'orbe reste sous le seul
      // contrôle du ProgressReporter : aucun `responding` au début, aucun
      // `passive` à la fin. Sans ça, l'orbe retombe pendant qu'un outil bosse.
      await coordinator.speakCue(ProgressReporter.cueWorking);
      await _flush();

      expect(tts.spoken, contains('Je regarde.'));
      expect(orbStates, isEmpty);
    });

    test('une parole normale, elle, pilote bien l\'orbe (contre-preuve)',
        () async {
      await coordinator.enqueueSpeech(
        AgentIds.system,
        'Bonjour Marie.',
        OutputPriority.standard,
      );
      await _flush();

      // Une vraie réponse DOIT bouger l'orbe (processing puis responding).
      expect(orbStates, isNotEmpty);
    });
  });

  test('implements ProgressSpeaker — utilisable comme speaker du reporter', () {
    final coordinator = OutputCoordinator(
      tts: _FakeTts(),
      haptic: _FakeHaptic(),
      profileAdapter: _FakeProfileAdapter(),
      clock: FakeClock(),
      bus: _FakeBus(),
      onOrbStateChanged: (_) {},
      onShellModeChanged: (_) {},
    );
    addTearDown(coordinator.dispose);

    // Le contrat structurel qui permet le câblage DI.
    expect(coordinator, isA<ProgressSpeaker>());
  });

  // ========================================================================
  // Contrat de câblage : le ProgressReporter réel est LA seule source de
  // vérité pour l'orbe pendant une requête. On verrouille la suite d'états.
  // ========================================================================
  group('ProgressReporter → orbe (câblage réel, sans widget)', () {
    late _FakeProgressSpeaker speaker;
    late ProgressReporter reporter;
    late List<OrbState> orbStates;
    late List<String?> statuses;

    setUp(() {
      speaker = _FakeProgressSpeaker();
      orbStates = [];
      statuses = [];
      reporter = ProgressReporter(
        speaker: speaker,
        haptic: _FakeHaptic(),
        clock: FakeClock(),
        onOrbStateChanged: orbStates.add,
        onStatusChanged: statuses.add,
      );
    });

    tearDown(() => reporter.dispose());

    test('un cycle complet enchaîne processing → responding → passive '
        'et laisse le statut final vide', () {
      reporter.beginRequest();
      reporter.report(ProgressPhase.thinking);
      reporter.report(ProgressPhase.working);
      reporter.report(ProgressPhase.responding);
      reporter.endRequest(success: true);

      expect(orbStates, <OrbState>[
        OrbState.processing, // thinking
        OrbState.processing, // working
        OrbState.responding, // responding
        OrbState.passive, // done
      ]);
      // La vraie réponse ayant pris le relais, plus aucun statut transitoire.
      expect(statuses.last, isNull);
    });

    test('un échec met l\'orbe en error', () {
      reporter.beginRequest();
      reporter.endRequest(success: false);

      expect(orbStates.last, OrbState.error);
    });
  });

  // ========================================================================
  // Câblage onSpeechStarted : seul le premier mot d'une VRAIE réponse d'agent
  // notifie le Shell (→ `responding`, efface le statut). Ni les repères de
  // progression, ni le « OK » d'annulation ne doivent notifier — sinon ils
  // pilotent l'orbe (interdit) et effacent la bulle de statut.
  //
  // On simule l'événement `started` natif du TTS en appelant `onSpeechStart()`
  // à la main (le `started` réel arrive APRÈS `speak()`), comme le pattern des
  // tests output_coordinator qui pilotent le faux TTS via les callbacks.
  // ========================================================================
  group('OutputCoordinator.onSpeechStart → onSpeechStarted', () {
    late _FakeTts tts;
    late OutputCoordinator coordinator;
    late int startedCount;
    late List<OrbState> orbStates;

    setUp(() {
      tts = _FakeTts();
      startedCount = 0;
      orbStates = [];
      coordinator = OutputCoordinator(
        tts: tts,
        haptic: _FakeHaptic(),
        profileAdapter: _FakeProfileAdapter(),
        clock: FakeClock(),
        bus: _FakeBus(),
        onOrbStateChanged: orbStates.add,
        onShellModeChanged: (_) {},
        onSpeechStarted: () => startedCount++,
      );
    });

    tearDown(() => coordinator.dispose());

    test('(a) un repère ne notifie JAMAIS onSpeechStarted et ne bouge pas '
        'l\'orbe', () async {
      await coordinator.speakCue(ProgressReporter.cueThinking);
      await _flush();
      // Le `started` natif du TTS arrive après `speak()` : on le simule.
      coordinator.onSpeechStart();
      await _flush();

      expect(tts.spoken, contains('Un instant.'));
      expect(startedCount, 0);
      expect(orbStates, isEmpty);
    });

    test('(b) une parole normale notifie onSpeechStarted une seule fois',
        () async {
      await coordinator.enqueueSpeech(
        AgentIds.system,
        'Voici la description.',
        OutputPriority.standard,
      );
      await _flush();
      coordinator.onSpeechStart();
      await _flush();

      expect(tts.spoken, contains('Voici la description.'));
      expect(startedCount, 1);
    });

    test('(c) le « OK » de cancelAll ne notifie pas onSpeechStarted ; '
        'l\'orbe finit en passive', () async {
      // Une vraie réponse est en cours…
      await coordinator.enqueueSpeech(
        AgentIds.system,
        'Réponse en cours.',
        OutputPriority.standard,
      );
      await _flush();
      startedCount = 0;
      orbStates.clear();

      // « stop » : cancelAll prononce « OK » et remet l'orbe en passive.
      await coordinator.cancelAll();
      await _flush();

      // Le `started` (asynchrone) du « OK » arrive APRÈS le retour à passive :
      // il ne doit surtout pas rallumer l'orbe en `responding`.
      coordinator.onSpeechStart();
      await _flush();

      expect(tts.spoken, contains('OK'));
      expect(startedCount, 0);
      expect(orbStates.last, OrbState.passive);
    });
  });
}
