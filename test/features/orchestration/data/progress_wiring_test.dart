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

    setUp(() {
      tts = _FakeTts();
      feedTexts = [];
      coordinator = OutputCoordinator(
        tts: tts,
        haptic: _FakeHaptic(),
        profileAdapter: _FakeProfileAdapter(),
        clock: FakeClock(),
        bus: _FakeBus(),
        onOrbStateChanged: (_) {},
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
}
