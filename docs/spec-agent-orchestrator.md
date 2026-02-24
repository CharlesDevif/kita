# Spec : KitaOrchestrator — Architecture Multi-Agents

**Phase :** 3.5 (pré-requis Phase 4)
**Validé par :** Charles, 2026-02-24
**Remplace :** `docs/spec-request-orchestrator.md` (queue FIFO simple)
**Révisé après :** Party Mode review (Winston, Amelia, Sally, Murat, John)

## Vision

Kita n'est pas une app qui exécute des commandes une par une.
Kita est un **système multi-agents** où plusieurs agents vivent simultanément,
utilisent des services, communiquent entre eux, et partagent les canaux de
sortie (voix, haptique, écran).

L'orchestrateur est le **cerveau** de Kita — il reçoit tout, route tout, arbitre tout.

## Décisions architecturales (Party Mode)

| # | Décision | Choix | Raison |
|---|----------|-------|--------|
| 1 | Emplacement | `lib/features/orchestration/` | `core/` = utilitaires sans logique métier. L'orchestrateur connaît les agents, le TTS, Marie — c'est la feature principale. |
| 2 | Abstraction | `KitaAgent` **remplace** `KitaPlugin` | Éliminer la couche wrapper. Un seul concept, une seule interface. Les plugins existants deviennent des agents. |
| 3 | Haptique presence | Triple battement doux 2s post-interruption CRITICAL | Marie ne doit jamais être dans le silence sans savoir si Kita fonctionne. Haptique (pas sonore) pour ne pas couvrir les sons ambiants. |
| 4 | Clock injectable | Tous timers/cooldowns via `Clock` abstrait | Tests 100% déterministes. `FakeClock` en test, `SystemClock` en prod. |
| 5 | Bus filtré | Subscription par `AgentMessageType` | À 30 FPS de détections, seul l'AlertAgent reçoit les events. Les autres ne sont pas notifiés. |
| 6 | Silence timeout | Agent gère via `OutputHandle.onSpeechComplete` | Le coordinator ne connaît pas la politique de timeout. Séparation des responsabilités. |
| 7 | ContextAgent | **OUT** MVP | Phase 4+. Le MVP gère 2 agents (Alert + Describe). |
| 8 | Plugins tiers YAML | **OUT** MVP | Le `PluginLoader` reste mais n'est pas prioritaire. |
| 9 | Scope | ~15 fichiers, 4 stories, 2 agents concurrents | Guard-rail MVP : exactement ce qui est nécessaire pour E9/E10. |

## Architecture

```
         ┌──────────────────────────────────────────────────────────┐
         │                        INPUT                             │
         │    Voix (STT)  │  Texte  │  Capteurs  │  Événements     │
         └───────────┬──────────────────────────────────────────────┘
                     │
              ┌──────▼──────┐
              │   KitaInput  │  (Shell widget — callbacks)
              └──────┬──────┘
                     │
         ┌───────────▼────────────┐
         │    KitaOrchestrator    │  ← LE CERVEAU
         │                        │
         │  - InputRouter         │  classifie + route l'input
         │  - AgentSupervisor     │  spawn / suspend / kill agents
         │  - OutputCoordinator   │  arbitre TTS / haptic / visual
         │  - AgentBus            │  communication inter-agents
         └───┬──────┬─────┘
             │      │
    ┌────────▼──┐ ┌─▼──────────┐
    │ AlertAgent│ │DescribeAg. │  ...N agents
    │(persistent)│ │(on-demand) │
    └─────┬─────┘ └─────┬─────┘
          │             │
    ┌─────▼─────────────▼──────────────────┐
    │         SERVICES PARTAGÉS            │
    │  Camera │ TTS │ Haptic │ AI │ Memory │
    └──────────────────────────────────────┘
```

## Interface KitaAgent

`KitaAgent` **remplace** `KitaPlugin`. C'est la seule interface pour tout module
qui veut participer au système. Les plugins existants migrent vers cette interface.

```dart
/// Remplace KitaPlugin. Interface unique pour tous les agents Kita.
abstract class KitaAgent {
  /// Manifest enrichi : id, nom, permissions, + agentType + priority.
  AgentManifest get manifest;

  /// Commandes vocales que cet agent reconnaît.
  List<VoiceCommand> get voiceCommands;

  // === Lifecycle ===

  /// Appelé quand le Supervisor spawn cet agent.
  /// Reçoit l'AgentContext = sa boîte à outils sandboxée.
  Future<void> onSpawn(AgentContext context);

  /// Suspension (économie batterie, background).
  Future<void> onSuspend();

  /// Reprise après suspension.
  Future<void> onResume();

  /// Terminaison propre. Libérer les ressources.
  Future<void> onTerminate();

  // === Communication ===

  /// Reçoit un input routé par l'InputRouter.
  Future<Result<AgentOutput>> handleInput(AgentInput input);

  /// Reçoit un message du bus. Opt-in, default no-op.
  /// Seuls les types auxquels l'agent est abonné arrivent ici.
  void onBusMessage(AgentMessage message) {}

  // === UI ===

  /// Widget pour le viewport du Shell. null = pas de viewport.
  Widget? buildViewport(BuildContext context);
}
```

### AgentManifest

Extension de l'ancien `PluginManifest` :

```dart
class AgentManifest {
  // Hérité de PluginManifest
  final String id;              // reverse-domain: "com.kita.describe"
  final String name;
  final String version;
  final String description;
  final TrustLevel trustLevel;
  final List<String> permissions;
  final List<String> capabilities;
  final List<String> compatibleProfiles;

  // Nouveau — agent-specific
  final AgentType agentType;     // persistent | onDemand | background
  final AgentPriority priority;  // critical | high | standard | low
  final Set<AgentMessageType> subscriptions;  // types de messages écoutés
}
```

### AgentType

| Type | Lifecycle | Exemples MVP |
|------|-----------|--------------|
| `persistent` | Tourne tant que Kita est active. Survit au changement de mode. | AlertAgent |
| `onDemand` | Spawné sur commande, terminé quand sa tâche est finie. | DescribeAgent |
| `background` | Tourne en fond, basse priorité, peut être suspendu. | (post-MVP) |

### AgentPriority

| Niveau | Usage | Comportement output |
|--------|-------|---------------------|
| `critical` | Alertes obstacles < 3m | Interrompt TTS immédiatement |
| `high` | Alertes obstacles 3-5m | Attend fin de phrase (~2s) |
| `standard` | Description, conversation | FIFO, attend son tour |
| `low` | Background, cleanup | FIFO, timeout 10s |

## AgentContext

L'objet injecté dans chaque agent au spawn. Construit par le `PluginSandbox`
(qui reste inchangé — il enforce les permissions du manifest).

```dart
class AgentContext {
  final SensorAccess sensors;      // camera, location, motion (sandboxé)
  final AIAccess ai;               // text + vision (sandboxé)
  final MemoryAccess? memory;      // stockage (sandboxé, null si pas de permission)
  final AgentBus bus;              // envoyer/recevoir des messages
  final OutputHandle output;       // produire du TTS/haptic/visual
  final Clock clock;               // injectable pour les timers
}
```

## OutputHandle

L'agent ne parle JAMAIS directement au TTS/Haptic. Il passe par son `OutputHandle` :

```dart
class OutputHandle {
  final String agentId;
  final OutputCoordinator _coordinator;

  /// Demande à parler. Le coordinator décide quand/si.
  Future<void> speak(String text, {OutputPriority priority});

  /// Retour haptique.
  Future<void> haptic(HapticPattern pattern, {OutputPriority priority});

  /// Met à jour le viewport visuel de cet agent.
  void updateViewport(Widget widget);

  /// Stream d'événements speech (pour le silence timeout).
  Stream<SpeechEvent> get speechEvents;
  // SpeechEvent: started | completed | interrupted

  /// Signale que l'agent a terminé sa tâche.
  void complete();
}
```

### Flow du silence timeout (DescribeAgent)

```
Agent → output.speak("description") → OutputCoordinator → TTS
TTS termine → OutputCoordinator → speechEvents.add(completed)
Agent écoute speechEvents → reçoit completed → démarre timer silence 5s (via Clock)
Timer expire → agent appelle output.complete() → Supervisor.terminate(agentId)
```

## AgentBus

Communication inter-agents par messages typés, **filtré par subscription**.

```dart
/// Interface
abstract class AgentBus {
  /// Publie un message. Seuls les agents abonnés au type le reçoivent.
  void publish(AgentMessage message);

  /// S'abonne à des types de messages pour un agent.
  void subscribe(String agentId, Set<AgentMessageType> types);

  /// Se désabonne (appelé automatiquement au terminate).
  void unsubscribe(String agentId);
}

class AgentMessage {
  final String fromAgent;        // "alert", "describe", "system"
  final String? toAgent;         // null = tous les abonnés du type
  final AgentMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
}

enum AgentMessageType {
  // Lifecycle
  agentSpawned,
  agentTerminated,

  // Interruption
  interruptRequest,     // "je dois parler, pousse-toi"
  interruptAck,         // "ok je me tais"

  // Data sharing
  contextUpdate,        // "Marie est à tel endroit"
  detectionEvent,       // "obstacle détecté à 2m"
  descriptionComplete,  // "j'ai décrit une rue avec des arbres"

  // User intent
  cancelAll,            // "stop" — tout le monde se tait
  userCommand,          // nouvelle commande utilisateur
}
```

### Subscriptions MVP

| Agent | S'abonne à |
|-------|-----------|
| AlertAgent | `{cancelAll, userCommand}` |
| DescribeAgent | `{cancelAll, interruptRequest, userCommand}` |

## InputRouter

Reçoit tout l'input brut, le classifie et le route :

```dart
class InputRouter {
  final VoiceCommandHandler _voiceHandler;
  final RequestClassifier _classifier;
  final AgentSupervisor _supervisor;
  final AgentBus _bus;

  Future<void> route(RawInput input);
}

class RawInput {
  final InputSource source;       // voice | text | sensor | system
  final String? transcript;       // si voice/text
  final Map<String, dynamic>? sensorData;  // si sensor
  final DateTime timestamp;
}

enum InputSource { voice, text, sensor, system }
```

### Logique de routage

```
1. "stop" / "annule"
   → bus.publish(cancelAll)
   → outputCoordinator.cancelAll()
   → feedback sonore bref "OK"

2. "décris" / "describe"
   → supervisor.spawn(DescribeAgent) ou re-route si déjà actif
   → Shell → mode ACTIVE

3. obstacle_detected (capteur)
   → route vers AlertAgent.handleInput(...)
   (AlertAgent toujours actif, pas besoin de spawn)

4. "plus de détails" / "répète" / "merci"
   → route vers l'agent au focus (dernier à avoir parlé)

5. Commande inconnue
   → route vers AIRouter (conversation générale, futur)
```

## OutputCoordinator

Arbitre quand N agents veulent parler. Le composant le plus critique.

```dart
class OutputCoordinator {
  final TTSService _tts;
  final HapticService _haptic;
  final ProfileAdapter _profileAdapter;
  final Clock _clock;

  /// Enqueue une demande de speech.
  Future<void> enqueueSpeech(String agentId, String text, OutputPriority priority);

  /// Enqueue un haptic.
  Future<void> enqueueHaptic(String agentId, HapticPattern pattern, OutputPriority priority);

  /// Annule tout (CANCEL).
  Future<void> cancelAll();

  /// Quel agent contrôle le viewport actuellement.
  String? get focusedAgentId;
}
```

### Règles d'arbitrage TTS

| Priorité | Comportement |
|----------|-------------|
| **CANCEL** | `TTS.stop()` + vide queue + reset + feedback "OK" |
| **CRITICAL** | `TTS.stop()` immédiat + parle + `interruptRequest` sur le bus |
| **HIGH** | Attend fin de phrase (~2s max via `_tts.waitForPause()`) puis parle |
| **STANDARD** | FIFO, attend son tour |
| **LOW** | FIFO, timeout 10s — droppé silencieusement si expiré |

### Règles supplémentaires

- **Déduplication** : même agent + même contenu dans les 2s → drop
- **Cooldown alertes** : même `{label}_{zone}` dans 15s → silencieux
- **Exception rapprochement** : distance diminue > 30% → re-alerte malgré cooldown
- **Présence haptique** : 2s après une interruption CRITICAL qui a coupé un agent onDemand → `HapticPattern.presence` (triple battement doux)

### Viewport management

- Un seul agent contrôle le viewport principal à la fois
- L'agent au "focus" = le dernier à avoir produit un output
- AlertAgent peut superposer un overlay (sur le viewport existant)

### Post-interruption : pas de reprise auto

Après une alerte qui interrompt une description :
- Kita **ne reprend PAS** automatiquement
- Marie doit re-demander ("décris" ou "continue")
- Raison : le contexte spatial a changé (Marie a bougé)
- Le signal haptique `presence` indique que Kita est toujours là

## AgentSupervisor

Gère le lifecycle de tous les agents :

```dart
class AgentSupervisor {
  final AgentBus _bus;
  final PluginSandbox _sandbox;     // construit les AgentContext
  final Clock _clock;

  /// Agents actuellement vivants (active + suspended).
  Map<String, AgentEntry> get agents;

  Future<void> spawn(KitaAgent agent);
  Future<void> suspend(String agentId);
  Future<void> resume(String agentId);
  Future<void> terminate(String agentId);

  /// Termine tous les onDemand. Les persistent restent.
  Future<void> returnToPassive();
}

class AgentEntry {
  final KitaAgent agent;
  final AgentState state;  // active | suspended | terminating
}
```

### Règles de supervision

- **Démarrage app** (après onboarding) : spawn les agents `persistent` (AlertAgent)
- **Commande utilisateur** : spawn l'agent `onDemand` approprié
- **Silence timeout** : agent onDemand appelle `output.complete()` → supervisor le termine
- **"stop"** : termine tous les `onDemand`, les `persistent` restent actifs
- **Max agents** : 5 simultanés (hérité de `Limits.maxActivePlugins`)
- **Batterie faible** : suspend les agents `background` (post-MVP)

## Clock injectable

Tous les composants time-dependent reçoivent un `Clock` :

```dart
abstract class Clock {
  DateTime now();
  Timer periodic(Duration duration, void Function(Timer) callback);
  Timer delayed(Duration duration, void Function() callback);
  Future<void> wait(Duration duration);
}

class SystemClock implements Clock { /* utilise dart:async */ }
class FakeClock implements Clock { /* avance le temps manuellement en tests */ }
```

Utilisateurs : `OutputCoordinator` (cooldown 15s, timeout 10s, presence 2s),
`DescribeAgent` (silence timeout 5s), `AgentSupervisor` (futur batterie).

## HapticPattern.presence

Nouveau pattern ajouté au `HapticService` :

```dart
enum HapticPattern {
  info,       // existant — pulsation légère
  warning,    // existant — double pulsation
  danger,     // existant — vibration forte
  presence,   // NOUVEAU — triple battement doux (cœur qui bat)
}
```

Déclenché automatiquement par l'`OutputCoordinator` 2s après une interruption
CRITICAL qui a coupé un agent onDemand. Marie sent que Kita est toujours là.

## Agents MVP

### AlertAgent (persistent, priority: critical)

Migration de l'actuel `KitaAlertPlugin` → `KitaAgent`.

- **agentType** : `persistent`
- **subscriptions** : `{cancelAll, userCommand}`
- **Input** : détections obstacle via `handleInput(AgentInput.sensor(...))`
- **Output** : via `OutputHandle` — plus d'appel direct à TTS/Haptic
- **Cooldown** : géré par `OutputCoordinator` (pas par l'agent)

Changements par rapport à `KitaAlertPlugin` :
- Supprime l'injection directe de `TTSService`, `HapticService`, `ProfileAdapter`
- Passe par `context.output.speak()` et `context.output.haptic()` à la place
- Le cooldown 15s sort de l'agent → va dans l'OutputCoordinator

### DescribeAgent (onDemand, priority: standard)

Migration de l'actuel `KitaDescribePlugin` → `KitaAgent`.

- **agentType** : `onDemand`
- **subscriptions** : `{cancelAll, interruptRequest, userCommand}`
- **Input** : commandes vocales via `handleInput(AgentInput.command(...))`
- **Output** : via `OutputHandle` — description TTS + viewport texte
- **Silence timeout** : écoute `output.speechEvents` → timer 5s via `Clock` → `output.complete()`

Changements par rapport à `KitaDescribePlugin` :
- Supprime `_silenceTimer` interne → utilise `Clock.delayed()` + `speechEvents`
- Supprime `onReturnPassive` callback → utilise `output.complete()`
- `onBusMessage(interruptRequest)` → annule le timer, nettoie l'état

## KitaOrchestrator (façade)

Point d'entrée unique pour le Shell :

```dart
class KitaOrchestrator {
  final InputRouter inputRouter;
  final AgentSupervisor supervisor;
  final OutputCoordinator outputCoordinator;
  final AgentBus bus;

  /// Point d'entrée principal — tout input passe par ici.
  Future<void> handleInput(RawInput input);

  /// Initialisation post-onboarding.
  Future<void> initialize();

  /// Arrêt propre.
  Future<void> dispose();
}
```

## Câblage Shell (Riverpod)

```dart
// Provider principal — singleton, keepAlive
@riverpod
KitaOrchestrator kitaOrchestrator(ref) {
  return KitaOrchestrator(
    inputRouter: ref.watch(inputRouterProvider),
    supervisor: ref.watch(agentSupervisorProvider),
    outputCoordinator: ref.watch(outputCoordinatorProvider),
    bus: ref.watch(agentBusProvider),
  );
}

// Câblage dans le Shell :
// KitaInput.onTextSubmit → orchestrator.handleInput(RawInput.text(...))
// KitaInput.onMicPressed → démarre STT → résultat → orchestrator.handleInput(RawInput.voice(...))
// AgentSupervisor.hasActiveOnDemand → ShellModeNotifier (passive/active)
// OutputCoordinator.isSpeaking → OrbStateNotifier (processing/responding/passive)
// Agent.output.updateViewport → PluginViewport.child
```

## Fichiers

### Créés (~15 fichiers)

```
lib/features/orchestration/
├── domain/
│   ├── kita_agent.dart              # Interface KitaAgent (remplace KitaPlugin)
│   ├── agent_bus.dart               # Interface AgentBus
│   ├── output_handle.dart           # OutputHandle + SpeechEvent
│   ├── clock.dart                   # Clock abstrait + SystemClock + FakeClock
│   └── models/
│       ├── agent_manifest.dart      # AgentManifest (extends PluginManifest)
│       ├── agent_message.dart       # AgentMessage + AgentMessageType
│       ├── agent_input.dart         # AgentInput (remplace PluginRequest)
│       ├── agent_output.dart        # AgentOutput (remplace PluginResponse)
│       └── output_priority.dart     # OutputPriority enum
├── data/
│   ├── kita_orchestrator.dart       # Façade
│   ├── input_router.dart            # Classification + routage
│   ├── agent_supervisor.dart        # Lifecycle agents
│   ├── output_coordinator.dart      # Arbitrage TTS/haptic/visual
│   └── agent_bus_impl.dart          # Bus filtré par subscription
└── di/
    └── providers.dart               # Riverpod providers
```

### Migrés (renommage interface, même fichier)

```
lib/features/plugins/built_in/describe/describe_plugin.dart
  → KitaDescribePlugin implements KitaAgent (au lieu de KitaPlugin)

lib/features/plugins/built_in/alert/kita_alert_plugin.dart
  → KitaAlertPlugin implements KitaAgent (au lieu de KitaPlugin)
```

### Étendus (modifications mineures)

```
lib/features/io/domain/tts_service.dart        → + onSpeechComplete stream
lib/features/io/data/tts_service_impl.dart     → expose le stream
lib/features/io/domain/haptic_service.dart     → + HapticPattern.presence
lib/features/io/data/haptic_service_impl.dart  → implémente presence
lib/features/shell/presentation/kita_shell.dart → câblage orchestrator
lib/features/plugins/domain/kita_plugin.dart   → deprecated, alias vers KitaAgent
lib/features/plugins/data/plugin_registry.dart → adapté pour AgentManifest
```

### Inchangés

```
lib/features/plugins/data/plugin_sandbox_impl.dart  → construit AgentContext
lib/features/plugins/data/plugin_loader.dart         → parse YAML manifests
lib/features/io/data/voice_command_handler.dart      → utilisé par InputRouter
lib/features/ai/data/request_classifier.dart         → utilisé par InputRouter
lib/shared/multi_modal/profile_adapter.dart          → utilisé par OutputCoordinator
```

## Mapping migration

| Ancien | Nouveau | Type de changement |
|--------|---------|-------------------|
| `KitaPlugin` | `KitaAgent` | Interface remplacée (deprecated alias gardé) |
| `PluginManifest` | `AgentManifest` | Étendu (agentType, priority, subscriptions) |
| `PluginRequest` | `AgentInput` | Remplacé (inclut OutputHandle via context) |
| `PluginResponse` | `AgentOutput` | Remplacé (simplifié, output via handle) |
| `PluginRegistry` | `AgentSupervisor` | Absorbé (supervisor gère lifecycle + registry) |
| `PluginSandbox` | Inchangé | Construit AgentContext au lieu de PluginRequest |
| `KitaDescribePlugin` | `DescribeAgent` | Migré vers KitaAgent interface |
| `KitaAlertPlugin` | `AlertAgent` | Migré vers KitaAgent interface |

## Dépendances (toutes existantes)

- `PluginSandbox` (E5) ✓ — construit AgentContext
- `TTSService` avec priorités (E3) ✓ — à étendre avec `onSpeechComplete`
- `HapticService` (E3) ✓ — à étendre avec `HapticPattern.presence`
- `VoiceCommandHandler` (E3) ✓ — utilisé par InputRouter
- `RequestClassifier` (E2) ✓ — utilisé par InputRouter
- `ProfileAdapter` (E8) ✓ — utilisé par OutputCoordinator
- `ShellModeNotifier` / `OrbStateNotifier` (E8) ✓ — pilotés par orchestrator
- `KitaDescribePlugin` (E6) ✓ — migré vers KitaAgent
- `KitaAlertPlugin` (E7) ✓ — migré vers KitaAgent

## Tests

### Unitaires (~15)

- [ ] InputRouter : "stop" → broadcast cancelAll + feedback "OK"
- [ ] InputRouter : "décris" → spawn DescribeAgent
- [ ] InputRouter : obstacle_detected → route vers AlertAgent
- [ ] InputRouter : "plus de détails" → route vers agent au focus
- [ ] AgentSupervisor : spawn/suspend/resume/terminate lifecycle complet
- [ ] AgentSupervisor : returnToPassive ne tue pas les persistent
- [ ] AgentSupervisor : max 5 agents simultanés
- [ ] AgentBus : message arrive uniquement aux agents abonnés au type
- [ ] AgentBus : unsubscribe au terminate
- [ ] OutputCoordinator : CRITICAL interrompt STANDARD
- [ ] OutputCoordinator : HIGH attend fin de phrase (~2s max)
- [ ] OutputCoordinator : CANCEL coupe tout + vide queue
- [ ] OutputCoordinator : cooldown 15s même obstacle type
- [ ] OutputCoordinator : exception rapprochement -30% pendant cooldown
- [ ] OutputCoordinator : déduplication même agent + contenu < 2s
- [ ] OutputCoordinator : presence haptique 2s après interruption CRITICAL
- [ ] OutputHandle : speechEvents stream (started, completed, interrupted)

### Intégration (3 scénarios E2E)

- [ ] **Marie décrit** : input "décris" → InputRouter → spawn DescribeAgent → capture photo (mock) → AI vision (mock) → OutputCoordinator → TTS (mock) → speechComplete → silence 5s (FakeClock) → complete → terminate → Shell passive
- [ ] **Interruption obstacle** : DescribeAgent parle → détection obstacle 2m → AlertAgent → OutputCoordinator stop TTS → alerte CRITICAL → interruptRequest sur bus → DescribeAgent terminé → haptic presence 2s après (FakeClock) → Shell passive
- [ ] **Stop total** : 2 agents actifs (Alert + Describe) → input "stop" → cancelAll broadcast → Describe terminé, Alert reste → queue vidée → feedback "OK" → Shell passive

## Stories Phase 3.5

| Story | Contenu | Deps |
|-------|---------|------|
| **3.5.1** | `KitaAgent` interface + `AgentManifest` + `AgentContext` + `AgentBus` (domain + impl) + `Clock` + modèles | Aucune |
| **3.5.2** | `AgentSupervisor` + migration `DescribePlugin` → `DescribeAgent` + migration `AlertPlugin` → `AlertAgent` + `HapticPattern.presence` + `TTS.onSpeechComplete` | 3.5.1 |
| **3.5.3** | `OutputCoordinator` (arbitrage TTS priority, cooldown, interruptions, dédup, presence haptique) + `OutputHandle` | 3.5.1 |
| **3.5.4** | `InputRouter` + `KitaOrchestrator` façade + câblage Shell complet + 3 tests E2E intégration | 3.5.2 + 3.5.3 |

```
3.5.1 (interfaces + bus + clock)
    ├── 3.5.2 (supervisor + agents migrated)  ─┐
    └── 3.5.3 (output coordinator)             ─┤→ 3.5.4 (router + façade + câblage Shell)
```

## Scénarios de référence

### Marie décrit (flow normal)

```
 0.0s  Marie dit "décris"              → InputRouter.route(voice)
       → spawn DescribeAgent            → AgentSupervisor
       → Shell mode ACTIVE              → ShellModeNotifier
       → Orb state PROCESSING           → OrbStateNotifier

 0.5s  DescribeAgent: capturePhoto()   → AgentContext.sensors
       → AI vision request              → AgentContext.ai

 2.0s  AI répond                        → DescribeAgent
       → output.speak(text, STANDARD)   → OutputCoordinator
       → TTS parle                      → Orb state RESPONDING

 4.0s  TTS terminé                      → speechEvents(completed)
       → DescribeAgent démarre timer 5s → Clock.delayed(5s)

 9.0s  Timer expire                     → output.complete()
       → Supervisor.terminate()          → Shell mode PASSIVE
```

### Interruption obstacle

```
 3.5s  Obstacle détecté: poteau 2m     → InputRouter.route(sensor)
       → AlertAgent.handleInput()       → (déjà actif)

       AlertAgent:
       → output.speak("Poteau 2m!", CRITICAL)
       → output.haptic(danger)

       OutputCoordinator:
       1. TTS.stop() immédiat
       2. bus.publish(interruptRequest)
       3. TTS "Attention! Poteau à 2 mètres!"
       4. haptic.danger()

       DescribeAgent reçoit interruptRequest
       → annule timer, nettoie état
       → Supervisor.terminate(describe)

 4.5s  TTS alerte terminé

 5.5s  OutputCoordinator → haptic.presence()
       (triple battement doux — "je suis là")
       → Shell mode PASSIVE
```

### Stop total

```
 0.0s  Marie dit "stop"                → InputRouter.route(voice)
       1. bus.publish(cancelAll)
       2. OutputCoordinator.cancelAll() → TTS.stop() + vide queue
       3. feedback "OK"

 0.1s  DescribeAgent reçoit cancelAll  → onTerminate()
       AlertAgent reçoit cancelAll     → reste actif (persistent!)
       → Shell mode PASSIVE
```
