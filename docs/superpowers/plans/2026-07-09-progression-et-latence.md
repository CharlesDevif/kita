# Retour de progression + réduction de latence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre l'attente de Kita lisible et rassurante (orbe + haptique + deux repères vocaux courts + bulle de statut), et faire passer le « décris » de 70 s à ~35 s (premier mot de 55 s à ~20 s) sans jamais court-circuiter le LLM.

**Architecture:** Un `ProgressReporter` dans la couche orchestration reçoit des *phases* et concentre toute la politique de restitution (orbe / haptique / voix / texte) — les agents n'y touchent pas. Côté latence, on réduit le nombre de **tokens décodés** (0,55 s/token mesuré) : format d'appel d'outil compact, suppression d'un paramètre mort, et première phrase de description volontairement courte.

**Tech Stack:** Flutter 3.41 / Dart 3.11, Riverpod 3, flutter_gemma 0.12.4, flutter_test.

## Global Constraints

- **Ne JAMAIS court-circuiter le LLM** : même « décris » passe par la ConversationEngine (décision produit de Charles).
- Débit de décodage mesuré sur S21 Ultra : **~0,55 s/token**. Toute réduction de latence passe par moins de tokens décodés.
- Au plus **deux repères vocaux par requête**, jamais répétés. Les repères vocaux ne créent **aucune entrée** dans le fil de conversation.
- Error handling : `sealed class KitaFailure` + `Result<T>`. Aux frontières natives, attraper `Object` (une `KitaFailure` n'est PAS une `Exception`).
- Zéro PII dans les logs : jamais le contenu d'un message, seulement des métadonnées (`len=`, phase, locuteur).
- Strings françaises **avec accents corrects** (lues par TTS).
- Accessibilité : `Semantics` descriptifs, `liveRegion` pour le statut, contrastes ≥ 4.5:1, cibles ≥ 48×48, respect de `MediaQuery.disableAnimations`.
- Piège CLAUDE.md : `testWidgets` + `StreamProvider`/`StreamController` = hang. Utiliser `test()` + `ProviderContainer` sauf besoin réel de `pumpWidget`.
- Toujours utiliser `Clock` (`clock.delayed(...)`) et jamais `Timer`/`DateTime.now()` directement dans la logique testable.
- PATH : `export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"`
- Après chaque tâche : `dart analyze --fatal-infos` clean et `flutter test` vert.

---

## File Structure

**Partie A — progression**
- `lib/features/orchestration/domain/progress_phase.dart` (créer) — l'enum des phases. Aucune dépendance.
- `lib/features/orchestration/data/progress_reporter.dart` (créer) — toute la politique de restitution. Pur Dart + `Clock`, testable sans widget.
- `lib/features/orchestration/di/providers.dart` (modifier) — instancie `ProgressReporter`, injecte les callbacks orbe/statut.
- `lib/features/shell/di/progress_status_provider.dart` (créer) — `StateProvider`-like exposant le statut courant au Shell.
- `lib/features/shell/presentation/kita_shell.dart` (modifier) — rend la bulle de statut transitoire.
- `lib/features/orchestration/data/input_router.dart` (modifier) — `beginRequest` / `thinking` / `endRequest`.
- `lib/features/orchestration/data/conversation_engine.dart` (modifier) — `working` avant chaque exécution d'outil.
- `lib/features/orchestration/data/output_coordinator.dart` (modifier) — `responding` sur `onSpeechStart`.

**Partie B — latence**
- `lib/features/ai/data/providers/local_provider.dart` (modifier) — prompt `TOOL <nom>` + parseur double format.
- `lib/features/orchestration/data/kita_tools.dart` (modifier) — supprimer `detail_level`, alléger les descriptions.
- `lib/features/plugins/built_in/describe/describe_plugin.dart` (modifier) — `describePrompt` bref + première phrase courte.

Tests : un fichier par unité créée ; les tests existants touchés sont mis à jour dans la tâche qui les casse.

---

## Task 1 : `ProgressPhase` + `ProgressReporter` (politique de restitution)

**Files:**
- Create: `lib/features/orchestration/domain/progress_phase.dart`
- Create: `lib/features/orchestration/data/progress_reporter.dart`
- Test: `test/features/orchestration/data/progress_reporter_test.dart`

**Interfaces:**
- Consumes: `OutputCoordinator.enqueueSpeech(String agentId, String text, OutputPriority priority)`, `HapticService.info()`, `Clock.delayed(Duration, void Function())`, `OrbState`, `AgentIds.system`.
- Produces:
  - `enum ProgressPhase { thinking, working, responding, done, failed }`
  - `class ProgressReporter({required OutputCoordinator coordinator, required HapticService haptic, required Clock clock, required void Function(OrbState) onOrbStateChanged, required void Function(String? status) onStatusChanged, Duration spokenCueDelay = const Duration(milliseconds: 2500)})`
  - `void beginRequest()`, `void report(ProgressPhase phase)`, `void endRequest({required bool success})`, `void dispose()`
  - `static const String cueThinking = 'Un instant.'`, `static const String cueWorking = 'Je regarde.'`

- [ ] **Step 1: Créer l'enum des phases**

```dart
// lib/features/orchestration/domain/progress_phase.dart

/// Où en est Kita dans le traitement d'une requête utilisateur.
///
/// Émis par l'InputRouter, la ConversationEngine et l'OutputCoordinator ;
/// consommé par [ProgressReporter] qui décide seul de la restitution
/// (orbe / haptique / voix / texte).
enum ProgressPhase {
  /// Le LLM réfléchit (aucune sortie encore).
  thinking,

  /// Un outil s'exécute (photo, analyse d'image…).
  working,

  /// Kita a commencé à répondre.
  responding,

  /// Requête terminée avec succès.
  done,

  /// Requête échouée.
  failed,
}
```

- [ ] **Step 2: Écrire les tests qui échouent**

```dart
// test/features/orchestration/data/progress_reporter_test.dart
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
}
```

- [ ] **Step 3: Vérifier l'échec**

Run: `flutter test test/features/orchestration/data/progress_reporter_test.dart`
Expected: FAIL — `progress_reporter.dart` n'existe pas.

> **Vérifié :** `FakeClock` (lib/features/orchestration/domain/clock.dart) expose
> `FakeClock({DateTime? initialTime})`, `void advance(Duration)`, `Timer delayed(...)`.
> `advance()` déclenche les timers échus — c'est ce qui rend ces tests déterministes.

- [ ] **Step 4: Implémenter**

```dart
// lib/features/orchestration/data/progress_reporter.dart
import 'dart:async';

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
          unawaited(_speaker.speakCue(cueWorking));
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
        unawaited(_haptic.warning());
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
  /// qui n'a pas encore de son.
  void _tick() => unawaited(_haptic.info());

  void _armThinkingCue() {
    if (_thinkingCueSpoken) return;
    _cancelThinkingCue();
    _thinkingCueTimer = _clock.delayed(spokenCueDelay, () {
      if (_disposed || _thinkingCueSpoken) return;
      _thinkingCueSpoken = true;
      unawaited(_speaker.speakCue(cueThinking));
    });
  }

  void _cancelThinkingCue() {
    _thinkingCueTimer?.cancel();
    _thinkingCueTimer = null;
  }
}
```

- [ ] **Step 5: Vérifier le succès**

Run: `flutter test test/features/orchestration/data/progress_reporter_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 6: Analyze + commit**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos lib/features/orchestration/domain/progress_phase.dart lib/features/orchestration/data/progress_reporter.dart test/features/orchestration/data/progress_reporter_test.dart
git add lib/features/orchestration/domain/progress_phase.dart lib/features/orchestration/data/progress_reporter.dart test/features/orchestration/data/progress_reporter_test.dart
git commit -m "feat(orchestration): ProgressReporter — politique unique de retour de progression"
```

---

## Task 2 : Câbler le `ProgressReporter` (émetteurs + providers + bulle de statut)

**Files:**
- Modify: `lib/features/orchestration/data/output_coordinator.dart`
- Modify: `lib/features/orchestration/data/input_router.dart`
- Modify: `lib/features/orchestration/data/conversation_engine.dart`
- Create: `lib/features/shell/di/progress_status_provider.dart`
- Modify: `lib/features/orchestration/di/providers.dart`
- Modify: `lib/features/shell/presentation/kita_shell.dart`
- Test: `test/features/orchestration/data/progress_wiring_test.dart`

**Interfaces:**
- Consumes (Task 1) : `ProgressReporter`, `ProgressSpeaker`, `ProgressPhase`, `ProgressReporter.cueThinking`, `ProgressReporter.cueWorking`.
- Produces :
  - `OutputCoordinator implements ProgressSpeaker` — `Future<void> speakCue(String text)` enfile la parole avec `OutputPriority.high` et **sans** notifier `onSpeechEnqueued` (pas de bulle permanente).
  - `final progressStatusProvider = NotifierProvider<ProgressStatus, String?>(ProgressStatus.new);` avec `void set(String? value)`.
  - `InputRouter({..., ProgressReporter? progress})`, `ConversationEngineImpl({..., ProgressReporter? progress})`.

- [ ] **Step 1: `OutputCoordinator` sait prononcer un repère sans polluer le fil**

Dans `lib/features/orchestration/data/output_coordinator.dart`, faire implémenter l'interface et ajouter la méthode. Ajouter l'import :

```dart
import 'progress_reporter.dart' show ProgressSpeaker;
```

Changer la déclaration de classe :

```dart
class OutputCoordinator implements ProgressSpeaker {
```

Puis ajouter (près de `enqueueSpeech`) :

```dart
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
    );
    unawaited(_handleHigh(request));
  }
```

> **Vérification obligatoire avant d'écrire :** ouvrir `_OutputRequest` et `_handleHigh` dans ce fichier et adapter les arguments nommés à leur signature réelle (`distance`, `cooldownKey`, `agentType` sont optionnels). Ne pas inventer de paramètre.

- [ ] **Step 2: `onSpeechStart` signale `responding`**

Toujours dans `output_coordinator.dart`, ajouter un champ optionnel et l'appeler.

Dans le constructeur, après `onSpeechEnqueued` :

```dart
    void Function()? onSpeechStarted,
```
puis `_onSpeechStarted = onSpeechStarted,` dans la liste d'initialisation, et le champ :

```dart
  /// Notifié au tout premier mot prononcé : le Shell bascule en `responding`.
  final void Function()? _onSpeechStarted;
```

Dans `void onSpeechStart()` (≈ ligne 675), ajouter en première instruction du corps :

```dart
    _onSpeechStarted?.call();
```

- [ ] **Step 3: `InputRouter` ouvre et ferme la requête**

Dans `lib/features/orchestration/data/input_router.dart` : ajouter les imports

```dart
import '../domain/progress_phase.dart';
import 'progress_reporter.dart';
```

Ajouter le paramètre optionnel au constructeur (`ProgressReporter? progress`) et le champ `final ProgressReporter? _progress;`.

Dans `route(...)`, juste après le contrôle du transcript vide (le `if (transcript.isEmpty) { ...; return; }`), envelopper la suite :

```dart
    _progress?.beginRequest();
    _progress?.report(ProgressPhase.thinking);
    var success = true;
    try {
      await _routeTranscript(input, transcript);
    } on Object {
      success = false;
      rethrow;
    } finally {
      _progress?.endRequest(success: success);
    }
  }

  /// Corps historique de [route] à partir de l'étape 3 (commande « stop »).
  Future<void> _routeTranscript(RawInput input, String transcript) async {
```

… et déplacer tel quel le code existant (étapes 3, 4, 5) dans `_routeTranscript`. Aucune logique ne change.

- [ ] **Step 4: `ConversationEngineImpl` signale `working` avant chaque outil**

Dans `lib/features/orchestration/data/conversation_engine.dart` : ajouter les imports

```dart
import '../domain/progress_phase.dart';
import 'progress_reporter.dart';
```

Ajouter `ProgressReporter? progress` au constructeur et le champ `final ProgressReporter? _progress;`.

Puis, dans la boucle tool-use, **juste avant** `final toolResult = await _executeToolCall(call);` :

```dart
        _progress?.report(ProgressPhase.working);
```

- [ ] **Step 5: Provider de statut pour le Shell**

```dart
// lib/features/shell/di/progress_status_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Statut transitoire affiché sous forme de bulle pendant le traitement
/// (« Réflexion… », « Je regarde… »). `null` = rien à afficher.
///
/// Session uniquement, jamais persisté.
class ProgressStatus extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final progressStatusProvider =
    NotifierProvider<ProgressStatus, String?>(ProgressStatus.new);
```

- [ ] **Step 6: Instancier et injecter dans la DI**

Dans `lib/features/orchestration/di/providers.dart`, ajouter les imports :

```dart
import '../../shell/di/progress_status_provider.dart';
import '../data/progress_reporter.dart';
```

Ajouter le provider (après `outputCoordinatorProvider`) :

```dart
/// Le [ProgressReporter] — politique unique de retour de progression.
final progressReporterProvider = Provider<ProgressReporter>((ref) {
  final coordinator = ref.watch(outputCoordinatorProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final clock = ref.watch(clockProvider);

  final reporter = ProgressReporter(
    speaker: coordinator,
    haptic: haptic,
    clock: clock,
    onOrbStateChanged: (OrbState state) {
      ref.read(orbStateProvider.notifier).setState(state);
    },
    onStatusChanged: (String? status) {
      ref.read(progressStatusProvider.notifier).set(status);
    },
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});
```

Dans `outputCoordinatorProvider`, passer le nouveau callback :

```dart
    onSpeechStarted: () {
      ref.read(progressReporterProvider).report(ProgressPhase.responding);
    },
```

> **Attention (cycle de providers) :** `progressReporterProvider` watch `outputCoordinatorProvider`, donc le callback ci-dessus doit utiliser `ref.read` **paresseusement à l'appel** (c'est le cas : il est dans une closure exécutée plus tard, pas à la construction). Ajouter l'import `import '../domain/progress_phase.dart';`.

Enfin, injecter dans `inputRouterProvider` et `conversationEngineProvider` :

```dart
    progress: ref.watch(progressReporterProvider),
```

- [ ] **Step 7: Le Shell rend la bulle de statut**

Dans `lib/features/shell/presentation/kita_shell.dart`, ajouter l'import :

```dart
import '../di/progress_status_provider.dart';
```

Dans `_buildViewport`, après `final conversation = ref.watch(conversationFeedProvider);` :

```dart
    final status = ref.watch(progressStatusProvider);
```

Remplacer le calcul de `defaultViewport` par :

```dart
    final showFeed = conversation.isNotEmpty || status != null;
    final Widget defaultViewport = !showFeed
        ? Center(
            child: Text(
              'Tout va bien',
              style: TextStyle(
                color: const Color(0xFFE2E8F0)
                    .withValues(alpha: 0.5 + 0.5 * viewportOpacity),
                fontSize: 16,
              ),
            ),
          )
        : _ConversationFeedView(entries: conversation, status: status);
```

… et l'opacité :

```dart
    final opacity = showFeed ? 1.0 : 0.3 + 0.7 * viewportOpacity;
```

Puis, dans `_ConversationFeedView`, ajouter le paramètre et la bulle de statut en tête de liste (elle est *au-dessus* des messages puisque `reverse: true`) :

```dart
class _ConversationFeedView extends StatelessWidget {
  const _ConversationFeedView({required this.entries, this.status});

  final List<ConversationEntry> entries;

  /// Statut transitoire (« Réflexion… »). Affiché en bas, sous le dernier
  /// message, et remplacé dès que la vraie réponse arrive.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final hasStatus = status != null;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length + (hasStatus ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasStatus && index == 0) {
          return Semantics(
            liveRegion: true,
            label: 'Kita ${status!}',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3A5F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF475D8F)),
                ),
                child: Text(
                  status!,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          );
        }
        final entryIndex = hasStatus ? index - 1 : index;
        final entry = entries[entries.length - 1 - entryIndex];
        // … suite inchangée (bulle utilisateur / Kita)
```

> Conserver le corps existant de la bulle après cette ligne.

- [ ] **Step 8: Test de câblage (les repères ne polluent pas le fil)**

```dart
// test/features/orchestration/data/progress_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/orchestration/data/progress_reporter.dart';

void main() {
  test('les repères vocaux sont des constantes accentuées et courtes', () {
    // Lus par le TTS : les accents sont obligatoires (règle projet).
    expect(ProgressReporter.cueThinking, 'Un instant.');
    expect(ProgressReporter.cueWorking, 'Je regarde.');
    expect(ProgressReporter.cueThinking.length, lessThan(20));
    expect(ProgressReporter.cueWorking.length, lessThan(20));
  });
}
```

> Le fait que `speakCue` n'ajoute rien au fil est garanti par construction (il n'appelle pas `_onSpeechEnqueued`). Le vérifier à la relecture du diff de l'étape 1.

- [ ] **Step 9: Vérifier tout**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos
flutter test
```
Expected: analyze clean, **tous les tests verts**. Si un test de `output_coordinator` ou `input_router` casse à cause du nouveau paramètre optionnel, c'est qu'il est passé positionnellement : corriger l'appel, pas la signature.

- [ ] **Step 10: Commit**

```bash
git add lib/features/orchestration lib/features/shell test/features/orchestration
git commit -m "feat(orchestration): câbler le ProgressReporter (orbe, haptique, repères vocaux, bulle de statut)"
```

---

## Task 3 : Format d'appel d'outil compact (gain ~15 s)

**Files:**
- Modify: `lib/features/ai/data/providers/local_provider.dart`
- Test: `test/features/ai/data/providers/tool_call_parsing_test.dart`

**Interfaces:**
- Produces : `_parseGemmaToolResponse` accepte **`TOOL <nom> [arg]`** *et* le JSON legacy. Le prompt demande le format compact.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
// test/features/ai/data/providers/tool_call_parsing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';

void main() {
  group('parseLocalToolResponse', () {
    test('format compact sans argument', () {
      final call = parseLocalToolResponse('TOOL describe');
      expect(call, isNotNull);
      expect(call!.name, 'describe');
      expect(call.firstArg, isNull);
    });

    test('format compact avec argument', () {
      final call = parseLocalToolResponse('TOOL alert start');
      expect(call!.name, 'alert');
      expect(call.firstArg, 'start');
    });

    test('tolère les espaces et une ligne de bavardage avant', () {
      final call = parseLocalToolResponse('Bien sûr.\n  TOOL describe  ');
      expect(call!.name, 'describe');
    });

    test('accepte encore le JSON legacy', () {
      final call = parseLocalToolResponse(
        '{"tool_call": {"name": "alert", "arguments": {"action": "stop"}}}',
      );
      expect(call!.name, 'alert');
      expect(call.arguments['action'], 'stop');
    });

    test('texte simple → pas d\'appel d\'outil', () {
      expect(parseLocalToolResponse('Bonjour ! Comment vas-tu ?'), isNull);
    });

    test('outil inconnu → pas d\'appel d\'outil', () {
      expect(parseLocalToolResponse('TOOL inventer'), isNull);
    });
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `flutter test test/features/ai/data/providers/tool_call_parsing_test.dart`
Expected: FAIL — `parseLocalToolResponse` n'existe pas.

- [ ] **Step 3: Extraire un parseur pur, testable**

Dans `lib/features/ai/data/providers/local_provider.dart`, ajouter en haut de fichier (hors classe) :

```dart
/// Résultat brut d'un parsing d'appel d'outil local.
class ParsedToolCall {
  const ParsedToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;

  /// Première valeur d'argument (le format compact n'en porte qu'une).
  String? get firstArg =>
      arguments.isEmpty ? null : arguments.values.first as String?;
}

/// Outils connus. Un `TOOL <nom>` inconnu est traité comme du texte.
const Set<String> _knownTools = {'describe', 'alert'};

/// Nom du premier paramètre de chaque outil, pour mapper le format compact.
/// `describe` n'a plus de paramètre (voir Task 4).
const Map<String, String> _firstParamOf = {'alert': 'action'};

/// Parse une réponse Gemma en appel d'outil.
///
/// Accepte le format **compact** `TOOL <nom> [valeur]` (peu de tokens à
/// décoder : ~15 s gagnées sur device) et, en repli, le **JSON legacy**
/// `{"tool_call": {...}}` au cas où le modèle, instruction-tuné au JSON,
/// ignore la consigne. Retourne `null` si ce n'est pas un appel d'outil.
ParsedToolCall? parseLocalToolResponse(String text) {
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('TOOL ')) continue;
    final parts = line.substring(5).trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) continue;
    final name = parts.first;
    if (!_knownTools.contains(name)) return null;
    final args = <String, dynamic>{};
    if (parts.length > 1 && _firstParamOf[name] != null) {
      args[_firstParamOf[name]!] = parts[1];
    }
    return ParsedToolCall(name: name, arguments: args);
  }

  // Repli JSON legacy.
  final trimmed = text.trim();
  final jsonStart = trimmed.indexOf('{');
  final jsonEnd = trimmed.lastIndexOf('}');
  if (jsonStart >= 0 && jsonEnd > jsonStart) {
    try {
      final parsed =
          jsonDecode(trimmed.substring(jsonStart, jsonEnd + 1))
              as Map<String, dynamic>;
      final toolCall = parsed['tool_call'] as Map<String, dynamic>?;
      final name = toolCall?['name'] as String?;
      if (name != null && _knownTools.contains(name)) {
        return ParsedToolCall(
          name: name,
          arguments: (toolCall!['arguments'] as Map<String, dynamic>?) ?? {},
        );
      }
    } catch (_) {
      // Pas du JSON valide : ce n'est pas un appel d'outil.
    }
  }
  return null;
}
```

- [ ] **Step 4: Brancher le parseur dans `_parseGemmaToolResponse`**

Remplacer le corps de `_parseGemmaToolResponse` par :

```dart
  AIToolResponse? _parseGemmaToolResponse(String text, Duration latency) {
    final parsed = parseLocalToolResponse(text);
    if (parsed == null) return null;
    return AIToolResponse(
      toolCalls: [
        ToolCall(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          name: parsed.name,
          arguments: parsed.arguments,
        ),
      ],
      meta: AIResponseMeta(
        providerId: 'gemma',
        latency: latency,
        tier: ProviderTier.local,
      ),
    );
  }
```

> Supprimer l'ancien bloc `jsonDecode` devenu mort, et l'import `dart:convert` **seulement si** plus rien ne l'utilise dans le fichier (le vérifier).

- [ ] **Step 5: Demander le format compact au modèle**

Dans le prompt (≈ ligne 380), remplacer :

```dart
To call a tool, respond with ONLY a JSON object like:
{"tool_call": {"name": "tool_name", "arguments": {"key": "value"}}}

If you do not need a tool, respond with plain text.
```

par :

```dart
Pour appeler un outil, réponds UNIQUEMENT par une ligne :
TOOL nom_de_l_outil
TOOL nom_de_l_outil valeur

Sinon, réponds normalement en texte.
```

> Ce texte est décodé par le modèle : chaque token compte. Rester court.

- [ ] **Step 6: Vérifier**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
flutter test test/features/ai/
dart analyze --fatal-infos lib/features/ai/data/providers/local_provider.dart
```
Expected: tests PASS (dont les 6 nouveaux), analyze clean. Si `openai_provider_test` casse, c'est hors périmètre : ne pas y toucher.

- [ ] **Step 7: Commit**

```bash
git add lib/features/ai/data/providers/local_provider.dart test/features/ai/data/providers/tool_call_parsing_test.dart
git commit -m "perf(ai): format d'appel d'outil compact (TOOL <nom>) — ~30 tokens économisés par appel"
```

---

## Task 4 : Supprimer `detail_level` + prompts allégés (gain ~15 s + ~3 s)

**Files:**
- Modify: `lib/features/orchestration/data/kita_tools.dart`
- Modify: `lib/features/plugins/built_in/describe/describe_plugin.dart`
- Modify: `test/features/orchestration/domain/tool_spec_test.dart`

**Interfaces:**
- Consumes (Task 3) : `_firstParamOf` ne contient plus `describe` — cohérent une fois le paramètre supprimé.
- Produces : `KitaTools.describe` sans paramètre ; `DescribePlugin.describePrompt` bref, à première phrase courte.

- [ ] **Step 1: Retirer le paramètre mort de l'outil**

**Constat de code (vérifié) :** `DescribePlugin` n'utilise jamais `detail_level` — il applique toujours `describePrompt`. La granularité passe par la commande vocale existante « plus de détails ».

Dans `lib/features/orchestration/data/kita_tools.dart`, supprimer entièrement le bloc `parameters` de l'outil `describe` (les lignes `'detail_level': ToolParameter(...)`), et raccourcir sa `description` :

```dart
    name: toolDescribe,
    description:
        'Prend une photo et décrit ce que la caméra voit. À utiliser quand '
        "l'utilisateur veut savoir ce qu'il y a autour de lui.",
```

Raccourcir aussi la description de `alert` (garder son paramètre `action`) :

```dart
    name: toolAlert,
    description:
        "Active ('start') ou désactive ('stop') la surveillance d'obstacles "
        'en temps réel.',
```

- [ ] **Step 2: Mettre à jour le test de structure d'outil**

Dans `test/features/orchestration/domain/tool_spec_test.dart`, le test « KitaTools describe has expected structure » attend `detail_level`. Le remplacer par :

```dart
    test('describe n\'expose plus de paramètre (detail_level supprimé)', () {
      expect(KitaTools.describe.parameters, isEmpty);
    });
```

Et dans les tests `toGemmaPrompt()` du même fichier, supprimer les assertions portant sur `detail_level`, `(optionnel)`, `brief`, `detailed` pour l'outil `describe` (elles ne s'appliquent plus). Conserver `expect(prompt, contains('Outil "describe"'))`.

- [ ] **Step 3: Première phrase courte + description brève**

Dans `lib/features/plugins/built_in/describe/describe_plugin.dart`, remplacer `describePrompt` :

```dart
  /// Prompt de description par défaut : bref, et surtout **première phrase
  /// très courte**. Le SentenceBuffer n'émet qu'une phrase terminée : une
  /// première phrase de 45 tokens = 25 s de silence mesurées sur device.
  static const describePrompt = '''
Décris cette image en français pour une personne aveugle.
Commence par une phrase très courte (5 à 8 mots) nommant l'élément principal.
Puis ajoute 1 ou 2 phrases de détails, en situant les objets (gauche, droite,
devant, derrière). Sois concret. N'identifie jamais les personnes.
Ne mentionne pas que c'est une image.''';
```

> Laisser `detailedPrompt` **inchangé** : c'est lui qui sert à « plus de détails ».

- [ ] **Step 4: Vérifier**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
flutter test test/features/orchestration/ test/features/plugins/
dart analyze --fatal-infos
```
Expected: tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/orchestration/data/kita_tools.dart lib/features/plugins/built_in/describe/describe_plugin.dart test/features/orchestration/domain/tool_spec_test.dart
git commit -m "perf(ai): supprimer detail_level (paramètre mort) + première phrase de description courte"
```

---

## Task 5 : Validation sur device et mesure des gains (manuel, avec Charles)

**Files:**
- Modify: `docs/superpowers/specs/2026-07-09-progression-et-latence-design.md` (section « Attendu » → mesures réelles)

**Interfaces:** consomme tout ce qui précède.

- [ ] **Step 1: Suite complète + build**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos
flutter test
flutter build apk --release --target-platform android-arm64
```
Expected: analyze clean, tous les tests verts, APK construit.

- [ ] **Step 2: Installer et relancer**

```bash
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_SERIAL=192.168.201.65:43233
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.kita.kita/.MainActivity
```

- [ ] **Step 3: Mesurer un « décris » complet**

Demander à Charles d'envoyer « décris », puis extraire les chronos :

```bash
PID=$(adb shell pidof com.kita.kita | tr -d '\r')
adb logcat -d -v time | grep "$PID" | grep -E "Handling input|Phase:|Tool-use request completed|Photo captured:|Entry added \(kita|Streaming description complete"
```

Relever : instant d'entrée, fin de décision tool-use, 1ʳᵉ phrase (`Entry added (kita`), fin. En déduire **premier mot entendu** et **total**.

Expected (spec) : premier mot ~20 s, total ~35 s. **Consigner les chiffres réels, même s'ils déçoivent.**

- [ ] **Step 4: Vérifier le retour de progression (le vrai livrable)**

Avec Charles, confirmer :
- vibration immédiate à l'envoi ;
- bulle « Réflexion… » à l'écran ;
- « Un instant. » prononcé une seule fois si l'attente dépasse 2,5 s ;
- « Je regarde. » prononcé une seule fois quand la photo part ;
- la bulle de statut **disparaît** quand la vraie réponse arrive ;
- aucune bulle « Un instant. » ni « Je regarde. » ne **reste** dans le fil.

Capture d'écran de contrôle (le device doit être déverrouillé et l'app au premier plan) :

```bash
adb exec-out screencap -p > /tmp/kita-progress.png
```

- [ ] **Step 5: Consigner les mesures et commiter**

Remplacer le tableau « 5.5 Attendu » du spec par les mesures réelles, sous un titre
« Mesuré après implémentation (2026-07-XX) », en conservant la colonne « Avant ».

```bash
git add docs/superpowers/specs/2026-07-09-progression-et-latence-design.md
git commit -m "docs: mesures réelles de latence après optimisation"
```
