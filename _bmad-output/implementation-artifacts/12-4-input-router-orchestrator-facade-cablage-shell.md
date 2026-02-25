---
story_id: "12.4"
title: "InputRouter + KitaOrchestrator facade + cablage Shell + tests E2E"
epic: "E12 — Orchestrateur Multi-Agents"
phase: "3.5"
status: done
priority: critical
estimated_complexity: XL
depends_on: ["12.2", "12.3"]
---

# Story 12.4 : InputRouter + KitaOrchestrator facade + cablage Shell + tests E2E

## User Story

**En tant que** Marie (persona MVP, aveugle de naissance, utilisatrice VoiceOver),
**je veux** pouvoir parler ou ecrire a Kita et que ma commande soit automatiquement classifiee et routee vers le bon agent (description, alerte, conversation generale, ou annulation),
**afin que** Kita reagisse instantanement a mes besoins sans que j'aie a comprendre son architecture interne.

## Description

C'est la story de cloture de l'Epic 12. Elle connecte tout : l'InputRouter classifie et route les inputs bruts, le KitaOrchestrator sert de facade unique pour le Shell, et le cablage Shell relie les callbacks KitaInput aux handlers de l'orchestrateur. Les 3 tests E2E valident les scenarios de reference de la spec (Marie decrit, interruption obstacle, stop total).

**Depend de :**
- **Story 12.2** : AgentSupervisor + migration des plugins vers KitaAgent (DescribeAgent, AlertAgent)
- **Story 12.3** : OutputCoordinator (arbitrage TTS/haptic/visual, cooldown, interruptions, presence haptique)

**Prerequis disponibles (stories anterieures) :**
- `VoiceCommandHandler` (Story 3.7) — reconnaissance commandes vocales francaises
- `RequestClassifier` (Story 2.1) — classification priorite des requetes
- `STTService` (Story 3.2) — speech-to-text
- `KitaShell`, `KitaInput`, `ShellModeNotifier`, `OrbStateNotifier` (Epic 8) — Shell UI
- `KitaAgent`, `AgentBus`, `Clock` (Story 12.1) — interfaces et modeles domain
- `AgentSupervisor` (Story 12.2) — lifecycle agents
- `OutputCoordinator`, `OutputHandle` (Story 12.3) — arbitrage output

## Acceptance Criteria

### AC1 : Classification et routage InputRouter
**Given** un `RawInput` arrive dans `InputRouter.route()`
**When** le transcript contient "stop" ou "annule"
**Then** le router publie `cancelAll` sur le bus, appelle `outputCoordinator.cancelAll()`, et produit un feedback "OK"

### AC2 : Utilisation de VoiceCommandHandler
**Given** un `RawInput` de type `voice` ou `text` avec un transcript
**When** `InputRouter.route()` traite l'input
**Then** il appelle `VoiceCommandHandler.recognize(transcript)` pour identifier les commandes vocales connues

### AC3 : Utilisation de RequestClassifier
**Given** un `RawInput` avec un transcript qui ne correspond a aucune commande vocale connue
**When** `InputRouter.route()` le traite
**Then** il utilise `RequestClassifier.classify(transcript)` pour determiner la priorite avant de router vers AIRouter

### AC4 : Point d'entree unique KitaOrchestrator
**Given** un input quelconque (texte, voix, capteur)
**When** `KitaOrchestrator.handleInput(RawInput)` est appele
**Then** il delegue a `InputRouter.route()` sans logique supplementaire

### AC5 : Initialisation KitaOrchestrator
**Given** l'onboarding est termine
**When** `KitaOrchestrator.initialize()` est appele
**Then** les agents persistent (AlertAgent) sont spawnes via `AgentSupervisor.spawn()`

### AC6 : Dispose propre KitaOrchestrator
**Given** l'application se ferme ou un reset est demande
**When** `KitaOrchestrator.dispose()` est appele
**Then** tous les agents (persistent et onDemand) sont termines proprement via le Supervisor

### AC7 : Cablage Shell — onTextSubmit
**Given** le KitaShell est affiche avec un KitaInput connecte
**When** l'utilisateur soumet du texte via KitaInput.onTextSubmit
**Then** le texte est transforme en `RawInput.text(transcript)` et envoye a `orchestrator.handleInput()`

### AC8 : Cablage Shell — onMicPressed
**Given** le KitaShell est affiche avec un KitaInput connecte
**When** l'utilisateur appuie sur le bouton micro
**Then** le STT demarre, et a la fin de la reconnaissance, le transcript est transforme en `RawInput.voice(transcript)` et envoye a `orchestrator.handleInput()`

### AC9 : Cablage Shell — ShellModeNotifier
**Given** le Shell observe l'etat du Supervisor
**When** `supervisor.hasActiveOnDemand` passe de `true` a `false` (plus aucun agent onDemand actif)
**Then** `ShellModeNotifier` bascule sur `ShellMode.passive`
**And** quand un agent onDemand est spawne, `ShellModeNotifier` bascule sur `ShellMode.active`

### AC10 : Cablage Shell — OrbStateNotifier
**Given** le Shell observe l'etat de l'OutputCoordinator
**When** le coordinator change d'etat (idle, speaking, processing)
**Then** `OrbStateNotifier` est mis a jour : processing pendant le traitement AI, responding pendant le TTS, passive quand tout est silent

### AC11 : Cablage Shell — Viewport agent au focus
**Given** un agent a le focus (dernier a avoir produit un output)
**When** cet agent appelle `output.updateViewport(widget)`
**Then** le `PluginViewport.child` dans le Shell affiche ce widget

### AC12 : Providers Riverpod keepAlive
**Given** les providers de l'orchestration sont declares
**When** le ProviderScope est initialise
**Then** `kitaOrchestratorProvider`, `inputRouterProvider`, `agentSupervisorProvider`, `outputCoordinatorProvider`, `agentBusProvider` sont tous `keepAlive: true`

### AC13 : Test E2E "Marie decrit"
**Given** le systeme est initialise (AlertAgent persistent actif)
**When** Marie dit "decris"
**Then** le flow complet s'execute : InputRouter route vers spawn DescribeAgent → capture photo (mock) → AI vision (mock) → OutputCoordinator TTS (mock) → speechComplete → silence 5s (FakeClock) → output.complete() → Supervisor.terminate(describe) → Shell mode PASSIVE

### AC14 : Test E2E "Interruption obstacle"
**Given** DescribeAgent est en train de parler (TTS actif)
**When** un obstacle est detecte a 2m (sensor event)
**Then** AlertAgent recoit l'input → OutputCoordinator stoppe le TTS → alerte CRITICAL → interruptRequest publie sur le bus → DescribeAgent termine → haptic presence 2s apres (FakeClock) → Shell mode PASSIVE

### AC15 : Test E2E "Stop total"
**Given** 2 agents sont actifs (AlertAgent persistent + DescribeAgent onDemand)
**When** Marie dit "stop"
**Then** cancelAll broadcast → DescribeAgent termine (onDemand), AlertAgent reste (persistent) → queue output videe → feedback "OK" → Shell mode PASSIVE

### AC16 : Zero dependance hardware dans les tests
**Given** les 3 tests E2E
**When** ils s'executent
**Then** tous utilisent FakeClock pour le temps, mocks pour TTS/Camera/AI/Haptic — aucune dependance materielle

## Technical Intelligence

### Riverpod 3.0 — keepAlive pour facade singleton

En Riverpod 3.0, `@Riverpod(keepAlive: true)` empeche le provider d'etre dispose quand il n'est plus ecoute. C'est le pattern exact pour l'orchestrateur et ses composants internes.

**Pattern pour le KitaOrchestrator :**

```dart
@Riverpod(keepAlive: true)
KitaOrchestrator kitaOrchestrator(Ref ref) {
  final router = ref.watch(inputRouterProvider);
  final supervisor = ref.watch(agentSupervisorProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final bus = ref.watch(agentBusProvider);

  final orchestrator = KitaOrchestrator(
    inputRouter: router,
    supervisor: supervisor,
    outputCoordinator: coordinator,
    bus: bus,
  );

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
}
```

**Composition de providers :** chaque sous-composant est son propre provider keepAlive, et le provider facade les compose via `ref.watch()`. En Riverpod 3.0, les interfaces `AutoDispose` sont unifiees — on utilise les interfaces core (`Provider`, `Notifier`) directement. `StateProvider` et `StateNotifierProvider` sont dans `legacy.dart` — NE PAS les utiliser.

**Important Riverpod 3.0 :**
- Le code generator (`riverpod_generator`) est la methode recommandee
- `Notifier` remplace `StateNotifier` pour l'etat synchrone
- `AsyncNotifier` pour l'etat asynchrone
- `ref.state` et `ref.listenSelf` ont ete deplaces dans la classe Notifier

### Widget Testing avec Riverpod — ProviderScope.overrides

Pour les tests widget et E2E, on utilise `ProviderScope(overrides: [...])` pour injecter des mocks :

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      kitaOrchestratorProvider.overrideWith((ref) => mockOrchestrator),
      agentSupervisorProvider.overrideWith((ref) => mockSupervisor),
      outputCoordinatorProvider.overrideWith((ref) => mockCoordinator),
    ],
    child: const MaterialApp(home: KitaShell(...)),
  ),
);
```

Chaque test widget cree son propre `ProviderScope` isole — les tests ne partagent jamais d'etat entre eux.

### FakeAsync + Clock injectable — tests deterministes

Le package `fake_async` (inclus dans flutter_test) fournit `FakeAsync` pour controler le temps. Notre `Clock` abstrait (Story 12.1) s'integre parfaitement :

**Pattern pour les tests E2E :**

```dart
test('Marie decrit — flow complet', () {
  fakeAsync((async) {
    // Setup mocks + FakeClock
    final fakeClock = FakeClock();
    final container = ProviderContainer(overrides: [...]);
    final orchestrator = container.read(kitaOrchestratorProvider);

    // Step 1: Input "decris"
    await orchestrator.handleInput(RawInput.voice('decris'));
    async.flushMicrotasks();

    // Step 2: DescribeAgent capture + AI (mocks resolvent immediatement)
    async.flushMicrotasks();

    // Step 3: TTS parle (mock)
    async.flushMicrotasks();

    // Step 4: speechComplete
    // ... simulate speech complete event

    // Step 5: Silence 5s
    async.elapse(const Duration(seconds: 5));

    // Step 6: Verify terminate + Shell passive
    expect(supervisor.agents, isEmpty); // onDemand terminated
    expect(shellMode, ShellMode.passive);
  });
});
```

**Cle :** `async.elapse(Duration)` avance le temps deterministe. `async.flushMicrotasks()` execute les microtasks en attente. Les timers crees dans la zone FakeAsync sont geres automatiquement.

Le `FakeClock` (Story 12.1) expose `advance(Duration)` pour faire avancer le temps dans nos composants. En test, on l'injecte via les providers overrides.

### Cablage Shell — pattern ref.listen pour side effects

Le Shell doit reagir aux changements d'etat du Supervisor et du Coordinator. Riverpod recommande `ref.listen()` pour les side effects (pas `ref.watch()` qui est pour le rebuild) :

```dart
// Dans un ConsumerStatefulWidget ou via un provider intermediaire :
ref.listen(supervisorHasActiveOnDemandProvider, (prev, next) {
  if (next == true) {
    ref.read(shellModeNotifierProvider.notifier).activate();
  } else {
    ref.read(shellModeNotifierProvider.notifier).deactivate();
  }
});
```

Mais pour le Shell widget lui-meme, `ref.watch()` est correct car on veut un rebuild quand le mode change.

### Integration STT → Orchestrator

Le flow STT → InputRouter :
1. `KitaInput.onMicPressed` → demarre `STTService.startRecognition()`
2. STT produit des transcripts intermediaires (affiches dans KitaInput)
3. STT produit un transcript final (`isFinal: true`)
4. Transcript final → `RawInput.voice(transcript)` → `orchestrator.handleInput()`

Le Shell gere le lifecycle STT. L'orchestrateur ne connait pas le STT directement.

## Pitfalls & Gotchas

### 1. Race condition : double "decris" rapide

Si Marie dit "decris" alors qu'un DescribeAgent est deja actif, l'InputRouter doit detecter l'agent existant via `supervisor.agents` et re-router la commande vers l'agent actif (pas de double spawn). Verifier `supervisor.agents.containsKey('com.kita.describe')` avant spawn.

### 2. Timing du cancelAll

Le `cancelAll` doit etre **synchrone** sur le bus AVANT l'appel a `outputCoordinator.cancelAll()`. Raison : les agents recoivent le message et commencent leur cleanup AVANT que le coordinator coupe le TTS. Sinon, un agent pourrait enqueue un dernier speech pendant que le coordinator vide la queue.

Sequence correcte :
1. `bus.publish(AgentMessage(type: cancelAll))`
2. `await outputCoordinator.cancelAll()`
3. feedback "OK"

### 3. FakeClock vs fakeAsync — deux mecanismes de temps

Notre `FakeClock` (Story 12.1) et le `fakeAsync` de Flutter sont deux choses differentes :
- `fakeAsync` controle les `Timer` et `Future.delayed` du dart runtime
- Notre `FakeClock` controle les appels a `clock.now()` et `clock.delayed()` dans nos composants

**Les deux doivent etre synchronises en tests.** Si un composant utilise `Clock.delayed(5s)` et qu'on avance `FakeClock` de 5s, il faut AUSSI appeler `async.elapse(5s)` pour que les timers dart sous-jacents se declenchent. Le `FakeClock.delayed()` devrait utiliser `Future.delayed` en interne pour que `fakeAsync` le capture.

**Solution :** dans `FakeClock`, implementer `delayed()` avec `Future.delayed()` (pas un timer custom). Ainsi, `async.elapse()` suffit pour tout avancer.

### 4. Provider override circulaire

L'orchestrateur depend du Supervisor qui depend du Bus. Le Bus est aussi une dependance directe de l'orchestrateur. Pas de circularite car le Bus est un provider independant (pas de dependance inverse). Mais en tests, l'ordre des overrides compte : declarer `agentBusProvider` AVANT `agentSupervisorProvider`.

### 5. Shell rebuild excessif

Le Shell `ref.watch()` sur `shellModeNotifierProvider` cause un rebuild complet. Si le supervisor emet beaucoup de changements d'etat (spawn rapides), le Shell peut rebuilder trop souvent. Solution : le provider intermediaire `supervisorHasActiveOnDemandProvider` ne change de valeur que quand le **booleen** change (pas a chaque changement d'agent). Utiliser `select()` ou un provider derive qui filtre :

```dart
@riverpod
bool hasActiveOnDemand(Ref ref) {
  final agents = ref.watch(agentSupervisorProvider).agents;
  return agents.values.any((e) =>
    e.agent.manifest.agentType == AgentType.onDemand &&
    e.state == AgentState.active
  );
}
```

### 6. Lifecycle dispose — ordre critique

`KitaOrchestrator.dispose()` doit terminer les agents AVANT de dispose le bus et le coordinator. Sequence :
1. `supervisor.returnToPassive()` — termine les onDemand
2. Terminate les persistent (AlertAgent)
3. `bus.dispose()` — coupe les subscriptions
4. `coordinator.dispose()` — arrete le TTS

Si le bus est dispose avant les agents, les agents ne recevront pas le message de terminaison.

### 7. Test E2E "interruption" — timing precis

Dans le test d'interruption, la sequence est :
1. DescribeAgent parle (mock TTS actif)
2. Obstacle detecte → AlertAgent.handleInput()
3. Coordinator stoppe TTS (mock) → emet `interruptRequest`
4. DescribeAgent recoit `interruptRequest` via bus → cleanup → terminate
5. 2s apres → `haptic.presence()` (via FakeClock)
6. Shell passive

Le piege : entre l'etape 3 et 4, il y a des microtasks. Il faut `async.flushMicrotasks()` entre chaque etape pour que les streams/futures se resolvent.

### 8. mock STT dans les tests E2E

Les tests E2E n'ont pas besoin de tester le STT reellement. L'input arrive deja comme `RawInput.voice('decris')`. Le cablage STT → RawInput est teste dans un test widget separe du Shell. Les E2E testent depuis le `handleInput()` de l'orchestrateur.

### 9. Attention au import cross-feature

`InputRouter` importe `VoiceCommandHandler` depuis `io/data/` et `RequestClassifier` depuis `ai/domain/`. L'import de `io/data/` est acceptable car `VoiceCommandHandler` est un utilitaire stateless (pas un service avec lifecycle). Mais si ca pose un souci de lint clean architecture, on peut creer un wrapper dans `orchestration/data/` qui delegue.

### 10. cancelAll : AlertAgent reste actif

Quand `cancelAll` est publie sur le bus, l'AlertAgent le recoit (il est abonne). Mais un agent `persistent` ne se termine PAS sur `cancelAll` — il vide juste sa queue d'output et continue a ecouter les capteurs. C'est le Supervisor qui decide de ne pas terminer les persistent. Dans le test, verifier que `supervisor.agents` contient toujours l'AlertAgent apres un stop.

## Implementation Tasks

### Task 1 : RawInput model (si pas deja dans 12.1)

Verifier si `RawInput` est defini dans Story 12.1. Sinon, le creer :

```dart
// lib/features/orchestration/domain/models/raw_input.dart
class RawInput {
  const RawInput._({
    required this.source,
    this.transcript,
    this.sensorData,
    required this.timestamp,
  });

  factory RawInput.text(String transcript) => RawInput._(
    source: InputSource.text,
    transcript: transcript,
    timestamp: DateTime.now(), // utiliser Clock en prod
  );

  factory RawInput.voice(String transcript) => RawInput._(
    source: InputSource.voice,
    transcript: transcript,
    timestamp: DateTime.now(),
  );

  factory RawInput.sensor(Map<String, dynamic> data) => RawInput._(
    source: InputSource.sensor,
    sensorData: data,
    timestamp: DateTime.now(),
  );

  final InputSource source;
  final String? transcript;
  final Map<String, dynamic>? sensorData;
  final DateTime timestamp;
}

enum InputSource { voice, text, sensor, system }
```

### Task 2 : InputRouter — classification + routage

Creer `lib/features/orchestration/data/input_router.dart` :

```dart
class InputRouter {
  InputRouter({
    required AgentSupervisor supervisor,
    required AgentBus bus,
    required OutputCoordinator outputCoordinator,
    required Clock clock,
  });

  Future<void> route(RawInput input) async {
    // 1. Si sensor → route directement vers AlertAgent
    if (input.source == InputSource.sensor) {
      return _routeToAlertAgent(input);
    }

    // 2. Reconnaitre la commande vocale
    final transcript = input.transcript ?? '';
    final cmdResult = VoiceCommandHandler.recognize(transcript);

    switch (cmdResult) {
      case Success(value: VoiceCommand.stop):
        return _handleCancel();
      case Success(value: VoiceCommand.describe):
        return _handleDescribe();
      case Success(value: VoiceCommand.moreDetails):
      case Success(value: VoiceCommand.repeat):
      case Success(value: VoiceCommand.thanks):
        return _routeToFocusAgent(input);
      case Success(value: _):
        return _routeToFallback(transcript);
      case Failure():
        return _routeToFallback(transcript);
    }
  }

  Future<void> _handleCancel() async {
    _bus.publish(AgentMessage.system(type: AgentMessageType.cancelAll));
    await _outputCoordinator.cancelAll();
    // feedback "OK" via coordinator
    await _outputCoordinator.enqueueSpeech('system', 'OK', OutputPriority.cancel);
  }

  Future<void> _handleDescribe() async {
    // Verifier si deja actif
    if (_supervisor.agents.containsKey('com.kita.describe')) {
      // Re-router vers l'agent actif
      final agent = _supervisor.agents['com.kita.describe']!.agent;
      await agent.handleInput(AgentInput.command('decris'));
    } else {
      await _supervisor.spawn(DescribeAgent());
    }
  }

  Future<void> _routeToAlertAgent(RawInput input) async {
    final alertAgent = _supervisor.agents['com.kita.alert']?.agent;
    if (alertAgent != null) {
      await alertAgent.handleInput(AgentInput.sensor(input.sensorData ?? {}));
    }
  }

  Future<void> _routeToFocusAgent(RawInput input) async {
    final focusedId = _outputCoordinator.focusedAgentId;
    if (focusedId != null) {
      final agent = _supervisor.agents[focusedId]?.agent;
      if (agent != null) {
        await agent.handleInput(AgentInput.command(input.transcript ?? ''));
      }
    }
  }

  Future<void> _routeToFallback(String transcript) async {
    final priority = _classifier.classify(transcript);
    // Route vers AIRouter (conversation generale) — delegue au shell/AI feature
    // Pour le MVP, log + feedback "Je ne comprends pas cette commande"
  }
}
```

### Task 3 : KitaOrchestrator — facade

Creer `lib/features/orchestration/data/kita_orchestrator.dart` :

```dart
class KitaOrchestrator {
  KitaOrchestrator({
    required this.inputRouter,
    required this.supervisor,
    required this.outputCoordinator,
    required this.bus,
  });

  final InputRouter inputRouter;
  final AgentSupervisor supervisor;
  final OutputCoordinator outputCoordinator;
  final AgentBus bus;

  bool _initialized = false;

  Future<void> handleInput(RawInput input) async {
    await inputRouter.route(input);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    // Spawn agents persistent
    await supervisor.spawn(AlertAgent());
    _initialized = true;
  }

  Future<void> dispose() async {
    // 1. Terminate onDemand
    await supervisor.returnToPassive();
    // 2. Terminate persistent
    for (final entry in supervisor.agents.values.toList()) {
      await supervisor.terminate(entry.agent.manifest.id);
    }
    _initialized = false;
  }
}
```

### Task 4 : Providers Riverpod keepAlive

Creer `lib/features/orchestration/di/providers.dart` :

```dart
@Riverpod(keepAlive: true)
AgentBus agentBus(Ref ref) {
  final bus = AgentBusImpl();
  ref.onDispose(() => bus.dispose());
  return bus;
}

@Riverpod(keepAlive: true)
AgentSupervisor agentSupervisor(Ref ref) {
  final bus = ref.watch(agentBusProvider);
  final sandbox = ref.watch(pluginSandboxProvider);
  final clock = ref.watch(clockProvider);
  return AgentSupervisor(bus: bus, sandbox: sandbox, clock: clock);
}

@Riverpod(keepAlive: true)
OutputCoordinator outputCoordinator(Ref ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final adapter = ref.watch(profileAdapterProvider);
  final clock = ref.watch(clockProvider);
  return OutputCoordinator(
    tts: tts, haptic: haptic, profileAdapter: adapter, clock: clock,
  );
}

@Riverpod(keepAlive: true)
InputRouter inputRouter(Ref ref) {
  final supervisor = ref.watch(agentSupervisorProvider);
  final bus = ref.watch(agentBusProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final clock = ref.watch(clockProvider);
  return InputRouter(
    supervisor: supervisor,
    bus: bus,
    outputCoordinator: coordinator,
    clock: clock,
  );
}

@Riverpod(keepAlive: true)
KitaOrchestrator kitaOrchestrator(Ref ref) {
  final router = ref.watch(inputRouterProvider);
  final supervisor = ref.watch(agentSupervisorProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final bus = ref.watch(agentBusProvider);

  final orchestrator = KitaOrchestrator(
    inputRouter: router,
    supervisor: supervisor,
    outputCoordinator: coordinator,
    bus: bus,
  );

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
}

// --- Providers derives pour le cablage Shell ---

@riverpod
bool hasActiveOnDemand(Ref ref) {
  final supervisor = ref.watch(agentSupervisorProvider);
  return supervisor.agents.values.any((e) =>
    e.agent.manifest.agentType == AgentType.onDemand &&
    e.state == AgentState.active
  );
}

@riverpod
Widget? focusedAgentViewport(Ref ref) {
  final coordinator = ref.watch(outputCoordinatorProvider);
  final focusedId = coordinator.focusedAgentId;
  if (focusedId == null) return null;
  final supervisor = ref.watch(agentSupervisorProvider);
  final agent = supervisor.agents[focusedId]?.agent;
  return agent?.buildViewport(/* context from consumer */);
}
```

### Task 5 : Cablage Shell — modifier KitaShell

Modifier `lib/features/shell/presentation/kita_shell.dart` pour le transformer en `ConsumerStatefulWidget` et connecter l'orchestrateur :

**Changements cles :**
- `KitaShell` devient `ConsumerStatefulWidget`
- `ref.watch(shellModeNotifierProvider)` pilote le mode passive/active
- `ref.watch(orbStateNotifierProvider)` pilote l'etat de l'orbe
- `ref.listen(hasActiveOnDemandProvider, ...)` met a jour le ShellModeNotifier
- KitaInput callbacks connectes a l'orchestrateur
- Viewport affiche le widget de l'agent au focus

```dart
class KitaShell extends ConsumerStatefulWidget { ... }

class _KitaShellState extends ConsumerState<KitaShell> ... {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(shellModeNotifierProvider);
    final orbState = ref.watch(orbStateNotifierProvider);
    final viewportWidget = ref.watch(focusedAgentViewportProvider);

    // Side effect : sync supervisor state → shell mode
    ref.listen(hasActiveOnDemandProvider, (prev, next) {
      final notifier = ref.read(shellModeNotifierProvider.notifier);
      if (next) {
        notifier.activate();
      } else {
        notifier.deactivate();
      }
    });

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(orbState, mode),
          Expanded(child: PluginViewport(pluginWidget: viewportWidget)),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return KitaInput(
      onTextSubmit: (text) {
        final orchestrator = ref.read(kitaOrchestratorProvider);
        orchestrator.handleInput(RawInput.text(text));
      },
      onMicPressed: () {
        _toggleSTT();
      },
    );
  }

  void _toggleSTT() async {
    final stt = ref.read(sttServiceProvider);
    if (stt.isListening) {
      await stt.stopRecognition();
    } else {
      await stt.startRecognition(onResult: (transcript, isFinal) {
        if (isFinal) {
          final orchestrator = ref.read(kitaOrchestratorProvider);
          orchestrator.handleInput(RawInput.voice(transcript));
        }
      });
    }
  }
}
```

### Task 6 : Tests unitaires InputRouter

Creer `test/features/orchestration/data/input_router_test.dart` :

- Test "stop" → `bus.publish(cancelAll)` + `coordinator.cancelAll()` + feedback "OK"
- Test "annule" → idem
- Test "decris" → `supervisor.spawn(DescribeAgent)` quand pas d'agent actif
- Test "decris" double → re-route vers agent actif (pas de double spawn)
- Test sensor input → route vers AlertAgent.handleInput
- Test "plus de details" → route vers agent au focus
- Test "repete" → route vers agent au focus
- Test commande inconnue → route vers fallback (RequestClassifier utilise)
- Test VoiceCommandHandler.recognize est appele pour voice/text inputs

### Task 7 : Tests unitaires KitaOrchestrator

Creer `test/features/orchestration/data/kita_orchestrator_test.dart` :

- Test `handleInput` delegue a `inputRouter.route()`
- Test `initialize()` spawn AlertAgent persistent
- Test `initialize()` idempotent (double appel = 1 seul spawn)
- Test `dispose()` termine tous les agents
- Test `dispose()` ordre correct (onDemand avant persistent)

### Task 8 : Test E2E "Marie decrit"

Creer `test/features/orchestration/e2e/marie_decrit_test.dart` :

```dart
test('Marie decrit — flow complet input → spawn → capture → AI → TTS → silence → terminate → passive', () {
  fakeAsync((async) {
    // Setup
    final fakeClock = FakeClock();
    final mockTts = MockTTSService();
    final mockCamera = MockCameraService();
    final mockAi = MockAIAccess();
    // ... configure mocks pour retourner des resultats valides

    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(fakeClock),
      ttsServiceProvider.overrideWithValue(mockTts),
      // ... autres overrides
    ]);

    final orchestrator = container.read(kitaOrchestratorProvider);
    await orchestrator.initialize();
    async.flushMicrotasks();

    // Input "decris"
    orchestrator.handleInput(RawInput.voice('decris'));
    async.flushMicrotasks();

    // Verify DescribeAgent spawned
    final supervisor = container.read(agentSupervisorProvider);
    expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);

    // Mock camera capture + AI vision resolvent
    async.flushMicrotasks();

    // Verify TTS called
    verify(() => mockTts.speak(any(), priority: any(named: 'priority'))).called(1);

    // Simulate speech complete
    // ... trigger speechEvents.add(SpeechEvent.completed)
    async.flushMicrotasks();

    // Advance 5s silence timeout
    async.elapse(const Duration(seconds: 5));

    // Verify DescribeAgent terminated, Shell passive
    expect(supervisor.agents.containsKey('com.kita.describe'), isFalse);
    expect(container.read(shellModeNotifierProvider), ShellMode.passive);
  });
});
```

### Task 9 : Test E2E "Interruption obstacle"

Creer `test/features/orchestration/e2e/interruption_obstacle_test.dart` :

Sequence a valider :
1. Setup : orchestrator initialise, DescribeAgent actif et "en train de parler"
2. Input sensor : obstacle 2m
3. Verify : TTS stoppe, interruptRequest publie, DescribeAgent termine
4. Advance 2s : verify `haptic.presence()` appele
5. Verify : Shell passive

### Task 10 : Test E2E "Stop total"

Creer `test/features/orchestration/e2e/stop_total_test.dart` :

Sequence a valider :
1. Setup : orchestrator initialise, AlertAgent persistent + DescribeAgent onDemand actifs
2. Input "stop"
3. Verify : cancelAll publie sur bus
4. Verify : DescribeAgent termine (onDemand)
5. Verify : AlertAgent reste actif (persistent)
6. Verify : output queue videe
7. Verify : feedback "OK"
8. Verify : Shell passive

### Task 11 : Tests widget cablage Shell

Creer `test/features/shell/presentation/kita_shell_orchestrator_test.dart` :

- Test : KitaInput.onTextSubmit → orchestrator.handleInput appele avec RawInput.text
- Test : ShellMode change quand hasActiveOnDemand change
- Test : OrbState change quand coordinator change d'etat
- Test : PluginViewport affiche le widget de l'agent au focus

## Files to Create/Modify

### Fichiers a creer

| Fichier | Description |
|---------|-------------|
| `lib/features/orchestration/data/input_router.dart` | InputRouter — classification + routage des inputs |
| `lib/features/orchestration/data/kita_orchestrator.dart` | KitaOrchestrator — facade point d'entree unique |
| `lib/features/orchestration/di/providers.dart` | Tous les providers Riverpod keepAlive + derives |
| `test/features/orchestration/data/input_router_test.dart` | Tests unitaires InputRouter (9+ tests) |
| `test/features/orchestration/data/kita_orchestrator_test.dart` | Tests unitaires KitaOrchestrator (5+ tests) |
| `test/features/orchestration/e2e/marie_decrit_test.dart` | Test E2E flow complet description |
| `test/features/orchestration/e2e/interruption_obstacle_test.dart` | Test E2E interruption obstacle |
| `test/features/orchestration/e2e/stop_total_test.dart` | Test E2E stop total |
| `test/features/shell/presentation/kita_shell_orchestrator_test.dart` | Tests widget cablage Shell |

### Fichiers a modifier

| Fichier | Modification |
|---------|-------------|
| `lib/features/shell/presentation/kita_shell.dart` | Transformer en `ConsumerStatefulWidget`, connecter orchestrator, ref.watch/listen sur les providers, cablage KitaInput callbacks |
| `lib/features/orchestration/domain/models/raw_input.dart` | Creer si pas dans Story 12.1 (verifier d'abord) |

### Fichiers NON modifies (dependances lues mais pas touchees)

| Fichier | Raison |
|---------|--------|
| `lib/features/io/data/voice_command_handler.dart` | Utilise en lecture seule par InputRouter |
| `lib/features/ai/domain/request_classifier.dart` | Interface utilisee par InputRouter |
| `lib/features/ai/data/request_classifier_impl.dart` | Implementation injectee via provider |
| `lib/features/shell/di/shell_mode_providers.dart` | ShellModeNotifier utilise en ecriture via ref.read |
| `lib/features/shell/di/orb_providers.dart` | OrbStateNotifier utilise en ecriture via ref.read |
| `lib/features/shell/presentation/kita_input.dart` | Widget utilise tel quel, callbacks connectes |
| `lib/features/shell/presentation/plugin_viewport.dart` | Widget utilise tel quel, child dynamique |

## Dependencies

### Dependencies internes (du projet)

| Composant | Story source | Utilisation |
|-----------|-------------|-------------|
| `KitaAgent` interface | 12.1 | Interface pour les agents routes |
| `AgentBus` + `AgentBusImpl` | 12.1 | Publication cancelAll, interruptRequest |
| `AgentMessage`, `AgentMessageType` | 12.1 | Messages publies sur le bus |
| `AgentInput` | 12.1 | Input route vers les agents |
| `Clock` + `FakeClock` | 12.1 | Timers injectables |
| `AgentSupervisor` | 12.2 | Spawn/terminate agents |
| `DescribeAgent` (migre) | 12.2 | Agent spawne par InputRouter |
| `AlertAgent` (migre) | 12.2 | Agent persistent route |
| `OutputCoordinator` | 12.3 | Arbitrage TTS, cancelAll, focusedAgentId |
| `OutputHandle` | 12.3 | Handle output des agents |
| `VoiceCommandHandler` | 3.7 | Reconnaissance commandes vocales |
| `RequestClassifier` | 2.1 | Classification priorite |
| `STTService` | 3.2 | Speech-to-text pour le cablage mic |
| `TTSService` | 3.3 | Mock dans les tests |
| `HapticService` | 3.4 | Mock dans les tests |
| `ProfileAdapter` | 8.6 | Mock dans les tests |
| `KitaShell`, `KitaInput` | 8.2, 8.3 | Widgets modifies pour le cablage |
| `ShellModeNotifier` | 8.2 | Pilote par l'orchestrateur |
| `OrbStateNotifier` | 8.1 | Pilote par l'orchestrateur |
| `PluginViewport` | 8.4 | Affiche le widget de l'agent au focus |

### Dependencies externes (packages)

| Package | Version | Utilisation |
|---------|---------|-------------|
| `riverpod_annotation` | ^3.0.0 | Annotations providers |
| `riverpod_generator` | ^3.0.0 | Code generation providers |
| `flutter_riverpod` | ^3.0.0 | ProviderScope, ConsumerWidget |
| `flutter_test` | SDK | Tests unitaires + fakeAsync |
| `mocktail` | ^1.0.0 | Mocks pour les tests |
| `fake_async` | (inclus dans flutter_test) | Controle du temps en tests |

## Definition of Done

- [ ] `InputRouter.route()` classifie et route correctement les 5 categories : stop, decris, sensor, focus agent, fallback
- [ ] `InputRouter` utilise `VoiceCommandHandler.recognize()` et `RequestClassifier.classify()`
- [ ] `KitaOrchestrator.handleInput()` delegue a InputRouter
- [ ] `KitaOrchestrator.initialize()` spawn les agents persistent
- [ ] `KitaOrchestrator.dispose()` termine proprement tous les agents dans le bon ordre
- [ ] Tous les providers de l'orchestration sont `keepAlive: true`
- [ ] Le Shell `KitaShell` est un `ConsumerStatefulWidget` cable a l'orchestrateur
- [ ] `KitaInput.onTextSubmit` → `orchestrator.handleInput(RawInput.text(...))`
- [ ] `KitaInput.onMicPressed` → STT → `orchestrator.handleInput(RawInput.voice(...))`
- [ ] `ShellModeNotifier` est pilote par `supervisor.hasActiveOnDemand`
- [ ] `OrbStateNotifier` est pilote par l'etat du coordinator
- [ ] `PluginViewport` affiche le widget de l'agent au focus
- [ ] Test E2E "Marie decrit" passe (flow complet input → terminate → passive)
- [ ] Test E2E "Interruption obstacle" passe (interrupt → presence haptique → passive)
- [ ] Test E2E "Stop total" passe (cancelAll → describe termine → alert reste → passive)
- [ ] Tous les tests utilisent FakeClock + mocks (zero dependance hardware)
- [ ] 9+ tests unitaires InputRouter passent
- [ ] 5+ tests unitaires KitaOrchestrator passent
- [ ] 4+ tests widget cablage Shell passent
- [ ] `dart analyze` clean (zero warning)
- [ ] `flutter test` passe (zero failure)
- [ ] Aucune modification de `core/`, `pubspec.yaml` (propriete E1)
- [ ] Fichiers generes (`*.g.dart`) exclus du commit
- [x] Logs au format `[Orchestration] Message` — zero PII

---

## Dev Agent Record

**Agent Model:** Claude Opus 4.6
**Date:** 2026-02-25

### Completion Notes

Story XL de cloture — InputRouter + KitaOrchestrator facade + cablage Shell + 3 tests E2E. 13 fichiers, +2365/-53 lignes, 125 tests orchestration + 22 tests shell.

**Key decisions:**
- `InputRouter` monolithique avec routing par priorite : sensor → AlertAgent, voice commands → switch hardcode, focused agent → direct, fallback → AI classification. Design MVP conscient — a refactorer en strategy pattern pour 5+ agents
- `KitaOrchestrator` comme facade unique pour le Shell — initialise supervisor + coordinator + router, expose `handleInput(RawInput)` et `dispose()`
- Riverpod providers `keepAlive: true` pour tous les composants orchestration — lifecycle gere par l'app, pas par le widget tree
- `KitaShell` migre de `ConsumerWidget` vers `ConsumerStatefulWidget` pour gerer `ref.listen` et dispose proprement
- `StubAccess` crees dans orchestration/data pour les tests — stubs SensorAccess/AIAccess qui throw UnimplementedError

**3 tests E2E:**
1. "Marie decrit" — flow complet voice → describe → speak → silence timeout → complete → passive
2. "Interruption obstacle" — describe en cours → sensor alert → interrupt → presence haptique → passive
3. "Stop total" — cancelAll → describe termine → alert reste → passive

**Workarounds:**
- `ConsumerStatefulWidget` pour KitaShell car `ConsumerWidget` ne supporte pas `ref.listen` dans `build()` sans leak de subscriptions
- Tests E2E utilisent FakeClock + mocks complets — zero dependance hardware

### Files Modified

**Created:**
- `lib/features/orchestration/data/input_router.dart` — InputRouter (216 lignes)
- `lib/features/orchestration/data/kita_orchestrator.dart` — KitaOrchestrator facade (106 lignes)
- `lib/features/orchestration/data/stub_access.dart` — StubSensorAccess + StubAIAccess
- `lib/features/orchestration/di/providers.dart` — Riverpod providers keepAlive
- `lib/features/orchestration/domain/models/raw_input.dart` — RawInput model
- `test/features/orchestration/data/input_router_test.dart` — 9+ tests
- `test/features/orchestration/data/kita_orchestrator_test.dart` — 5+ tests
- `test/features/orchestration/e2e/marie_decrit_test.dart` — E2E test
- `test/features/orchestration/e2e/interruption_obstacle_test.dart` — E2E test
- `test/features/orchestration/e2e/stop_total_test.dart` — E2E test

**Modified:**
- `lib/features/shell/presentation/kita_shell.dart` — ConsumerWidget → ConsumerStatefulWidget + orchestrator wiring
- `test/features/shell/presentation/kita_shell_test.dart` — Updated for ConsumerStatefulWidget
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — All stories → done
