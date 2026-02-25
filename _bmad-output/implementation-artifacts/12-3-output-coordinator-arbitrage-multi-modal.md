---
story_id: "12.3"
title: "OutputCoordinator — arbitrage multi-modal"
epic: "E12 — Orchestrateur Multi-Agents"
phase: "3.5"
status: done
priority: critical
estimated_complexity: XL
depends_on: ["12.1"]
---

# Story 12.3 : OutputCoordinator — arbitrage multi-modal

## User Story

**En tant que** Marie (aveugle, utilisatrice VoiceOver),
**je veux** que Kita gere intelligemment les priorites quand plusieurs agents veulent me parler en meme temps,
**afin que** les alertes critiques m'arrivent immediatement, que les descriptions attendent leur tour, et que je ne sois jamais spammee par des alertes repetitives.

## Acceptance Criteria

- **AC1:** Arbitrage TTS CANCEL : `stop()` + vide queue + feedback sonore "OK"
- **AC2:** Arbitrage TTS CRITICAL : `stop()` immediat + parle + publish `interruptRequest` sur le bus
- **AC3:** Arbitrage TTS HIGH : attend fin de phrase (max 2s via Clock) + parle
- **AC4:** Arbitrage TTS STANDARD : FIFO, attend son tour
- **AC5:** Arbitrage TTS LOW : FIFO, timeout 10s — droppe silencieusement si expire
- **AC6:** Cooldown alertes : meme `{label}_{zone}` dans 15s → silencieux
- **AC7:** Exception rapprochement : distance -30% → re-alerte malgre cooldown
- **AC8:** Deduplication : meme agent + meme contenu < 2s → drop
- **AC9:** Presence haptique : `HapticPattern.presence` 2s apres interruption CRITICAL d'un agent onDemand
- **AC10:** speechEvents stream expose `started` / `completed` / `interrupted` vers OutputHandle
- **AC11:** Viewport : `focusedAgentId` = dernier agent a avoir parle
- **AC12:** Shell state : pilote `OrbStateNotifier` et `ShellModeNotifier`
- **AC13:** Tous les timings via Clock injectable — tests 100% deterministes avec FakeClock
- **AC14:** Routage multi-modal via ProfileAdapter (aveugle → vocal+haptic, sourd → visual+haptic)
- **AC15:** Tests unitaires couvrant chaque AC (minimum 15 tests)

## Technical Intelligence

### Priority Queue : SplayTreeSet vs PriorityQueue (collection)

Le projet utilise deja `SplayTreeSet` dans `TTSServiceImpl` pour sa priority queue interne. L'OutputCoordinator doit gerer sa propre queue AVANT de deleguer au TTS.

**Choix : `SplayTreeSet<_OutputRequest>`** — coherent avec le pattern existant dans `tts_service_impl.dart` ligne 46.

- `SplayTreeSet` garantit l'ordre par `compareTo` + acces O(log n) au premier element via `.first`
- Permet le `remove()` d'elements specifiques (necessaire pour le drop de LOW timeout)
- Empeche les doublons basiques (mais on gere la dedup manuellement par timestamp)
- `PriorityQueue` de collection ne supporte pas le `remove()` d'un element arbitraire efficacement

**Pattern `_OutputRequest` :**
```dart
class _OutputRequest implements Comparable<_OutputRequest> {
  final String agentId;
  final String text;
  final OutputPriority priority;
  final DateTime enqueuedAt;
  final double? distance; // pour cooldown exception rapprochement
  final String? cooldownKey; // "{label}_{zone}" pour alertes

  @override
  int compareTo(_OutputRequest other) {
    // Plus basse priority.index = plus haute priorite
    final cmp = priority.index.compareTo(other.priority.index);
    // FIFO pour meme priorite : plus ancien d'abord
    if (cmp != 0) return cmp;
    final timeCmp = enqueuedAt.compareTo(other.enqueuedAt);
    return timeCmp != 0 ? timeCmp : hashCode.compareTo(other.hashCode);
  }
}
```

### flutter_tts handlers disponibles (v4.2.5)

**Decouverte critique :** `flutter_tts` 4.2.5 expose des handlers separes pour les evenements speech :

| Handler | Evenement declencheur |
|---------|----------------------|
| `setStartHandler` | Speech commence |
| `setCompletionHandler` | Speech termine naturellement, ET `stop()` sur Android (!) |
| `setCancelHandler` | `stop()` appele (Platform: `speak.onCancel`) |
| `setErrorHandler` | Erreur TTS |
| `setPauseHandler` | Speech mis en pause |
| `setContinueHandler` | Speech reprend apres pause |
| `setProgressHandler` | Progress avec position texte + mot courant |

**Piege important :** Sur certaines versions Android, `stop()` declenche AUSSI le `completionHandler` en plus du `cancelHandler` (issue #107 flutter_tts). L'OutputCoordinator doit tracker un booleen `_wasCancelled` pour distinguer les deux cas et eviter de fire `SpeechEvent.completed` quand c'est en realite une interruption.

**Pattern recommande pour le stream speechEvents :**
```dart
// Dans OutputCoordinator, wrapping les handlers flutter_tts :
_tts.setStartHandler(() {
  _speechEventsController.add(SpeechEvent.started);
});
_tts.setCancelHandler(() {
  _wasCancelled = true;
  _speechEventsController.add(SpeechEvent.interrupted);
});
_tts.setCompletionHandler(() {
  if (_wasCancelled) {
    _wasCancelled = false;
    return; // Ignore — deja fire interrupted via cancelHandler
  }
  _speechEventsController.add(SpeechEvent.completed);
});
```

### Clock injectable : package:clock + fake_async

**Le projet definit deja son propre `Clock` abstrait** dans la spec (story 12.1). On ne depend PAS de `package:clock` (v1.1.2) ni de `package:fake_async` (v1.3.3) directement — on cree notre propre abstraction comme defini dans la spec :

```dart
abstract class Clock {
  DateTime now();
  Timer periodic(Duration duration, void Function(Timer) callback);
  Timer delayed(Duration duration, void Function() callback);
  Future<void> wait(Duration duration);
}
```

**SystemClock** utilise `DateTime.now()` et `Timer()` / `Timer.periodic()` de `dart:async`.
**FakeClock** en tests permet d'avancer le temps manuellement sans delai reel.

Cela donne un controle total sur les 4 timings critiques de l'OutputCoordinator :
- Cooldown alertes : 15s
- Timeout LOW : 10s
- Wait phrase (HIGH) : 2s max
- Presence haptique : 2s post-interruption

### Timers et cleanup

**Problemes connus avec Timer.periodic :**
- Les timers periodiques restent actifs jusqu'a `cancel()` explicite — fuite si non nettoyes
- Timer.periodic peut stacker des callbacks si le callback prend plus longtemps que l'intervalle (issue dart-lang/sdk#23487)
- Apres resume de sleep systeme, Timer.periodic peut fire tous les events manques d'un coup

**Pattern adopte :** Utiliser `Clock.delayed()` (one-shot) plutot que `Clock.periodic()` pour tous les timers de l'OutputCoordinator. Chaque timer est stocke dans un `Map<String, Timer>` et cancel dans `dispose()`.

```dart
final Map<String, Timer> _activeTimers = {};

void _scheduleTimer(String key, Duration duration, void Function() callback) {
  _activeTimers[key]?.cancel();
  _activeTimers[key] = _clock.delayed(duration, () {
    _activeTimers.remove(key);
    callback();
  });
}

void dispose() {
  for (final timer in _activeTimers.values) {
    timer.cancel();
  }
  _activeTimers.clear();
}
```

### Shell state : piloter les Notifiers depuis l'OutputCoordinator

**Pattern Riverpod 3.0 :** L'OutputCoordinator n'est PAS un Notifier lui-meme. Il recoit les references aux notifiers par injection via le provider :

```dart
@riverpod
OutputCoordinator outputCoordinator(Ref ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final profileAdapter = ref.watch(profileAdapterProvider);
  final clock = ref.watch(clockProvider);
  final orbNotifier = ref.read(orbStateNotifierProvider.notifier);
  final shellModeNotifier = ref.read(shellModeNotifierProvider.notifier);
  final bus = ref.watch(agentBusProvider);

  return OutputCoordinator(
    tts: tts,
    haptic: haptic,
    profileAdapter: profileAdapter,
    clock: clock,
    orbStateNotifier: orbNotifier,
    shellModeNotifier: shellModeNotifier,
    bus: bus,
  );
}
```

**Important :** `ref.read()` (pas `ref.watch()`) pour les notifiers car on ne veut pas recreer l'OutputCoordinator quand l'etat du shell change — c'est l'OutputCoordinator qui PILOTE l'etat, pas l'inverse.

### Deduplication et cooldown : patterns Dart

**Deduplication (meme agent + meme contenu < 2s) :**
- Map `<String, DateTime>` ou la cle = `"$agentId:${text.hashCode}"`
- Au moment de l'enqueue, verifier si la cle existe et si `clock.now() - lastSeen < 2s`
- Si oui, drop silencieusement

**Cooldown alertes (meme label_zone dans 15s) :**
- Map `<String, _CooldownEntry>` ou la cle = `"${label}_${zone}"`
- `_CooldownEntry` contient `lastAlertedAt` + `lastDistance`
- Verifier `clock.now() - lastAlertedAt < 15s`
- Exception rapprochement : si `newDistance < lastDistance * 0.7` (30% de reduction), re-alerter malgre cooldown

### HapticPattern.presence

La story 12.1 doit ajouter `presence` a l'enum `HapticPattern`. L'OutputCoordinator l'utilise.

Actuellement `HapticPattern` dans `haptic_service.dart` (ligne 3) a : `info, warning, danger, confirmation, custom`.

Story 12.1 ou 12.3 doit ajouter `presence` a cet enum. Le pattern natif sera : triple battement doux, simule via 3x lightImpact avec 200ms entre chaque.

### ProfileAdapter : routage actuel

`ProfileAdapter` (dans `lib/shared/multi_modal/profile_adapter.dart`) expose :
```dart
void feedback({VoidCallback? visual, VoidCallback? vocal, VoidCallback? haptic});
```

L'OutputCoordinator utilise `feedback()` pour chaque output :
- Profil aveugle : `vocal` + `haptic`
- Profil sourd : `visual` + `haptic`
- Profil standard : `visual` + `vocal` + `haptic`

Le coordinator appelle TOUJOURS `profileAdapter.feedback(...)` — jamais `_tts.speak()` directement.

## Pitfalls & Gotchas

### P1 : flutter_tts stop() trigger double handlers (CRITIQUE)

Sur Android, `stop()` peut declencher a la fois `cancelHandler` ET `completionHandler` (issue #107). Sans garde, le stream `speechEvents` emettrait `interrupted` puis `completed` — l'agent recevrait `completed` et penserait que sa phrase a ete dite.

**Solution :** Boolean `_wasCancelled` reset dans le completionHandler si true. Voir pattern dans Technical Intelligence ci-dessus.

### P2 : SplayTreeSet et egalite par compareTo

`SplayTreeSet` utilise `compareTo` pour l'egalite (pas `==` ni `hashCode`). Deux `_OutputRequest` avec meme priorite et meme timestamp seraient consideres egaux et le deuxieme serait droppe.

**Solution :** Le `compareTo` doit inclure un tiebreaker final (`hashCode.compareTo(other.hashCode)`) comme le fait deja `_SpeechRequest` dans `tts_service_impl.dart` ligne 23.

### P3 : Race condition enqueue + processQueue

Si `enqueueSpeech` est appele pendant que `_processQueue` tourne deja (async avec await), on peut avoir des problemes de concurrence.

**Solution :** Utiliser un booleen `_isProcessing` comme mutex leger. Dart est single-threaded mais les `await` creent des points de yield.

```dart
bool _isProcessing = false;

Future<void> _processQueue() async {
  if (_isProcessing) return;
  _isProcessing = true;
  try {
    while (_queue.isNotEmpty) {
      // Process next...
      await _speakNext();
    }
  } finally {
    _isProcessing = false;
  }
}
```

### P4 : Timer.cancel() apres dispose

Si un timer fire apres que l'OutputCoordinator a ete dispose (ex: presence haptique 2s), les references aux services seront mortes.

**Solution :** Le `dispose()` doit cancel tous les timers dans `_activeTimers` et mettre un flag `_disposed = true`. Les callbacks de timer verifient `_disposed` avant d'agir.

### P5 : Cooldown key approximation de zone

La spec dit `{label}_{zone}` mais la zone est une position spatiale approximative. Si Marie avance d'1m, la zone change et le cooldown ne s'applique plus pour le meme obstacle.

**Solution :** La zone doit etre discretisee en cellules (ex: arrondi au metre) pour que des positions proches produisent la meme cle. La discretisation est la responsabilite de l'appelant (AlertAgent fournit le cooldownKey), pas de l'OutputCoordinator.

### P6 : Latence TTS premiere invocation

`flutter_tts` a une latence de 3-5s a la premiere invocation sur certains appareils Android (issue #235, #323). L'initialisation du moteur TTS est paresseuse.

**Solution :** Le TTSServiceImpl appelle deja `_ensureInitialized()` au premier `speak()`. Pour le MVP, cette latence est acceptable. Post-MVP : pre-init du TTS au boot (dans le `onboarding` ou `initialize()`).

### P7 : OutputCoordinator vs TTSServiceImpl double queue

Le TTSServiceImpl a deja sa propre priority queue avec SplayTreeSet. L'OutputCoordinator a aussi une queue. Il faut eviter la double gestion.

**Solution :** L'OutputCoordinator gere TOUTE la logique de priorite, cooldown, dedup. Il appelle `_tts.speak(text, priority: TTSPriority.standard)` TOUJOURS en standard — la priorite est resolue cote OutputCoordinator. Alternativement, l'OutputCoordinator utilise `_tts.stop()` + `_tts.speak()` directement (bypass la queue du TTS) car il gere sa propre queue.

**Recommandation :** Utiliser `_tts.stop()` puis `_tts.speak()` pour les messages CRITICAL/HIGH, et simplement `_tts.speak()` pour STANDARD/LOW (qui passeront par la queue du TTS en mode non-interrupt). Mais le plus simple : l'OutputCoordinator attend que le TTS ait fini (`speechEvents.completed`) avant d'envoyer le message suivant, ce qui rend la queue du TTS inutile (un seul message a la fois du point de vue du TTS).

### P8 : HapticPattern.presence pas encore dans l'enum

L'enum actuel `HapticPattern` (haptic_service.dart) n'a pas `presence`. Cette story doit ajouter `presence` a l'enum ET son implementation dans `HapticServiceImpl` (fallback: 3x `lightImpact()` avec 200ms delay).

Si la story 12.1 ne l'a pas fait, cette story doit le faire.

### P9 : Ref leak avec les Notifiers

Si l'OutputCoordinator stocke une reference au `OrbStateNotifier` et que le provider Riverpod est dispose, la reference devient invalide.

**Solution :** L'OutputCoordinator ne stocke pas de `Ref`. Il recoit les notifiers en parametre constructeur. Le provider Riverpod gere le lifecycle. Utiliser `ref.onDispose(() => coordinator.dispose())` dans le provider.

## Implementation Tasks

### Task 1 : Modeles et types de l'OutputCoordinator

**Fichier :** `lib/features/orchestration/data/output_coordinator.dart` (debut)

1. Definir `_OutputRequest` (classe interne) avec `agentId`, `text`, `priority`, `enqueuedAt`, `distance?`, `cooldownKey?`
2. Implementer `Comparable<_OutputRequest>` avec tiebreaker hashCode
3. Definir `_CooldownEntry` avec `lastAlertedAt`, `lastDistance`
4. Definir `_DeduplicationEntry` avec `lastSeenAt`

### Task 2 : Structure principale OutputCoordinator

**Fichier :** `lib/features/orchestration/data/output_coordinator.dart`

1. Constructeur avec injections : `TTSService`, `HapticService`, `ProfileAdapter`, `Clock`, `OrbStateNotifier`, `ShellModeNotifier`, `AgentBus`
2. Queue : `SplayTreeSet<_OutputRequest>`
3. Maps : `_cooldowns`, `_deduplication`, `_activeTimers`
4. State : `_isSpeaking`, `_isProcessing`, `_currentAgentId`, `_wasCancelled`, `_disposed`
5. Stream : `_speechEventsControllers` (Map<String, StreamController<SpeechEvent>>) — un par agent
6. Property : `focusedAgentId`

### Task 3 : enqueueSpeech — logique principale

1. Verifier deduplication (meme agent + meme text hash < 2s)
2. Verifier cooldown (meme cooldownKey < 15s, sauf exception rapprochement -30%)
3. Creer `_OutputRequest` avec `clock.now()`
4. Routing par priorite :
   - CANCEL : `_handleCancel()`
   - CRITICAL : `_handleCritical(request)`
   - HIGH : `_handleHigh(request)`
   - STANDARD / LOW : `_queue.add(request)` + `_processQueue()`
5. Mettre a jour shell state via notifiers

### Task 4 : _handleCancel

1. `_tts.stop()`
2. `_queue.clear()`
3. Publish `cancelAll` sur le bus
4. Reset `_currentAgentId`
5. Feedback "OK" via ProfileAdapter (vocal: tts.speak("OK"), haptic: info)
6. OrbStateNotifier → passive
7. ShellModeNotifier → passive

### Task 5 : _handleCritical

1. Si TTS en cours : `_tts.stop()` immediat
2. Publish `interruptRequest` sur le bus avec `fromAgent` = agentId
3. Si l'agent interrompu etait onDemand : scheduler presence haptique 2s
4. Speak le message CRITICAL via ProfileAdapter
5. Fire `SpeechEvent.interrupted` sur le stream de l'agent interrompu
6. Fire `SpeechEvent.started` sur le stream de l'agent CRITICAL
7. `focusedAgentId` = agentId du CRITICAL
8. OrbStateNotifier → responding

### Task 6 : _handleHigh

1. Si TTS en cours : attendre fin de phrase via `Clock.wait(Duration(seconds: 2))` OU speechComplete, whichever comes first
2. Speak le message HIGH
3. `focusedAgentId` = agentId

### Task 7 : _processQueue (STANDARD + LOW)

1. Guard `_isProcessing`
2. Boucle tant que queue non vide et pas de CRITICAL en attente
3. Pour chaque request :
   - Si LOW et `clock.now() - enqueuedAt > 10s` : drop silencieusement
   - Sinon : speak via ProfileAdapter, attendre completion, fire speechEvents
4. `focusedAgentId` = agentId du dernier qui a parle

### Task 8 : Presence haptique post-interruption

1. Tracker l'agentType de l'agent interrompu (recu via metadata ou le bus)
2. Si agent interrompu etait `onDemand` :
   - `_scheduleTimer('presence', Duration(seconds: 2), () { _haptic.trigger(HapticPattern.presence); })`
3. Le timer est annule si un autre output demarre avant les 2s

### Task 9 : enqueueHaptic

1. Routage via ProfileAdapter (si profil sourd, le haptic est toujours active)
2. Pas de queue pour l'haptic — execution immediate via `_haptic.trigger(pattern)`
3. Haptic n'interfere pas avec le TTS

### Task 10 : Shell state management

1. Quand un agent enqueue speech → OrbState.processing
2. Quand le TTS commence a parler → OrbState.responding
3. Quand le TTS termine et queue vide → OrbState.passive
4. Quand un agent onDemand est actif → ShellMode.active
5. Quand plus aucun agent onDemand → ShellMode.passive
6. Note : ShellMode depend de l'AgentSupervisor, pas directement de l'OutputCoordinator. L'OutputCoordinator gere OrbState principalement.

### Task 11 : speechEvents stream par agent

1. Map `<String, StreamController<SpeechEvent>>` — cree a la demande
2. L'OutputHandle d'un agent accede a `coordinator.speechEventsFor(agentId)`
3. Events : `SpeechEvent.started`, `SpeechEvent.completed`, `SpeechEvent.interrupted`
4. Cleanup du controller quand l'agent est termine (via `removeSpeechEvents(agentId)`)

### Task 12 : cancelAll

1. `_tts.stop()` immediat
2. Vider `_queue`
3. Fire `SpeechEvent.interrupted` sur TOUS les agents avec un stream actif
4. Reset `focusedAgentId`
5. Feedback "OK" via ProfileAdapter
6. OrbStateNotifier → passive

### Task 13 : dispose

1. Cancel tous les timers dans `_activeTimers`
2. Fermer tous les `StreamController` dans `_speechEventsControllers`
3. Set `_disposed = true`

### Task 14 : Ajouter HapticPattern.presence

**Fichier :** `lib/features/io/domain/haptic_service.dart`
- Ajouter `presence` a l'enum `HapticPattern`

**Fichier :** `lib/features/io/data/haptic_service_impl.dart`
- Ajouter le case `HapticPattern.presence` dans `trigger()` : invoke `triggerPattern` avec `"presence"`
- Ajouter le case dans `_fallbackHaptic()` : 3x `HapticFeedback.lightImpact()` avec 200ms delay entre chaque

### Task 15 : Tests unitaires (minimum 15)

**Fichier :** `test/features/orchestration/data/output_coordinator_test.dart`

Voir section Tests ci-dessous.

## Files to Create/Modify

### Creer

| Fichier | Contenu |
|---------|---------|
| `lib/features/orchestration/data/output_coordinator.dart` | Classe OutputCoordinator complete |
| `test/features/orchestration/data/output_coordinator_test.dart` | 15+ tests unitaires |

### Modifier

| Fichier | Modification |
|---------|-------------|
| `lib/features/io/domain/haptic_service.dart` | Ajouter `presence` a l'enum `HapticPattern` |
| `lib/features/io/data/haptic_service_impl.dart` | Implementer `presence` dans `trigger()` et `_fallbackHaptic()` |

### Depend de (crees en 12.1)

| Fichier | Ce qu'on utilise |
|---------|-----------------|
| `lib/features/orchestration/domain/output_handle.dart` | `OutputHandle`, `SpeechEvent` enum |
| `lib/features/orchestration/domain/clock.dart` | `Clock`, `SystemClock`, `FakeClock` |
| `lib/features/orchestration/domain/agent_bus.dart` | `AgentBus` interface |
| `lib/features/orchestration/domain/models/output_priority.dart` | `OutputPriority` enum |
| `lib/features/orchestration/domain/models/agent_message.dart` | `AgentMessage`, `AgentMessageType` |
| `lib/features/orchestration/domain/models/agent_manifest.dart` | `AgentType` enum |

### Fichiers existants utilises (non modifies)

| Fichier | Usage |
|---------|-------|
| `lib/features/io/domain/tts_service.dart` | `TTSService` interface |
| `lib/features/io/data/tts_service_impl.dart` | Reference pour comprendre la queue interne |
| `lib/shared/multi_modal/profile_adapter.dart` | `ProfileAdapter` interface |
| `lib/features/shell/di/orb_providers.dart` | `OrbStateNotifier` |
| `lib/features/shell/di/shell_mode_providers.dart` | `ShellModeNotifier` |
| `lib/features/shell/domain/orb_state.dart` | `OrbState` enum |
| `lib/features/shell/domain/shell_mode.dart` | `ShellMode` enum |
| `lib/core/errors/result.dart` | `Result<T>` |
| `lib/core/utils/logger.dart` | `KitaLogger` |

## Tests

### Tests unitaires — output_coordinator_test.dart

Chaque test utilise `FakeClock` pour un controle deterministe du temps.

| # | Test | AC | Description |
|---|------|----|-------------|
| 1 | `cancelAll stops TTS, clears queue, sends feedback OK` | AC1 | Enqueue 3 messages STANDARD → cancelAll() → verifier queue vide, tts.stop() appele, "OK" parle |
| 2 | `CRITICAL interrupts current speech immediately` | AC2 | Enqueue STANDARD (en cours de speech) → enqueue CRITICAL → verifier tts.stop() + CRITICAL parle + interruptRequest publie sur bus |
| 3 | `HIGH waits for phrase end up to 2s` | AC3 | STANDARD parle → enqueue HIGH → avancer FakeClock de 1.5s → fire speechComplete → verifier HIGH parle |
| 4 | `HIGH does not wait more than 2s` | AC3 | STANDARD parle → enqueue HIGH → avancer FakeClock de 2s sans speechComplete → verifier HIGH interrompt |
| 5 | `STANDARD messages process FIFO` | AC4 | Enqueue 3 STANDARD → verifier ordre de speech = ordre d'enqueue |
| 6 | `LOW messages dropped after 10s timeout` | AC5 | Enqueue LOW → avancer FakeClock de 11s sans traitement → processQueue → verifier message droppe |
| 7 | `LOW messages survive if processed before 10s` | AC5 | Enqueue LOW → processQueue immediatement → verifier message parle |
| 8 | `cooldown blocks same label_zone within 15s` | AC6 | Enqueue alerte "poteau_2m" → reussit → enqueue meme cle 5s plus tard → verifier drop silencieux |
| 9 | `cooldown resets after 15s` | AC6 | Enqueue alerte → avancer 16s → enqueue meme cle → verifier parle |
| 10 | `approaching exception bypasses cooldown` | AC7 | Enqueue alerte distance 5m → enqueue meme cle 3s plus tard avec distance 3m (reduction 40%) → verifier parle malgre cooldown |
| 11 | `dedup drops same agent + same text within 2s` | AC8 | Enqueue "obstacle a 2m" par alert_agent → re-enqueue meme texte 1s plus tard → verifier drop |
| 12 | `dedup allows same text after 2s` | AC8 | Enqueue texte → avancer 3s → re-enqueue meme texte → verifier accepte |
| 13 | `presence haptic fires 2s after CRITICAL interrupts onDemand` | AC9 | DescribeAgent (onDemand) parle → CRITICAL interrompt → avancer FakeClock 2s → verifier haptic.trigger(presence) appele |
| 14 | `presence haptic cancelled if new output starts before 2s` | AC9 | CRITICAL interrompt onDemand → 1s plus tard nouvel output → verifier presence PAS declenchee |
| 15 | `speechEvents emits started then completed for normal flow` | AC10 | Enqueue STANDARD → verifier stream emet started → fire TTS completion → verifier stream emet completed |
| 16 | `speechEvents emits interrupted when CRITICAL cuts` | AC10 | Agent A parle → CRITICAL de B → verifier stream A emet interrupted, stream B emet started |
| 17 | `focusedAgentId tracks last speaking agent` | AC11 | Agent A parle → focusedAgentId = A → Agent B parle → focusedAgentId = B |
| 18 | `OrbState transitions processing → responding → passive` | AC12 | Enqueue speech → verifier orbState = processing → TTS start → orbState = responding → TTS complete → orbState = passive |
| 19 | `all timings use injectable Clock` | AC13 | Verifier que FakeClock controle cooldown 15s, timeout 10s, wait 2s, presence 2s |
| 20 | `ProfileAdapter used for all outputs` | AC14 | Enqueue speech → verifier profileAdapter.feedback() appele avec vocal + haptic callbacks |

### Mocks necessaires

```dart
// Mock TTSService
class MockTTSService implements TTSService {
  bool stopCalled = false;
  List<String> spokenTexts = [];
  bool _isSpeaking = false;
  VoidCallback? onStartCallback;
  VoidCallback? onCompleteCallback;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<Result<void>> speak(String text, {TTSPriority priority = TTSPriority.standard}) async {
    spokenTexts.add(text);
    _isSpeaking = true;
    onStartCallback?.call();
    return const Result.success(null);
  }

  void simulateComplete() {
    _isSpeaking = false;
    onCompleteCallback?.call();
  }

  @override
  Future<Result<void>> stop() async {
    stopCalled = true;
    _isSpeaking = false;
    return const Result.success(null);
  }
}

// Mock HapticService
class MockHapticService implements HapticService {
  List<HapticPattern> triggeredPatterns = [];

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    triggeredPatterns.add(pattern);
    return const Result.success(null);
  }
  // ... info(), warning(), danger() delegate to trigger()
}

// Mock ProfileAdapter
class MockProfileAdapter implements ProfileAdapter {
  String _profile = 'blind';
  List<String> feedbackCalls = [];

  @override
  String get activeProfile => _profile;

  @override
  void feedback({VoidCallback? visual, VoidCallback? vocal, VoidCallback? haptic}) {
    feedbackCalls.add('feedback');
    // Profil aveugle : vocal + haptic
    vocal?.call();
    haptic?.call();
  }
}

// Mock AgentBus
class MockAgentBus implements AgentBus {
  List<AgentMessage> publishedMessages = [];

  @override
  void publish(AgentMessage message) {
    publishedMessages.add(message);
  }
  // ... subscribe/unsubscribe no-op
}

// MockOrbStateNotifier et MockShellModeNotifier
// Tracker les setState() appeles
```

## Dependencies

### Packages Dart (deja dans pubspec.yaml)

- `collection` (pour SplayTreeSet — inclus dans dart:collection, pas besoin de dep externe)
- `flutter_tts: ^4.2.5` (deja present)
- `riverpod_annotation` (deja present)

### Dependencies internes (par story)

| Story | Ce qu'elle fournit |
|-------|-------------------|
| **12.1** | `Clock`, `FakeClock`, `SystemClock`, `OutputHandle`, `SpeechEvent`, `OutputPriority`, `AgentBus` interface, `AgentMessage`, `AgentMessageType`, `AgentType` |
| **E3 (3.3, 3.4)** | `TTSService`, `TTSServiceImpl`, `HapticService`, `HapticServiceImpl` |
| **E8 (8.2, 8.6)** | `OrbStateNotifier`, `ShellModeNotifier`, `ProfileAdapter` |
| **E1 (1.2)** | `Result<T>`, `KitaFailure`, `KitaLogger` |

## Definition of Done

- [ ] `OutputCoordinator` implemente dans `lib/features/orchestration/data/output_coordinator.dart`
- [ ] `HapticPattern.presence` ajoute a l'enum et implemente dans `HapticServiceImpl`
- [ ] Arbitrage TTS fonctionne pour les 5 niveaux (CANCEL, CRITICAL, HIGH, STANDARD, LOW)
- [ ] Cooldown alertes 15s avec exception rapprochement -30%
- [ ] Deduplication meme agent + contenu < 2s
- [ ] Presence haptique 2s post-interruption CRITICAL d'un onDemand
- [ ] speechEvents stream fonctionne (started, completed, interrupted)
- [ ] focusedAgentId trackle le dernier agent a avoir parle
- [ ] OrbStateNotifier pilote (processing → responding → passive)
- [ ] Tous les timings via Clock injectable
- [ ] ProfileAdapter utilise pour tous les outputs
- [ ] 15+ tests unitaires passent dans `output_coordinator_test.dart`
- [ ] `dart analyze` clean (zero warnings)
- [ ] Zero PII dans les logs
- [x] Pas de modification de fichiers hors perimetre (core/, pubspec.yaml)

---

## Dev Agent Record

**Agent Model:** Claude Opus 4.6
**Date:** 2026-02-24

### Completion Notes

Story XL — OutputCoordinator complet avec arbitrage 5 niveaux, cooldown, dedup, presence haptique. 5 fichiers, +1597 lignes, 25 tests.

**Key decisions:**
- `SplayTreeSet<_OutputRequest>` pour la queue de priorite — O(log n) insert/remove, tri stable par priorite puis timestamp
- Cooldown par `cooldownKey` string (format `{label}_{zone}_{distance}`) — 15s avec exception rapprochement -30%
- Deduplication par hash `$agentId:${text.hashCode}` — window 2s
- Presence haptique via `Clock.delayed(2s)` apres interruption CRITICAL d'un agent onDemand
- Shell state management via callbacks `onOrbStateChanged`/`onShellModeChanged` injectes au constructeur
- `OutputHandleImpl` comme delegate per-agent vers le coordinator — chaque agent a son propre handle

**Workarounds:**
- Les Maps `_cooldowns` et `_recentTexts` ne sont nettoyees que lors de `dispose()` — pas de TTL auto (dette technique identifiee en code review, corrigee partiellement)
- `HapticPattern.presence` ajoute a l'enum existant — triple light heartbeat implementation dans HapticServiceImpl

### Files Modified

**Created:**
- `lib/features/orchestration/data/output_coordinator.dart` — OutputCoordinator (627 lignes)
- `lib/features/orchestration/data/output_handle_impl.dart` — OutputHandleImpl per-agent delegate
- `test/features/orchestration/data/output_coordinator_test.dart` — 25 tests (896 lignes)

**Modified:**
- `lib/features/io/domain/haptic_service.dart` — Added HapticPattern.presence
- `lib/features/io/data/haptic_service_impl.dart` — Implemented presence() triple heartbeat
