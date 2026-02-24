# Story 7.3 — Integration Gate Phase 3

## Metadata

| Champ | Valeur |
|-------|--------|
| **Story** | 7.3 — Integration Gate Phase 3 |
| **Epic** | E7 — Marie est protegee — Plugin Alert |
| **Priority** | Must (Phase Gate bloquant) |
| **Estimate** | 5 story points |
| **Sprint** | Phase 3 (apres E6 + E7) |
| **Dependencies** | Story 6.1, 6.2, 7.1, 7.2 (toutes mergees sur `develop`) |
| **Phase Gate** | Phase 3 -> 4 |

## Status: review

---

## Description

### Contexte

La Phase 3 du projet Kita comprend deux epics paralleles :
- **E6 (Describe)** : Plugin qui capture une photo et retourne une description vocale (< 5s)
- **E7 (Alert)** : Plugin qui detecte les obstacles via TFLite/YOLO et alerte Marie en < 50ms

Cette story est le **gate de validation Phase 3 -> Phase 4**. Elle valide que les deux plugins fonctionnent de bout en bout, individuellement et ensemble, dans le shell, avec fallbacks, sans crash. C'est le critere de passage avant de lancer Phase 4 (Onboarding + Background).

### Objectif

Ecrire une suite de tests d'integration qui valident :
1. Le flow complet **Describe** : commande "decris" -> capture photo -> ExifStripper -> AIAccess.vision -> TTS -> reponse vocale
2. Le flow complet **Alert** : flux camera -> ObstacleDetector (TFLite mock) -> classification urgence -> alerte multi-modale
3. Le **fallback offline** de Describe : OCR local -> annonce "Mode local, description simplifiee"
4. L'**enchainement naturel** : "decris" -> reponse -> "plus de details" -> reponse enrichie -> "merci" -> retour passif
5. Les **deux plugins charges simultanement** sans crash du shell
6. Le **lifecycle complet** : register -> activate -> use -> deactivate pour les deux plugins

### Patron de reference

Cette story suit le meme patron que **Story 2.8 (Integration Gate Phase 2)**, dont les tests sont dans `test/integration/phase2_integration_gate_test.dart`. Les mocks et patterns de ce fichier servent de base.

---

## Acceptance Criteria

### AC-1 : Test flow Describe E2E
**Given** les Epics 6 et 7 sont merges sur `develop`
**When** le test flow Describe E2E est execute
**Then** la commande "decris" est reconnue par `VoiceCommandHandler`
**And** `SensorAccess.capturePhoto()` est appele et retourne une `ImageData`
**And** `ExifStripper.strip()` retire les metadonnees EXIF de l'image
**And** `AIAccess.vision(image, prompt)` est appele avec l'image nettoyee et retourne une description
**And** le TTS recoit la description a vocaliser
**And** le `PluginResponse` est de type `text` et contient la description
**And** le temps simule du flow est < 5s

### AC-2 : Test flow Alert E2E
**Given** les memes preconditions
**When** le test flow Alert E2E est execute
**Then** le flux camera fournit des frames via `CameraService.startStream()`
**And** l'`ObstacleDetector` mock analyse chaque frame et retourne des detections
**And** les detections sont classifiees par urgence (`immediate` < 3m, `preventive` 3-10m)
**And** une detection `immediate` declenche : vibration danger x3 + voix "Attention ! [type] a [distance] metres"
**And** une detection `preventive` declenche : vibration warning x1 + voix "[type] a [distance] metres"
**And** le `PluginResponse` est de type `alert` et contient le message d'alerte
**And** le `KitaAlert` widget s'affiche avec la bonne severite et le Semantics `liveRegion: true`

### AC-3 : Test fallback Describe offline
**Given** le mock AI cloud retourne un echec (simule hors-ligne)
**When** le flow Describe est execute en mode offline
**Then** le fallback utilise l'OCR local (mock) et retourne une description simplifiee
**And** la reponse contient le texte "Mode local" ou equivalent
**And** le `AIResponseStatus` est `degraded`

### AC-4 : Test enchainement naturel
**Given** le plugin Describe est actif
**When** l'enchainement complet est execute
**Then** "decris" -> capture + description initiale
**And** "plus de details" -> meme image avec prompt enrichi -> description detaillee
**And** "repete" -> relecture TTS de la derniere description
**And** "merci" ou silence 5s -> retour au mode passif (shell mode = `passive`)

### AC-5 : Les deux plugins charges simultanement
**Given** `KitaDescribePlugin` et `KitaAlertPlugin` sont enregistres dans le `PluginRegistryImpl`
**When** les deux sont actives simultanement
**Then** les deux sont accessibles via `getPlugin()`
**And** les `voiceCommands` aggreges contiennent les triggers des deux plugins
**And** le shell rend sans crash avec les deux plugins actifs
**And** chaque plugin peut traiter une requete independamment

### AC-6 : Plugin lifecycle activate/deactivate
**Given** les deux plugins sont enregistres
**When** le lifecycle complet est execute
**Then** `register` -> `activate` -> `handleRequest` -> `deactivate` fonctionne pour Describe
**And** `register` -> `activate` -> `handleRequest` -> `deactivate` fonctionne pour Alert
**And** apres deactivation, `getPlugin()` retourne `null`
**And** les callbacks `onActivate()` et `onDeactivate()` sont appeles
**And** aucun crash du shell pendant toute la sequence

---

## Tasks & Subtasks

### Task 1 : Preparer les mocks Phase 3
- [x] 1.1 Creer `_MockDescribePlugin` qui implemente le flow complet (capture -> strip EXIF -> vision -> response)
- [x] 1.2 Creer `_MockAlertPlugin` qui implemente le flow complet (stream -> detect -> classify -> alert)
- [x] 1.3 Creer `_MockObstacleDetector` qui retourne des detections configurables (type, distance, confiance)
- [x] 1.4 Creer `_MockTTSService` qui enregistre les textes vocalises et les priorites
- [x] 1.5 Creer `_MockHapticService` qui enregistre les patterns declenches
- [x] 1.6 Creer `_MockCameraStreamService` qui simule `startStream()` avec des frames configurables
- [x] 1.7 Etendre `_MockAIAccess` avec un mode offline (retourne failure) et un mode OCR local (retourne description simplifiee)
- [x] 1.8 Creer `_MockExifStripper` (ou reutiliser le vrai `ExifStripper` avec des bytes test)

### Task 2 : Tests flow Describe E2E (AC-1)
- [x] 2.1 Test : commande "decris" reconnue par VoiceCommandHandler
- [x] 2.2 Test : capturePhoto -> ExifStripper -> AIAccess.vision -> PluginResponse.text
- [x] 2.3 Test : TTS recoit la description
- [x] 2.4 Test : le flow complet en < 5s (verification du timing simule)

### Task 3 : Tests flow Alert E2E (AC-2)
- [x] 3.1 Test : obstacle `immediate` (< 3m) -> vibration danger x3 + voix
- [x] 3.2 Test : obstacle `preventive` (3-10m) -> vibration warning x1 + voix
- [x] 3.3 Test : KitaAlert widget rend avec la bonne severite
- [x] 3.4 Test : KitaAlert a `Semantics(liveRegion: true, label: "Alerte : ...")`

### Task 4 : Test fallback Describe offline (AC-3)
- [x] 4.1 Test : AI cloud fails -> fallback OCR local -> description simplifiee
- [x] 4.2 Test : la reponse contient un marqueur "mode local" / "description simplifiee"
- [x] 4.3 Test : le status est `degraded`

### Task 5 : Test enchainement naturel (AC-4)
- [x] 5.1 Test : "decris" -> description initiale
- [x] 5.2 Test : "plus de details" -> description enrichie (meme image, prompt different)
- [x] 5.3 Test : "repete" -> relecture TTS de la derniere description
- [x] 5.4 Test : "merci" -> retour passif

### Task 6 : Test deux plugins simultanes (AC-5)
- [x] 6.1 Test : les deux s'enregistrent et s'activent sans conflit
- [x] 6.2 Test : voiceCommands aggreges contiennent "decris" et le trigger Alert
- [x] 6.3 Test widget : KitaShell rend avec un viewport sans crash quand les deux sont actifs
- [x] 6.4 Test : chaque plugin traite une requete independamment

### Task 7 : Test lifecycle complet (AC-6)
- [x] 7.1 Test : lifecycle Describe (register -> activate -> request -> deactivate)
- [x] 7.2 Test : lifecycle Alert (register -> activate -> request -> deactivate)
- [x] 7.3 Test : deactivation puis reactivation fonctionne
- [x] 7.4 Test : crash dans un plugin n'affecte pas l'autre

### Task 8 : Verification Semantics et accessibilite
- [x] 8.1 Test : KitaAlert a le Semantics liveRegion
- [x] 8.2 Test : bouton "Fermer alerte" a un touch target >= 56x56px
- [x] 8.3 Test : PluginViewport a le Semantics liveRegion
- [x] 8.4 Test : tous les widgets interactifs ont un Semantics label

### Task 9 : Integration finale et clean-up
- [x] 9.1 Verifier que `dart analyze` est clean
- [x] 9.2 Verifier que `flutter test` passe a 100%
- [x] 9.3 Mettre a jour `sprint-status.yaml`

---

## Technical Intelligence

### Patterns de test (reference Phase 2)

Le fichier `test/integration/phase2_integration_gate_test.dart` etablit les patterns suivants :

**1. Mocks inline prives** : Toutes les classes mock sont definies en `_MockXxx` dans le fichier de test, pas dans des fichiers separes. Garder cette convention pour Phase 3.

**2. Pattern PluginRequest avec DI** : Les plugins recoivent leurs dependances (SensorAccess, AIAccess, MemoryAccess) via le `PluginRequest`, pas via injection globale. Ceci facilite le test :

```dart
final response = await plugin.handleRequest(PluginRequest(
  command: 'describe',
  sensors: mockSensors,
  ai: mockAI,
));
```

**3. Pattern Result verification** : Utiliser `expect(result.isSuccess, isTrue)` puis `result.when(success:, failure:)` pour des assertions detaillees.

**4. Widget tests avec MaterialApp** : Wrapper minimal pour les widget tests :

```dart
await tester.pumpWidget(
  MaterialApp(
    home: KitaShell(
      orbState: OrbState.passive,
      viewportChild: PluginViewport(pluginWidget: widget),
    ),
  ),
);
```

### Strategies de mock pour les services natifs

#### Camera mock (pas d'acces materiel en test)

Le `CameraService` est une interface abstraite. En test, mocker avec des `ImageData` synthetiques :

```dart
class _MockCameraService implements CameraService {
  final List<ImageData> frames;
  void Function(ImageData)? _onFrame;
  bool _streaming = false;

  _MockCameraService({required this.frames});

  @override
  bool get isAvailable => true;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    return Result.success(frames.first);
  }

  @override
  Future<Result<void>> startStream(void Function(ImageData) onFrame) async {
    _streaming = true;
    _onFrame = onFrame;
    // Simuler l'emission de frames
    for (final frame in frames) {
      if (!_streaming) break;
      _onFrame?.call(frame);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopStream() async {
    _streaming = false;
    return const Result.success(null);
  }
}
```

**Donnees test minimales** : Utiliser des bytes JPEG synthetiques `[0xFF, 0xD8, 0xFF, 0xE0]` (header JPEG valide). Le `ExifStripper` peut etre utilise en vrai si le package `image` est disponible, sinon mocker.

#### ObstacleDetector mock (pas de TFLite reel en test)

L'`ObstacleDetector` sera implemente dans Story 7.1 avec TFLite. En test d'integration, mocker avec des resultats configures :

```dart
class _MockObstacleDetector {
  List<ObstacleDetection> detectionsToReturn = [];
  int framesAnalyzed = 0;

  Future<List<ObstacleDetection>> analyze(ImageData frame) async {
    framesAnalyzed++;
    return detectionsToReturn;
  }
}

class ObstacleDetection {
  final String type;       // "voiture", "poteau", "trou"
  final double distance;   // en metres
  final double confidence; // 0.0 - 1.0
  final AlertSeverity severity; // immediate ou preventive

  ObstacleDetection({
    required this.type,
    required this.distance,
    required this.confidence,
    required this.severity,
  });
}
```

**Seuils de test** :
- `distance < 3m` et `confidence > 0.8` -> `immediate`
- `distance 3-10m` et `confidence > 0.8` -> `preventive`
- `confidence <= 0.8` -> ignore

#### TTS mock

```dart
class _MockTTSService implements TTSService {
  final List<(String text, TTSPriority priority)> spokenTexts = [];
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<Result<void>> speak(String text, {TTSPriority priority = TTSPriority.standard}) async {
    _speaking = true;
    spokenTexts.add((text, priority));
    _speaking = false;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _speaking = false;
    return const Result.success(null);
  }
}
```

#### Haptic mock

```dart
class _MockHapticService implements HapticService {
  final List<HapticPattern> triggeredPatterns = [];

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    triggeredPatterns.add(pattern);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() async => trigger(HapticPattern.info);
  @override
  Future<Result<void>> warning() async => trigger(HapticPattern.warning);
  @override
  Future<Result<void>> danger() async => trigger(HapticPattern.danger);
}
```

### Gestion du timing et async dans les tests

**Eviter `pumpAndSettle()` avec des animations infinies** : Le `KitaOrb` utilise `AnimationController` avec des animations continues. Utiliser `pump(duration)` au lieu de `pumpAndSettle()` pour eviter les timeouts :

```dart
// NON — risque de timeout
await tester.pumpAndSettle();

// OUI — avancer d'une duree precise
await tester.pump(const Duration(milliseconds: 300));
```

**Animations et `disableAnimations`** : Pour les tests qui ne concernent pas l'animation, injecter un MediaQuery avec `disableAnimations: true` :

```dart
await tester.pumpWidget(
  MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(home: KitaShell(...)),
  ),
);
```

**Async plugins** : Les appels `onActivate()`, `onDeactivate()`, `handleRequest()` sont tous async. Utiliser `await` dans les tests unitaires. Dans les widget tests, utiliser `tester.runAsync()` si necessaire :

```dart
await tester.runAsync(() async {
  await registry.activate('com.kita.describe');
});
```

### Interfaces existantes du projet

| Interface | Fichier | Methodes cles |
|-----------|---------|--------------|
| `KitaPlugin` | `lib/features/plugins/domain/kita_plugin.dart` | `manifest`, `voiceCommands`, `onActivate()`, `onDeactivate()`, `handleRequest()`, `buildViewport()` |
| `PluginRegistryService` | `lib/features/plugins/domain/plugin_registry_service.dart` | `register()`, `activate()`, `deactivate()`, `getPlugin()`, `listPlugins()`, `aggregatedVoiceCommands` |
| `SensorAccess` | `lib/features/plugins/domain/sensor_access.dart` | `capturePhoto()`, `getCurrentPosition()`, `getMotionState()` |
| `AIAccess` | `lib/features/plugins/domain/ai_access.dart` | `complete()`, `vision()` |
| `MemoryAccess` | `lib/features/plugins/domain/memory_access.dart` | `saveEpisode()`, `getPreference()`, `setPreference()` |
| `CameraService` | `lib/features/io/domain/camera_service.dart` | `isAvailable`, `capturePhoto()`, `startStream()`, `stopStream()` |
| `TTSService` | `lib/features/io/domain/tts_service.dart` | `isSpeaking`, `speak()`, `stop()` |
| `HapticService` | `lib/features/io/domain/haptic_service.dart` | `trigger()`, `info()`, `warning()`, `danger()` |
| `PluginSandbox` | `lib/features/plugins/domain/plugin_sandbox.dart` | `execute()`, `enforcePermissions()` |
| `PluginManifest` | `lib/features/plugins/domain/plugin_manifest.dart` | `id`, `name`, `version`, `trustLevel`, `permissions`, `capabilities` |
| `PluginRequest` | `lib/features/plugins/domain/plugin_request.dart` | `command`, `params`, `sensors`, `ai`, `memory` |
| `PluginResponse` | `lib/features/plugins/domain/plugin_response.dart` | `type`, `content`, `metadata`, `viewport` |
| `KitaAlert` | `lib/shared/widgets/kita_alert.dart` | `message`, `severity`, `onDismiss` |
| `PluginViewport` | `lib/features/shell/presentation/plugin_viewport.dart` | `pluginWidget`, `fallbackText` |
| `KitaShell` | `lib/features/shell/presentation/kita_shell.dart` | `mode`, `orbState`, `status`, `viewportChild`, `inputChild` |
| `VoiceCommandHandler` | `lib/features/io/data/voice_command_handler.dart` | `recognize()` — reconnait "decris", "repete", "merci", etc. |
| `ExifStripper` | `lib/features/io/data/exif_stripper.dart` | `strip()` — retire les metadonnees EXIF |

### Manifests des plugins

**Describe** (reference Story 6.1 / Phase 2 mock) :
```dart
const PluginManifest(
  id: 'com.kita.describe',
  name: 'Kita Describe',
  version: '1.0.0',
  description: 'Description vocale de scenes',
  trustLevel: TrustLevel.official,
  permissions: ['sensor.camera', 'ai.vision'],
  capabilities: ['photo_description'],
  compatibleProfiles: ['aveugle', 'standard'],
  voiceCommands: ['decris', 'describe'],
)
```

**Alert** (reference Story 7.2) :
```dart
const PluginManifest(
  id: 'com.kita.alert',
  name: 'Kita Alert',
  version: '1.0.0',
  description: 'Detection obstacles et alertes',
  trustLevel: TrustLevel.official,
  permissions: ['sensor.camera'],
  capabilities: ['obstacle_detection'],
  compatibleProfiles: ['aveugle', 'standard'],
  voiceCommands: [],  // Alert est passif, pas de commande vocale
)
```

### Enums et types cles

```dart
enum AlertSeverity { immediate, preventive }
enum PluginResponseType { text, image, alert, rich }
enum OrbState { passive, listening, processing, responding, error, offline }
enum ShellMode { passive, active }
enum TTSPriority { critical, urgent, standard }
enum HapticPattern { info, warning, danger, confirmation, custom }
enum PluginState { registered, active, inactive }
enum TrustLevel { official, communityVerified, unverified }
```

---

## Pitfalls & Gotchas

### 1. pumpAndSettle() et animations infinies du KitaOrb
Le `KitaOrb` utilise un `AnimationController` avec des animations continues. `pumpAndSettle()` attend que TOUTES les animations soient terminees, donc il va **timeout** (10 min par defaut) avec le KitaOrb.

**Solution** : Utiliser `pump(Duration)` au lieu de `pumpAndSettle()`. Ou injecter `MediaQueryData(disableAnimations: true)` pour forcer les transitions instantanees.

### 2. ExifStripper et bytes synthetiques
Le `ExifStripper` reel utilise le package `image` pour decoder les bytes. Les bytes JPEG minimaux `[0xFF, 0xD8, 0xFF, 0xE0]` ne sont PAS une image decodable complete — le `ExifStripper.strip()` retournera un `Result.failure`.

**Solution** : Soit utiliser une vraie image JPEG minimale encodee en bytes (generer avec `img.encodeJpg(img.Image(width: 1, height: 1))`), soit mocker `ExifStripper` dans les tests d'integration en passant directement l'`ImageData` nettoyee au plugin.

### 3. VoiceCommandHandler est un enum, pas le meme que le domain VoiceCommand
`lib/features/io/data/voice_command_handler.dart` definit un enum `VoiceCommand` (describe, read, stop, help, thanks, repeat). C'est different de la classe `VoiceCommand` dans `lib/features/plugins/domain/voice_command.dart` (trigger, description, aliases). Attention aux imports et aux noms.

**Solution** : Utiliser des imports prefixes : `import '...' as io_vc;` si les deux sont necessaires dans le meme fichier.

### 4. PluginRegistryImpl.maxActivePlugins
Le `PluginRegistryImpl` a une limite configurable de plugins actifs simultanement (`Limits.maxActivePlugins`). Verifier que cette limite est >= 2 pour que les deux plugins puissent etre actifs en meme temps.

**Solution** : Creer le registry avec `PluginRegistryImpl(maxActivePlugins: 5)` dans les tests, ou verifier la valeur de `Limits.maxActivePlugins`.

### 5. Pas de tests sur device reel — tout est mock
Les tests d'integration Phase 3 ne s'executent PAS sur un device reel. Ils tournent dans `flutter test`, pas `flutter test --integration`. La camera, le TFLite, le TTS et l'haptique sont tous mockes.

**Consequence** : Ces tests valident la **logique d'integration** (wiring correct, lifecycle, fallbacks) mais PAS les performances reelles (50ms, 5s). Les tests de performance reelles seront dans Phase 5 (E11).

### 6. Widget buildViewport() et null
`KitaPlugin.buildViewport()` retourne `Widget?`. Le mock Describe de Phase 2 retourne `null`. Pour Phase 3, les mocks doivent retourner de vrais widgets pour tester l'affichage dans `PluginViewport` et `KitaShell`.

### 7. Le PluginRequest n'a pas de champ "stream"
Le `PluginRequest` actuel contient `sensors`, `ai`, `memory` mais pas de mechanism pour le stream camera. Le plugin Alert recevra probablement le flux camera via `SensorAccess` etendu ou un mechanism different. Adapter les mocks en consequence.

**Solution** : Si le `SensorAccess` n'a pas de `startStream()`, le plugin Alert utilisera probablement `CameraService` directement (pas via `SensorAccess`). Verifier l'implementation de Story 7.1/7.2 et adapter.

### 8. Timing test non-deterministe
Les tests async avec `Future.delayed` ou `Stopwatch` peuvent etre flaky. Ne PAS dependre du wall-clock time pour les assertions de latence.

**Solution** : Mocker le timing, utiliser des compteurs d'appels, ou tester que les methodes sont appelees dans le bon ordre plutot que de mesurer le temps reel.

---

## Dev Notes

### Ordre d'implementation requis

Cette story doit etre implementee **APRES** les stories suivantes :
1. **Story 6.1** (KitaDescribePlugin) — le vrai plugin Describe
2. **Story 6.2** (Describe Viewport et enchainement naturel) — viewport, "plus de details", "repete", "merci"
3. **Story 7.1** (ObstacleDetector) — detection TFLite/YOLO
4. **Story 7.2** (KitaAlertPlugin) — alertes multi-modales

L'agent dev de 7.3 doit lire les implementations reelles de ces stories et adapter les mocks/tests en consequence. Les mocks fournis ici sont des **guides** bases sur les interfaces connues — les implementations finales de 6.1/6.2/7.1/7.2 peuvent modifier les contrats.

### Fichier de test

Le fichier de test doit etre cree a :
```
test/integration/phase3_integration_gate_test.dart
```

Suivre la structure du fichier Phase 2 : mocks prives en haut, groupe de tests avec commentaires separateurs.

### Verification de la Phase Gate

Pour que Phase 3 -> 4 soit validee, les criteres sont (cf. `epics.md`) :
- E6 + E7 merges sur `develop`
- Story 7.3 (ce fichier) passe : tous les tests verts
- Flows Describe + Alert E2E OK
- `flutter test` global passe
- `dart analyze` clean

### Pas de modification de fichiers hors perimetre

Cette story ne cree QUE le fichier de test. Elle ne modifie PAS :
- `core/`, `pubspec.yaml`, `database.dart` (propriete E1)
- Les fichiers des plugins (propriete E6/E7)
- Les fichiers du shell (propriete E8)

---

## Test Scenarios detailles

### Scenario 1 : Describe flow E2E

**Preconditions** : Mocks SensorAccess, AIAccess, TTSService prets.

```
1. VoiceCommandHandler.recognize("decris") -> Result.success(VoiceCommand.describe)
2. _MockDescribePlugin.handleRequest(PluginRequest(command: "describe", sensors: mock, ai: mock))
   2a. sensors.capturePhoto() -> Result.success(ImageData(bytes: jpegBytes))
   2b. ExifStripper.strip(imageData) -> Result.success(cleanImageData)
   2c. ai.vision(cleanImageData, "Decris cette scene") -> Result.success(AIResponse(content: "Un parc avec..."))
3. PluginResponse(type: text, content: "Un parc avec...")
4. TTS.speak("Un parc avec...", priority: standard)
```

**Assertions** :
- `sensors.capturePhotoCalled == true`
- `response.type == PluginResponseType.text`
- `response.content` contient une description
- `tts.spokenTexts.length == 1`
- `tts.spokenTexts.first.$1` contient la description

### Scenario 2 : Alert flow E2E

**Preconditions** : Mocks CameraService, ObstacleDetector, TTSService, HapticService prets.

```
1. CameraService.startStream(onFrame) -> emmet des frames
2. Pour chaque frame : ObstacleDetector.analyze(frame)
   -> [ObstacleDetection(type: "voiture", distance: 2.0, confidence: 0.95, severity: immediate)]
3. _MockAlertPlugin.handleRequest(...)
   3a. Detection immediate : haptic.danger() x3 + tts.speak("Attention ! Voiture a 2 metres", priority: critical)
   3b. Detection preventive : haptic.warning() x1 + tts.speak("Poteau a 8 metres", priority: urgent)
4. PluginResponse(type: alert, content: "Attention ! Voiture a 2 metres")
```

**Assertions** :
- `haptic.triggeredPatterns` contient `HapticPattern.danger` (immediate) ou `HapticPattern.warning` (preventive)
- `tts.spokenTexts` contient le message d'alerte avec le bon `TTSPriority`
- `response.type == PluginResponseType.alert`

### Scenario 3 : Describe fallback offline

```
1. _MockAIAccess.vision() -> Result.failure(NetworkFailure.noConnection())
2. Plugin Describe detecte l'echec -> bascule sur OCR local (mock)
3. OCR local retourne "Texte detecte : Sortie de secours"
4. Reponse : "Mode local, description simplifiee : Texte detecte : Sortie de secours"
```

**Assertions** :
- Le fallback est transparent (pas de crash)
- La reponse contient un indicateur "mode local" ou "simplifiee"
- Le statut est `degraded`

### Scenario 4 : Enchainement naturel

```
1. "decris" -> description initiale "Un parc avec des arbres"
2. "plus de details" -> meme image, prompt enrichi -> "Un parc verdoyant avec 3 grands chenes..."
3. "repete" -> TTS relit "Un parc verdoyant avec 3 grands chenes..."
4. "merci" -> retour mode passif
```

**Assertions** :
- Etape 2 : ai.vision() appele avec le meme ImageData mais prompt different
- Etape 3 : tts.speak() appele avec la derniere description (pas une nouvelle requete AI)
- Etape 4 : l'etat du plugin indique retour passif

### Scenario 5 : Deux plugins simultanes

```
1. registry.register(describePlugin) -> success
2. registry.register(alertPlugin) -> success
3. registry.activate('com.kita.describe') -> success
4. registry.activate('com.kita.alert') -> success
5. registry.getPlugin('com.kita.describe') != null
6. registry.getPlugin('com.kita.alert') != null
7. registry.aggregatedVoiceCommands contient les commandes des deux
8. Widget test : KitaShell rend avec viewportChild sans crash
```

### Scenario 6 : Lifecycle et stabilite shell

```
1. Register Describe + Alert
2. Activate both
3. Execute une requete Describe -> success
4. Execute une requete Alert -> success
5. Deactivate Describe -> success, Alert reste actif
6. Deactivate Alert -> success
7. getPlugin() retourne null pour les deux
8. Widget test : KitaShell ne crash PAS pendant toute la sequence
9. Reactivate les deux -> success (test du cycle complet)
```

---

## Ressources web consultees

- [Flutter Testing Overview](https://docs.flutter.dev/testing/overview) — structure des tests unit/widget/integration
- [Plugins in Flutter Tests](https://docs.flutter.dev/testing/plugins-in-tests) — strategies de mock pour plugins natifs
- [Flutter Integration Tests](https://docs.flutter.dev/testing/integration-tests) — runner integration_test
- [pumpAndSettle API](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html) — timeout 10min, risque avec animations infinies
- [Accessibility Testing Flutter](https://docs.flutter.dev/ui/accessibility/accessibility-testing) — Semantics matchers, guideline API
- [Riverpod pumpAndSettle timeout discussion](https://github.com/rrousselGit/riverpod/discussions/453) — workaround pour tests avec Riverpod

---

## File List

_(A remplir par l'agent dev)_

### Files Created
| File | Description |
|------|-------------|
| `test/integration/phase3_integration_gate_test.dart` | Tests d'integration gate Phase 3 |

### Files Modified
| File | Description |
|------|-------------|
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | Mise a jour statut story 7.3 |

---

## Dev Agent Record

| Champ | Valeur |
|-------|--------|
| Agent | E7-Alert (claude-opus-4-6) |
| Start | 2026-02-24 |
| End | 2026-02-24 |
| Status | review |
| Tests | 36/36 passing (987 total project tests) |
| dart analyze | Clean (0 issues) |
| Blockers | None — all dependencies completed |

---

## Change Log

| Date | Auteur | Changement |
|------|--------|-----------|
| 2026-02-24 | Scrum Master (Claude) | Creation du story file enrichi |
| 2026-02-24 | E7-Alert (claude-opus-4-6) | Implementation complete: 36 integration tests covering AC-1 through AC-6. Tests use real KitaDescribePlugin and KitaAlertPlugin with mocked services (AIAccess, SensorAccess, TTSService, HapticService, ProfileAdapter). Covers: Describe E2E flow, Alert E2E flow, offline fallback, natural chaining (decris/plus de details/repete/merci/silence timeout), two plugins simultaneously in PluginRegistry, full lifecycle (register/activate/request/deactivate/reactivate), Semantics liveRegion verification, touch target 56x56, zero PII logging. |
