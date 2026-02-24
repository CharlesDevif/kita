---
story_id: "12.1"
title: "KitaAgent interface, AgentBus, Clock et modeles"
epic: "E12 — Orchestrateur Multi-Agents"
phase: "3.5"
status: ready-for-dev
priority: critical
estimated_complexity: M
depends_on: []
blocks: ["12.2", "12.3", "12.4"]
---

# Story 12.1 : KitaAgent interface, AgentBus, Clock et modeles

## Story

As a **developpeur Kita**,
I want **les interfaces fondamentales du systeme multi-agents (KitaAgent, AgentBus, Clock) et tous les modeles associes**,
So that **les stories 12.2 (Supervisor + migration agents), 12.3 (OutputCoordinator) et 12.4 (InputRouter + facade) puissent etre implementees en parallele sur une base stable et testee**.

## Acceptance Criteria

1. **Given** le projet Kita avec le plugin system existant (E5) **When** `KitaAgent` est cree dans `lib/features/orchestration/domain/kita_agent.dart` **Then** c'est une abstract class avec :
   - un getter `AgentManifest get manifest`
   - un getter `List<VoiceCommand> get voiceCommands`
   - lifecycle complet : `Future<void> onSpawn(AgentContext context)`, `Future<void> onSuspend()`, `Future<void> onResume()`, `Future<void> onTerminate()`
   - `Future<Result<AgentOutput>> handleInput(AgentInput input)` pour recevoir des inputs routes
   - `void onBusMessage(AgentMessage message) {}` — opt-in avec default no-op
   - `Widget? buildViewport(BuildContext context)` pour le viewport Shell

2. **Given** `PluginManifest` existe dans `lib/features/plugins/domain/plugin_manifest.dart` **When** `AgentManifest` est cree dans `lib/features/orchestration/domain/models/agent_manifest.dart` **Then** il contient tous les champs de `PluginManifest` (id, name, version, description, trustLevel, permissions, capabilities, compatibleProfiles) **plus** :
   - `AgentType agentType` (enum : persistent, onDemand, background)
   - `AgentPriority priority` (enum : critical, high, standard, low)
   - `Set<AgentMessageType> subscriptions` — types de messages bus auxquels l'agent est abonne

3. **Given** les services existants (SensorAccess, AIAccess, MemoryAccess) **When** `AgentContext` est cree dans `lib/features/orchestration/domain/kita_agent.dart` (meme fichier que KitaAgent) **Then** il contient :
   - `SensorAccess sensors`
   - `AIAccess ai`
   - `MemoryAccess? memory` (null si pas de permission)
   - `AgentBus bus`
   - `OutputHandle output`
   - `Clock clock`

4. **Given** la necessite de communication inter-agents filtree **When** `AgentBus` (interface) est cree dans `lib/features/orchestration/domain/agent_bus.dart` et `AgentBusImpl` dans `lib/features/orchestration/data/agent_bus_impl.dart` **Then** :
   - L'interface expose `publish(AgentMessage)`, `subscribe(String agentId, Set<AgentMessageType> types)`, `unsubscribe(String agentId)`, `Stream<AgentMessage> streamFor(String agentId)`
   - `AgentBusImpl` utilise un `StreamController<AgentMessage>.broadcast()` interne
   - Un agent ne recoit que les messages dont le type est dans ses subscriptions
   - Les messages avec `toAgent` specifique ne sont livres qu'a cet agent (s'il est abonne au type)
   - Les messages sans `toAgent` sont livres a tous les abonnes du type

5. **Given** la necessite de messages inter-agents types **When** `AgentMessage` est cree dans `lib/features/orchestration/domain/models/agent_message.dart` **Then** il contient :
   - `String fromAgent` — ID de l'agent emetteur ("alert", "describe", "system")
   - `String? toAgent` — ID du destinataire (null = broadcast aux abonnes)
   - `AgentMessageType type` — type du message
   - `Map<String, dynamic> payload` — donnees associees
   - `DateTime timestamp` — horodatage du message

6. **Given** les besoins de la spec **When** `AgentMessageType` enum est cree dans `agent_message.dart` **Then** il couvre :
   - Lifecycle : `agentSpawned`, `agentTerminated`
   - Interruption : `interruptRequest`, `interruptAck`
   - Data sharing : `contextUpdate`, `detectionEvent`, `descriptionComplete`
   - User intent : `cancelAll`, `userCommand`

7. **Given** `PluginRequest` existe dans le plugin system **When** `AgentInput` est cree dans `lib/features/orchestration/domain/models/agent_input.dart` **Then** il contient :
   - `String command` — commande recue ("describe", "alert", "stop")
   - `Map<String, dynamic> params` — parametres associes
   - `InputSource source` — enum : voice, text, sensor, system
   - `DateTime timestamp`

8. **Given** `PluginResponse` existe dans le plugin system **When** `AgentOutput` est cree dans `lib/features/orchestration/domain/models/agent_output.dart` **Then** il contient :
   - `AgentOutputType type` — enum : text, image, alert, rich, empty
   - `String content` — contenu de la reponse
   - `Map<String, dynamic>? metadata` — metadonnees optionnelles

9. **Given** les agents ne doivent jamais appeler TTS/Haptic directement **When** `OutputHandle` est cree dans `lib/features/orchestration/domain/output_handle.dart` **Then** c'est une abstract class avec :
   - `String get agentId`
   - `Future<void> speak(String text, {OutputPriority priority = OutputPriority.standard})`
   - `Future<void> haptic(HapticPattern pattern, {OutputPriority priority = OutputPriority.standard})`
   - `void updateViewport(Widget widget)`
   - `Stream<SpeechEvent> get speechEvents`
   - `void complete()`
   - Et `SpeechEvent` enum : `started`, `completed`, `interrupted`

10. **Given** le besoin de tests deterministes pour les timers **When** `Clock` est cree dans `lib/features/orchestration/domain/clock.dart` **Then** :
    - `Clock` abstract class avec : `DateTime now()`, `Timer periodic(Duration, void Function(Timer))`, `Timer delayed(Duration, void Function())`, `Future<void> wait(Duration)`
    - `SystemClock implements Clock` — utilise `DateTime.now()` et `dart:async` `Timer` en prod
    - `FakeClock implements Clock` — avance le temps manuellement : `void advance(Duration)`, expose `DateTime get currentTime`
    - `FakeClock.wait()` complete immediatement (synchrone) quand `advance()` est appele
    - `FakeClock.periodic()` et `delayed()` stockent les callbacks et les executent quand `advance()` depasse leur echeance

11. **Given** la spec definit des niveaux de priorite output **When** `OutputPriority` est cree dans `lib/features/orchestration/domain/models/output_priority.dart` **Then** l'enum contient dans l'ordre : `cancel`, `critical`, `high`, `standard`, `low`

12. **Given** `AgentBusImpl` et `FakeClock` sont des composants testables **When** les tests unitaires sont ecrits **Then** :
    - `AgentBusImpl` : test subscription, test filtrage par type, test unsubscribe supprime la reception, test toAgent filtre le destinataire, test broadcast (toAgent null) distribue a tous les abonnes du type
    - `FakeClock` : test `now()` retourne l'heure initiale, test `advance()` avance l'heure, test `delayed()` execute le callback quand le temps est atteint, test `periodic()` execute N fois quand le temps couvre N periodes, test `wait()` complete quand advance depasse la duree

13. **Given** `KitaPlugin` est l'interface existante dans `lib/features/plugins/domain/kita_plugin.dart` **When** le fichier est modifie **Then** la classe est annotee `@Deprecated('Use KitaAgent from lib/features/orchestration/domain/kita_agent.dart instead')` — le corps de la classe reste inchange pour la retrocompatibilite temporaire

14. **Given** les conventions Kita **When** tous les fichiers sont crees **Then** :
    - Fichiers en `snake_case`
    - Classes en `UpperCamelCase`
    - Variables en `lowerCamelCase`
    - `Result<T>` utilise pour `handleInput` (pas de throw non type)
    - Imports respectent Clean Architecture (domain/ n'importe jamais data/)
    - Logs au format `[Source] Message`, zero PII

## Technical Intelligence

### Dart Streams — Broadcast pour le Bus

Le `AgentBus` utilise un `StreamController<AgentMessage>.broadcast()` comme backbone. Les raisons :

- **Multiple listeners** : Plusieurs agents ecoutent simultanement le meme stream. Un `StreamController` standard (single-subscription) ne le permet pas — il lance une `StateError` au deuxieme `listen()`.
- **Pas de buffering** : Les messages broadcast ne sont pas bufferises. Si un agent n'est pas encore abonne quand un message est publie, il le rate. C'est le comportement voulu : un agent recoit uniquement les messages emis apres son `subscribe()`.
- **Filtrage cote consommateur** : Chaque agent recoit le stream filtre via `.where()` sur le `AgentMessageType` et le `toAgent`. Ce filtrage est performant car Dart `Stream.where()` est lazy — les events non-matchers ne declenchent pas de processing.

**Pattern d'implementation recommande :**

```dart
class AgentBusImpl implements AgentBus {
  final _controller = StreamController<AgentMessage>.broadcast();
  final Map<String, Set<AgentMessageType>> _subscriptions = {};

  @override
  void publish(AgentMessage message) {
    _controller.add(message);
  }

  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {
    _subscriptions[agentId] = types;
  }

  @override
  void unsubscribe(String agentId) {
    _subscriptions.remove(agentId);
  }

  @override
  Stream<AgentMessage> streamFor(String agentId) {
    return _controller.stream.where((msg) {
      // Agent doit etre abonne au type
      final subs = _subscriptions[agentId];
      if (subs == null || !subs.contains(msg.type)) return false;
      // Si toAgent specifie, ne livrer qu'au destinataire
      if (msg.toAgent != null && msg.toAgent != agentId) return false;
      return true;
    });
  }

  void dispose() {
    _controller.close();
  }
}
```

**Attention** : Ne PAS utiliser `asBroadcastStream()` sur un single-subscription controller — cela transfère la gestion du lifecycle et peut causer des fuites memoire si les listeners ne cancel pas correctement. Utiliser directement `StreamController.broadcast()`.

**Reference** : La documentation officielle Dart confirme ce pattern. Voir aussi le package `rxdart` si on veut des operateurs plus avances (`.combineLatest`, `.debounce`), mais pour le MVP le `Stream.where()` natif suffit.

### Clock injectable — Package `clock` vs custom

**Decision : Clock custom (pas le package `clock`).**

Le package `clock` (v1.1.2, pub.dev, par `tools.dart.dev`) fournit un `Clock` avec `now()` et des methodes de calcul temporel (`daysAgo`, `hoursFromNow`, etc.), plus un mecanisme `withClock()` pour swapper l'horloge globale. Cependant :

1. **Il ne fournit PAS `periodic()`, `delayed()`, ni `wait()`** — or la spec Kita en a besoin pour les timers (cooldowns, timeouts, silence timer).
2. **Son mecanisme `withClock()` est zone-based** — fonctionne bien pour les tests simples mais mal avec les Isolates et les `StreamController.broadcast()`.
3. **Le package `fake_async` (v1.3.3)** fournit `FakeAsync.elapse()` qui avance les `Timer` et les `Future.delayed`, mais impose un wrapper `fakeAsync((async) { ... })` autour du code test entier. Cela ne s'integre pas naturellement avec notre pattern d'injection Riverpod.

**Conclusion** : On cree notre propre `Clock` abstrait avec exactement les 4 methodes dont on a besoin (`now`, `periodic`, `delayed`, `wait`), et un `FakeClock` maison qui avance le temps manuellement. C'est plus simple, plus explicite, et testable sans zone tricks.

**Implementation FakeClock recommandee :**

```dart
class FakeClock implements Clock {
  FakeClock({DateTime? initialTime})
      : _currentTime = initialTime ?? DateTime(2026, 1, 1);

  DateTime _currentTime;
  final List<_PendingTimer> _pendingTimers = [];
  final List<_PendingWait> _pendingWaits = [];

  DateTime get currentTime => _currentTime;

  @override
  DateTime now() => _currentTime;

  @override
  Timer periodic(Duration duration, void Function(Timer) callback) {
    final timer = _FakePeriodicTimer(duration, callback);
    _pendingTimers.add(_PendingTimer(
      fireAt: _currentTime.add(duration),
      timer: timer,
    ));
    return timer;
  }

  @override
  Timer delayed(Duration duration, void Function() callback) {
    final timer = _FakeDelayedTimer(callback);
    _pendingTimers.add(_PendingTimer(
      fireAt: _currentTime.add(duration),
      timer: timer,
      callback: callback,
    ));
    return timer;
  }

  @override
  Future<void> wait(Duration duration) {
    final completer = Completer<void>();
    _pendingWaits.add(_PendingWait(
      completeAt: _currentTime.add(duration),
      completer: completer,
    ));
    return completer.future;
  }

  /// Avance le temps et execute les timers/waits echus.
  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
    _firePendingTimers();
    _completePendingWaits();
  }
}
```

### Sealed classes et enums Dart 3

Les enums Dart 3 supportent des champs, des methodes, et des constructeurs `const`. On les utilise pour `AgentMessageType`, `OutputPriority`, `AgentType`, `AgentPriority`, `InputSource`, `SpeechEvent`, et `AgentOutputType`.

**Enhanced enums pattern** (recommande pour `OutputPriority` et `AgentPriority`) :

```dart
enum OutputPriority implements Comparable<OutputPriority> {
  cancel(0),
  critical(1),
  high(2),
  standard(3),
  low(4);

  const OutputPriority(this.level);
  final int level;

  /// Plus le level est bas, plus la priorite est haute.
  bool operator >(OutputPriority other) => level < other.level;
  bool operator <(OutputPriority other) => level > other.level;

  @override
  int compareTo(OutputPriority other) => level.compareTo(other.level);
}
```

Ce pattern permet la comparaison directe de priorites dans l'`OutputCoordinator` (story 12.3).

Pour `AgentType`, on n'a pas besoin de comparaison, un simple enum suffit :

```dart
enum AgentType { persistent, onDemand, background }
```

### Actor Model inspiration

Le systeme multi-agents de Kita n'est pas un actor model pur (pas d'Isolates par agent — trop lourd pour mobile), mais il s'en inspire :

- **Mailbox** : `AgentBus` + `streamFor(agentId)` = chaque agent a sa "boite aux lettres" filtree
- **Message-driven** : Communication exclusivement par messages types (`AgentMessage`)
- **Encapsulation** : L'agent ne peut pas acceder aux internals d'un autre agent — il passe par le bus
- **Lifecycle superviseur** : `AgentSupervisor` gere spawn/terminate comme un supervisor Erlang (story 12.2)

La difference : tous les agents vivent dans le meme Isolate (main Isolate Flutter) pour l'acces aux widgets. La concurrence est cooperative (async/await), pas preemptive.

## Pitfalls & Gotchas

### 1. StreamController.broadcast() ne bufferise pas

Si un message est publie AVANT qu'un agent appelle `streamFor()` et `listen()`, le message est perdu. **Solution** : L'`AgentSupervisor` (story 12.2) doit TOUJOURS appeler `bus.subscribe()` + demarrer le listener AVANT d'appeler `agent.onSpawn()`. L'ordre dans `AgentSupervisor.spawn()` sera :

```
1. bus.subscribe(agentId, manifest.subscriptions)
2. listener = bus.streamFor(agentId).listen(agent.onBusMessage)
3. agent.onSpawn(context)
```

Ceci est un contrat que l'`AgentSupervisor` (story 12.2) doit respecter — le documenter dans l'interface `AgentBus` comme commentaire.

### 2. FakeClock et async tests

Le `FakeClock.advance()` execute les callbacks de facon synchrone. Si un callback lance une `Future` asynchrone, cette future ne sera pas complete a la sortie de `advance()`. **Solution** : Les tests qui utilisent `FakeClock.advance()` doivent faire un `await Future.microtask(() {})` apres l'advance pour permettre aux microtasks d'etre flush. Documenter ce pattern dans les commentaires de `FakeClock`.

```dart
fakeClock.advance(const Duration(seconds: 5));
await Future.microtask(() {}); // flush microtasks
expect(callbackExecuted, isTrue);
```

### 3. Timer.cancel() sur FakeClock

Les timers retournes par `FakeClock.periodic()` et `delayed()` doivent supporter `cancel()`. Si un agent annule son timer (ex: DescribeAgent annule le silence timer quand il recoit interruptRequest), le `FakeClock` ne doit pas executer le callback. Implementer un flag `_isCancelled` sur les fake timers.

### 4. AgentManifest ne doit PAS heriter de PluginManifest

Meme si `AgentManifest` contient les memes champs que `PluginManifest`, il ne doit PAS en heriter (`extends` ou `implements`). Raisons :
- `PluginManifest` est dans `features/plugins/domain/` — l'importer depuis `features/orchestration/domain/` creerait une dependance cross-feature sur `data/` indirectement (via les types utilises par PluginManifest)
- La spec dit "extends PluginManifest concepts", pas "extends PluginManifest class"
- On peut prevoir un `toPluginManifest()` sur `AgentManifest` pour la retrocompatibilite temporaire si necessaire (migration story 12.2)

**Exception** : On importe `TrustLevel` depuis `features/plugins/domain/trust_level.dart` car c'est un enum simple sans dependance.

### 5. Import de VoiceCommand

`VoiceCommand` existe dans `features/plugins/domain/voice_command.dart`. Comme c'est un modele domain simple sans dependance, on l'importe directement dans `kita_agent.dart`. C'est un import cross-feature autorise (domain/ vers domain/).

### 6. OutputHandle est abstract dans cette story

`OutputHandle` est defini comme abstract class dans cette story. L'implementation concrete sera creee dans story 12.3 (`OutputCoordinator`) qui injectera la reference au coordinator. Ne PAS creer d'implementation concrete ici.

### 7. HapticPattern reference

`OutputHandle.haptic()` prend un `HapticPattern` en parametre. Ce type existe dans `lib/features/io/domain/haptic_service.dart`. C'est un import cross-feature autorise (domain/ vers domain/). NE PAS re-declarer le type.

### 8. AgentBusImpl.dispose() et cleanup

`AgentBusImpl` doit exposer une methode `dispose()` qui appelle `_controller.close()`. Sans cela, le StreamController leak en memoire. Le `KitaOrchestrator` (story 12.4) appellera `dispose()` dans sa propre methode `dispose()`.

## Implementation Tasks

### Task 1 : Creer les enums et modeles simples (AC: #6, #7, #8, #11)

- [ ] Creer `lib/features/orchestration/domain/models/output_priority.dart`
  - Enum `OutputPriority` avec `cancel`, `critical`, `high`, `standard`, `low`
  - Implementer `Comparable<OutputPriority>` avec un champ `level` int
  - Operateurs `>` et `<` pour comparaison de priorite

- [ ] Creer `lib/features/orchestration/domain/models/agent_message.dart`
  - Enum `AgentMessageType` avec les 9 valeurs specifiees (AC6)
  - Classe `AgentMessage` avec les 5 champs specifies (AC5)
  - Constructeur `const` avec `required` sur `fromAgent`, `type`, `payload`, `timestamp`
  - `toAgent` optionnel (nullable)

- [ ] Creer `lib/features/orchestration/domain/models/agent_input.dart`
  - Enum `InputSource` avec `voice`, `text`, `sensor`, `system`
  - Classe `AgentInput` avec `command`, `params`, `source`, `timestamp`
  - Constructeur `const`

- [ ] Creer `lib/features/orchestration/domain/models/agent_output.dart`
  - Enum `AgentOutputType` avec `text`, `image`, `alert`, `rich`, `empty`
  - Classe `AgentOutput` avec `type`, `content`, `metadata`
  - Constructeur `const`

### Task 2 : Creer AgentManifest (AC: #2)

- [ ] Creer `lib/features/orchestration/domain/models/agent_manifest.dart`
  - Enum `AgentType` avec `persistent`, `onDemand`, `background`
  - Enum `AgentPriority` avec `critical`, `high`, `standard`, `low` — implementer `Comparable`
  - Classe `AgentManifest` avec tous les champs PluginManifest + les 3 nouveaux
  - Importer `TrustLevel` depuis `plugins/domain/trust_level.dart`
  - Importer `AgentMessageType` depuis le fichier agent_message.dart local
  - Constructeur `const` avec parametres nommes

### Task 3 : Creer OutputHandle et SpeechEvent (AC: #9)

- [ ] Creer `lib/features/orchestration/domain/output_handle.dart`
  - Enum `SpeechEvent` avec `started`, `completed`, `interrupted`
  - Abstract class `OutputHandle` avec les 6 methodes/getters specifies (AC9)
  - Importer `OutputPriority` et `HapticPattern` (de io/domain/)
  - Importer `Widget` et `BuildContext` de Flutter

### Task 4 : Creer Clock, SystemClock, FakeClock (AC: #10)

- [ ] Creer `lib/features/orchestration/domain/clock.dart`
  - Abstract class `Clock` avec `now()`, `periodic()`, `delayed()`, `wait()`
  - `SystemClock implements Clock` — delegation a `DateTime.now()`, `Timer.periodic()`, `Timer()`, `Future.delayed()`
  - `FakeClock implements Clock` dans le meme fichier — ou dans un fichier separe si trop long

- [ ] Si `FakeClock` est long, le separer dans `test/helpers/fake_clock.dart`
  - Mais la spec dit `clock.dart` dans domain/ — donc garder `FakeClock` dans `lib/features/orchestration/domain/clock.dart` pour que les stories 12.2/12.3/12.4 puissent l'utiliser dans leurs tests sans import circulaire
  - Classes internes `_PendingTimer`, `_PendingWait`, `_FakePeriodicTimer`, `_FakeDelayedTimer` (privees)

### Task 5 : Creer KitaAgent et AgentContext (AC: #1, #3)

- [ ] Creer `lib/features/orchestration/domain/kita_agent.dart`
  - Import `AgentManifest`, `AgentMessage`, `AgentInput`, `AgentOutput`, `OutputHandle`, `Clock`
  - Import `VoiceCommand` depuis plugins/domain/
  - Import `SensorAccess`, `AIAccess`, `MemoryAccess` depuis plugins/domain/
  - Import `AgentBus` (local)
  - Classe `AgentContext` avec les 6 champs (const constructor)
  - Abstract class `KitaAgent` avec l'API complete specifiee (AC1)
  - `onBusMessage` avec body `{}` (no-op default)

### Task 6 : Creer AgentBus interface + AgentBusImpl (AC: #4)

- [ ] Creer `lib/features/orchestration/domain/agent_bus.dart`
  - Abstract class `AgentBus` avec `publish()`, `subscribe()`, `unsubscribe()`, `streamFor()`
  - Documenter le contrat : subscribe AVANT onSpawn

- [ ] Creer `lib/features/orchestration/data/agent_bus_impl.dart`
  - `AgentBusImpl implements AgentBus`
  - `StreamController<AgentMessage>.broadcast()` interne
  - Map `_subscriptions` pour le filtrage
  - Methode `dispose()` pour fermer le controller
  - Logique de filtrage dans `streamFor()` : subscription check + toAgent check

### Task 7 : Deprecer KitaPlugin (AC: #13)

- [ ] Modifier `lib/features/plugins/domain/kita_plugin.dart`
  - Ajouter `@Deprecated('Use KitaAgent from lib/features/orchestration/domain/kita_agent.dart instead')` au-dessus de la classe
  - Ne PAS modifier le corps de la classe (retrocompatibilite pour stories existantes)

### Task 8 : Tests unitaires (AC: #12)

- [ ] Creer `test/features/orchestration/data/agent_bus_impl_test.dart`
  - Test : publish un message de type `detectionEvent` → seul l'agent abonne a `detectionEvent` le recoit
  - Test : publish un message de type `cancelAll` → les 2 agents abonnes a `cancelAll` le recoivent
  - Test : publish un message avec `toAgent: "describe"` → seul "describe" le recoit, pas les autres abonnes
  - Test : unsubscribe → l'agent ne recoit plus rien apres unsubscribe
  - Test : agent non abonne a un type ne recoit pas les messages de ce type
  - Test : dispose() ferme le stream sans erreur

- [ ] Creer `test/features/orchestration/domain/clock_test.dart`
  - Test : `FakeClock.now()` retourne l'heure initiale
  - Test : `FakeClock.advance(Duration(seconds: 5))` → `now()` retourne +5s
  - Test : `FakeClock.delayed(Duration(seconds: 3), callback)` → callback execute apres `advance(3s)`
  - Test : `FakeClock.delayed(Duration(seconds: 3), callback)` → callback PAS execute apres `advance(2s)`
  - Test : `FakeClock.periodic(Duration(seconds: 1), callback)` → callback execute 3 fois apres `advance(3s)`
  - Test : `FakeClock.wait(Duration(seconds: 2))` → future completee apres `advance(2s)`
  - Test : timer cancel → callback PAS execute meme apres advance suffisant
  - Test : `SystemClock.now()` retourne une DateTime proche de `DateTime.now()` (test de sanite)

## Files to Create/Modify

| Fichier | Action | Description |
|---------|--------|-------------|
| `lib/features/orchestration/domain/models/output_priority.dart` | Creer | Enum `OutputPriority` (cancel, critical, high, standard, low) avec `Comparable` |
| `lib/features/orchestration/domain/models/agent_message.dart` | Creer | Enum `AgentMessageType` (9 valeurs) + classe `AgentMessage` |
| `lib/features/orchestration/domain/models/agent_input.dart` | Creer | Enum `InputSource` (4 valeurs) + classe `AgentInput` |
| `lib/features/orchestration/domain/models/agent_output.dart` | Creer | Enum `AgentOutputType` (5 valeurs) + classe `AgentOutput` |
| `lib/features/orchestration/domain/models/agent_manifest.dart` | Creer | Enums `AgentType`, `AgentPriority` + classe `AgentManifest` |
| `lib/features/orchestration/domain/output_handle.dart` | Creer | Enum `SpeechEvent` + abstract class `OutputHandle` |
| `lib/features/orchestration/domain/clock.dart` | Creer | Abstract `Clock` + `SystemClock` + `FakeClock` |
| `lib/features/orchestration/domain/kita_agent.dart` | Creer | Classes `AgentContext` + abstract `KitaAgent` |
| `lib/features/orchestration/domain/agent_bus.dart` | Creer | Abstract class `AgentBus` (interface) |
| `lib/features/orchestration/data/agent_bus_impl.dart` | Creer | `AgentBusImpl` avec StreamController broadcast + filtrage |
| `lib/features/plugins/domain/kita_plugin.dart` | Modifier | Ajouter `@Deprecated` sur la classe KitaPlugin |
| `test/features/orchestration/data/agent_bus_impl_test.dart` | Creer | 6+ tests unitaires AgentBusImpl |
| `test/features/orchestration/domain/clock_test.dart` | Creer | 8+ tests unitaires FakeClock + SystemClock |

## Dependencies

### Fichiers existants utilises (imports)

| Fichier | Ce qu'on importe | Pourquoi |
|---------|-----------------|----------|
| `lib/core/errors/result.dart` | `Result<T>` | Retour de `handleInput` |
| `lib/core/errors/kita_failure.dart` | `KitaFailure` | Type d'erreur dans Result |
| `lib/features/plugins/domain/trust_level.dart` | `TrustLevel` enum | Champ dans AgentManifest |
| `lib/features/plugins/domain/voice_command.dart` | `VoiceCommand` class | Getter dans KitaAgent |
| `lib/features/plugins/domain/sensor_access.dart` | `SensorAccess` interface | Champ dans AgentContext |
| `lib/features/plugins/domain/ai_access.dart` | `AIAccess` interface | Champ dans AgentContext |
| `lib/features/plugins/domain/memory_access.dart` | `MemoryAccess` interface | Champ dans AgentContext |
| `lib/features/io/domain/haptic_service.dart` | `HapticPattern` enum | Parametre de OutputHandle.haptic() |
| `package:flutter/widgets.dart` | `Widget`, `BuildContext` | buildViewport, updateViewport |

### Stories pre-requises

| Story | Statut | Ce qu'elle fournit |
|-------|--------|-------------------|
| 1.1 (Init projet) | Done | Structure de base, pubspec.yaml |
| 1.2 (Core patterns) | Done | KitaFailure, Result<T>, Logger |
| 1.7 (Interfaces domain) | Done | SensorAccess, AIAccess, MemoryAccess, PluginManifest, KitaPlugin, VoiceCommand |

### Aucune dependance pubspec.yaml a ajouter

Cette story n'a besoin d'aucun nouveau package. Tout est implemente avec les APIs Dart standard (`dart:async` pour Stream/Timer/Completer, `package:flutter/widgets.dart` pour Widget/BuildContext).

## Definition of Done

- [ ] Tous les 10 fichiers dans `lib/features/orchestration/` sont crees et compilent sans erreur
- [ ] `KitaPlugin` est annote `@Deprecated` avec un message clair
- [ ] `dart analyze` retourne zero erreur/warning sur les fichiers crees
- [ ] Les tests AgentBusImpl (6+ tests) passent tous au vert
- [ ] Les tests FakeClock (8+ tests) passent tous au vert
- [ ] `flutter test test/features/orchestration/` passe a 100%
- [ ] Aucun import de `data/` depuis `domain/` (Clean Architecture respectee)
- [ ] Aucun import circulaire entre `orchestration/` et `plugins/` (seulement des imports de `plugins/domain/` types simples)
- [ ] Les commentaires doc (///) sont presents sur chaque classe et methode publique
- [ ] Le format `[Source] Message` est utilise dans tout logging eventuel
- [ ] Sprint status mis a jour dans `_bmad-output/implementation-artifacts/sprint-status.yaml`
