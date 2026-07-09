import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/orchestration/data/progress_reporter.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/progress_phase.dart';
import 'package:kita/features/shell/domain/orb_state.dart';

/// `HapticService` expose : trigger, info, warning, danger, presence.
/// (`confirmation` est une valeur de `HapticPattern`, PAS une méthode.)
class _FakeHaptic implements HapticService {
  int infoCount = 0;
  @override
  Future<Result<void>> info() async {
    infoCount++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async =>
      const Result.success(null);
  @override
  Future<Result<void>> warning() async => const Result.success(null);
  @override
  Future<Result<void>> danger() async => const Result.success(null);
  @override
  Future<Result<void>> presence() async => const Result.success(null);
}

/// Capture les paroles sans dépendre du vrai OutputCoordinator.
class _SpyCoordinator implements ProgressSpeaker {
  final List<String> spoken = [];
  @override
  Future<void> speakCue(String text) async => spoken.add(text);
}

void main() {
  late FakeClock clock;
  late _FakeHaptic haptic;
  late _SpyCoordinator speaker;
  late List<OrbState> orbStates;
  late List<String?> statuses;
  late ProgressReporter reporter;

  setUp(() {
    // FakeClock({DateTime? initialTime}) — argument NOMMÉ. `advance(Duration)`
    // déclenche les timers en attente (voir clock.dart).
    clock = FakeClock();
    haptic = _FakeHaptic();
    speaker = _SpyCoordinator();
    orbStates = [];
    statuses = [];
    reporter = ProgressReporter(
      speaker: speaker,
      haptic: haptic,
      clock: clock,
      onOrbStateChanged: orbStates.add,
      onStatusChanged: statuses.add,
    );
  });

  tearDown(() => reporter.dispose());

  test('thinking met l\'orbe en processing et affiche un statut', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);

    expect(orbStates, contains(OrbState.processing));
    expect(statuses.last, isNotNull);
    expect(haptic.infoCount, 1);
  });

  test('une sortie AVANT 2,5 s annule le repère « Un instant »', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);

    // La réponse arrive à 1 s.
    clock.advance(const Duration(seconds: 1));
    reporter.report(ProgressPhase.responding);

    // On dépasse le seuil : le repère ne doit PAS sortir.
    clock.advance(const Duration(seconds: 5));
    expect(speaker.spoken, isNot(contains(ProgressReporter.cueThinking)));
  });

  test('au-delà de 2,5 s, « Un instant » est dit exactement une fois', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);

    clock.advance(const Duration(seconds: 3));
    expect(
      speaker.spoken.where((s) => s == ProgressReporter.cueThinking).length,
      1,
    );

    // Une deuxième phase thinking ne le redit pas.
    reporter.report(ProgressPhase.thinking);
    clock.advance(const Duration(seconds: 3));
    expect(
      speaker.spoken.where((s) => s == ProgressReporter.cueThinking).length,
      1,
    );
  });

  test('« Je regarde » est dit une seule fois même sur deux outils', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.working);
    reporter.report(ProgressPhase.working);

    expect(
      speaker.spoken.where((s) => s == ProgressReporter.cueWorking).length,
      1,
    );
  });

  test('beginRequest réarme les repères pour la requête suivante', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.working);
    expect(speaker.spoken.length, 1);

    reporter.beginRequest();
    reporter.report(ProgressPhase.working);
    expect(speaker.spoken.length, 2);
  });

  test('endRequest efface le statut, remet l\'orbe passive et vibre', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);
    haptic.infoCount = 0;

    reporter.endRequest(success: true);

    expect(statuses.last, isNull);
    expect(orbStates.last, OrbState.passive);
    expect(haptic.infoCount, 1);
  });

  test('endRequest annule le timer en attente (aucune parole après)', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);
    reporter.endRequest(success: true);

    clock.advance(const Duration(seconds: 10));
    expect(speaker.spoken, isEmpty);
  });

  test('failed met l\'orbe en error', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.failed);
    expect(orbStates.last, OrbState.error);
  });

  test('aucun effet après dispose()', () {
    reporter.dispose();
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);
    clock.advance(const Duration(seconds: 5));
    expect(speaker.spoken, isEmpty);
    expect(orbStates, isEmpty);
  });

  test('des report(thinking) répétés ne repoussent pas « Un instant »', () {
    reporter.beginRequest();
    reporter.report(ProgressPhase.thinking);
    clock.advance(const Duration(seconds: 1));
    reporter.report(ProgressPhase.thinking); // ne doit PAS réarmer
    clock.advance(const Duration(milliseconds: 1600)); // total 2,6 s
    expect(speaker.spoken, contains(ProgressReporter.cueThinking));
  });
}
