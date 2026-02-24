# Story 1.7: Interfaces domain — Contrats pour le travail parallele

Status: ready-for-dev

## Story

As a **developpeur**,
I want **toutes les interfaces domain definies (AI, I/O, Memory, Plugin, Multi-modal)**,
So that **les agents des Epics 2-5 et 8 peuvent implementer contre ces contrats en parallele**.

## Acceptance Criteria

1. **Given** les core patterns et Drift existent (Stories 1.2, 1.6) **When** les interfaces AI domain sont creees **Then** `features/ai/domain/` contient : `AIProvider` (abstract class avec id, displayName, tier, isAvailable, complete, vision, validateApiKey), `AIRequest`, `AIResponse`, `AIRouter` interface, `RequestClassifier` interface, `ProviderTier` enum

2. **Given** les core patterns existent **When** les interfaces I/O domain sont creees **Then** `features/io/domain/` contient : `CameraService`, `AudioService`, `STTService`, `TTSService`, `HapticService`, `LocationService`, `MotionService` interfaces

3. **Given** les core patterns existent **When** les interfaces Memory domain sont creees **Then** `features/memory/domain/` contient : `MemoryVault` interface (forget, whatDoYouKnow, saveEpisode, getPreference), `MemoryDomain` enum (working, episodic, semantic, relational), `ForgetRequest`, `ConsentEntry`

4. **Given** les core patterns existent **When** les interfaces Plugin domain sont creees **Then** `features/plugins/domain/` contient : `KitaPlugin` (abstract class avec manifest, onActivate, onDeactivate, handleRequest, buildViewport, voiceCommands), `PluginManifest`, `PluginSandbox` interface, `PluginRequest`, `PluginResponse`, `SensorAccess`, `AIAccess`, `MemoryAccess` proxy interfaces, `TrustLevel` enum

5. **Given** les core patterns existent **When** l'interface multi-modal est creee **Then** `shared/multi_modal/` contient : `ProfileAdapter` interface (feedback avec visual/vocal/haptic callbacks)

6. **Given** les core patterns existent **When** l'interface platform bridge est creee **Then** `platform/platform_bridge.dart` contient l'interface `PlatformBridge`

7. **Given** toutes les interfaces sont creees **When** on verifie les imports **Then** aucune interface n'importe de `data/` (regle Clean Architecture)

8. **Given** toutes les interfaces sont creees **When** les mocks partages sont crees **Then** `test/mocks/` contient les mocks implementant chaque interface : `mock_ai_provider.dart`, `mock_camera_service.dart`, `mock_tts_service.dart`, `mock_stt_service.dart`, `mock_haptic_service.dart`, `mock_audio_service.dart`, `mock_location_service.dart`, `mock_motion_service.dart`, `mock_memory_vault.dart`, `mock_plugin_sandbox.dart`, `mock_profile_adapter.dart`

9. **Given** les mocks existent **When** les golden fixtures sont creees **Then** chaque mock retourne des donnees coherentes issues des golden fixtures (`test/fixtures/`)

## Tasks / Subtasks

### Domain AI (AC: #1)

- [ ] **Task 1.1 : Creer `lib/features/ai/domain/provider_tier.dart`** — enum `ProviderTier` avec valeurs `local`, `cloudFast`, `cloudPowerful`
- [ ] **Task 1.2 : Creer `lib/features/ai/domain/ai_request.dart`** — classe `AIRequest` avec champs : `prompt`, `imageData` (optionnel), `priority` (RequestPriority), `context` (Map optionnel), `maxTokens`
- [ ] **Task 1.3 : Creer `lib/features/ai/domain/request_priority.dart`** — enum `RequestPriority` avec valeurs `critical`, `urgent`, `standard`, `background`
- [ ] **Task 1.4 : Creer `lib/features/ai/domain/ai_response.dart`** — classe `AIResponse` avec champs : `content`, `meta` (AIResponseMeta), `status` (AIResponseStatus) ; classe `AIResponseMeta` avec champs : `providerId`, `latency` (Duration), `tier` (ProviderTier), `cached` (bool) ; enum `AIResponseStatus` avec valeurs `success`, `fallback`, `degraded`, `error`
- [ ] **Task 1.5 : Creer `lib/features/ai/domain/ai_provider.dart`** — abstract interface class `AIProvider` avec getters `id`, `displayName`, `tier`, `isAvailable` et methodes `complete(AIRequest)`, `vision(ImageData, String)`, `validateApiKey(String)` retournant `Future<Result<...>>`
- [ ] **Task 1.6 : Creer `lib/features/ai/domain/ai_router.dart`** — abstract interface class `AIRouter` avec methode `route(AIRequest)` retournant `Future<Result<AIResponse>>`
- [ ] **Task 1.7 : Creer `lib/features/ai/domain/request_classifier.dart`** — abstract interface class `RequestClassifier` avec methode `classify(String prompt)` retournant `Result<RequestPriority>`
- [ ] **Task 1.8 : Creer `lib/features/ai/domain/image_data.dart`** — classe `ImageData` (typed holder pour les donnees image passees a vision)

### Domain I/O (AC: #2)

- [ ] **Task 2.1 : Creer `lib/features/io/domain/camera_service.dart`** — abstract interface class `CameraService` avec methodes `capturePhoto()`, `startStream()`, `stopStream()`, `isAvailable`
- [ ] **Task 2.2 : Creer `lib/features/io/domain/audio_service.dart`** — abstract interface class `AudioService` avec methodes `startListening()`, `stopListening()`, `isListening`
- [ ] **Task 2.3 : Creer `lib/features/io/domain/stt_service.dart`** — abstract interface class `STTService` avec methodes `startRecognition()`, `stopRecognition()`, `isAvailable` ; typedef `STTCallback` pour les resultats de transcription
- [ ] **Task 2.4 : Creer `lib/features/io/domain/tts_service.dart`** — abstract interface class `TTSService` avec methodes `speak(String text, {TTSPriority priority})`, `stop()`, `isSpeaking` ; enum `TTSPriority` (critical, urgent, standard)
- [ ] **Task 2.5 : Creer `lib/features/io/domain/haptic_service.dart`** — abstract interface class `HapticService` avec methodes `info()`, `warning()`, `danger()`, `custom(HapticPattern)` ; enum `HapticPattern`
- [ ] **Task 2.6 : Creer `lib/features/io/domain/location_service.dart`** — abstract interface class `LocationService` avec methodes `getCurrentPosition()`, `reverseGeocode(Position)`, `getNearbyPOIs(Position, {double radius})`, `isAvailable`
- [ ] **Task 2.7 : Creer `lib/features/io/domain/motion_service.dart`** — abstract interface class `MotionService` avec methodes `startMonitoring()`, `stopMonitoring()`, `currentState` (MotionState) ; enum `MotionState` (immobile, walking, running)

### Domain Memory (AC: #3)

- [ ] **Task 3.1 : Creer `lib/features/memory/domain/memory_domain.dart`** — enum `MemoryDomain` avec valeurs `working`, `episodic`, `semantic`, `relational`
- [ ] **Task 3.2 : Creer `lib/features/memory/domain/forget_request.dart`** — classe `ForgetRequest` avec champs : `scope` (ForgetScope), `domain` (MemoryDomain optionnel), `before` (DateTime optionnel), `confirmation` (bool) ; enum `ForgetScope` (everything, domain, olderThan, specific)
- [ ] **Task 3.3 : Creer `lib/features/memory/domain/consent_entry.dart`** — classe `ConsentEntry` avec champs : `id`, `domain` (MemoryDomain), `purpose` (String), `grantedAt` (DateTime), `revokedAt` (DateTime optionnel), `dataCategory` (String)
- [ ] **Task 3.4 : Creer `lib/features/memory/domain/episode.dart`** — classe `Episode` avec champs : `id`, `timestamp`, `source`, `summary`, `tags`, `important` (bool), `domain` (MemoryDomain)
- [ ] **Task 3.5 : Creer `lib/features/memory/domain/memory_vault.dart`** — abstract interface class `MemoryVault` avec methodes `forget(ForgetRequest)`, `whatDoYouKnow()`, `saveEpisode(Episode)`, `getPreference(String key)`, `setPreference(String key, String value)`, `getConsents()`, `grantConsent(ConsentEntry)`, `revokeConsent(String consentId)` — toutes retournant `Future<Result<...>>`

### Domain Plugins (AC: #4)

- [ ] **Task 4.1 : Creer `lib/features/plugins/domain/trust_level.dart`** — enum `TrustLevel` avec valeurs `official`, `communityVerified`, `unverified`
- [ ] **Task 4.2 : Creer `lib/features/plugins/domain/plugin_manifest.dart`** — classe `PluginManifest` avec champs : `id` (String, format reverse domain), `name`, `version`, `description`, `trustLevel` (TrustLevel), `permissions` (List<String>), `capabilities` (List<String>), `compatibleProfiles` (List<String>), `voiceCommands` (List<String>)
- [ ] **Task 4.3 : Creer `lib/features/plugins/domain/voice_command.dart`** — classe `VoiceCommand` avec champs : `trigger` (String), `description` (String), `aliases` (List<String>)
- [ ] **Task 4.4 : Creer `lib/features/plugins/domain/plugin_request.dart`** — classe `PluginRequest` avec champs : `command` (String), `params` (Map<String, dynamic>), `sensors` (SensorAccess), `ai` (AIAccess), `memory` (MemoryAccess optionnel)
- [ ] **Task 4.5 : Creer `lib/features/plugins/domain/plugin_response.dart`** — classe `PluginResponse` avec champs : `type` (PluginResponseType), `content` (String), `metadata` (Map<String, dynamic> optionnel), `viewport` (Widget? optionnel — pour le rendu UI specifique au plugin dans le Shell, necessite `import 'package:flutter/widgets.dart'`) ; enum `PluginResponseType` (text, image, alert, rich)
- [ ] **Task 4.6 : Creer `lib/features/plugins/domain/kita_plugin.dart`** — abstract class `KitaPlugin` avec getter `manifest` (PluginManifest), methodes `onActivate()`, `onDeactivate()`, `handleRequest(PluginRequest)` retournant `Future<Result<PluginResponse>>`, `buildViewport(BuildContext)` retournant `Widget?`, getter `voiceCommands` (List<VoiceCommand>)
- [ ] **Task 4.7 : Creer `lib/features/plugins/domain/plugin_sandbox.dart`** — abstract interface class `PluginSandbox` avec methodes `execute(KitaPlugin, PluginRequest)` retournant `Future<Result<PluginResponse>>`, `enforcePermissions(PluginManifest, PluginRequest)` retournant `Result<void>`
- [ ] **Task 4.8 : Creer `lib/features/plugins/domain/sensor_access.dart`** — abstract interface class `SensorAccess` avec methodes `capturePhoto()`, `getCurrentPosition()`, `getMotionState()` — proxy sandbox pour capteurs, retournant `Future<Result<...>>`
- [ ] **Task 4.9 : Creer `lib/features/plugins/domain/ai_access.dart`** — abstract interface class `AIAccess` avec methodes `complete(AIRequest)`, `vision(ImageData, String)` — proxy sandbox pour IA, retournant `Future<Result<...>>`
- [ ] **Task 4.10 : Creer `lib/features/plugins/domain/memory_access.dart`** — abstract interface class `MemoryAccess` avec methodes `saveEpisode(Episode)`, `getPreference(String)`, `setPreference(String, String)` — proxy sandbox pour memoire, retournant `Future<Result<...>>`

### Multi-modal (AC: #5)

- [ ] **Task 5.1 : Creer `lib/shared/multi_modal/profile_adapter.dart`** — abstract interface class `ProfileAdapter` avec methode `feedback({VoidCallback? visual, VoidCallback? vocal, VoidCallback? haptic})` et getter `activeProfile` (String)

### Platform Bridge (AC: #6)

- [ ] **Task 6.1 : Creer `lib/platform/platform_bridge.dart`** — abstract interface class `PlatformBridge` avec methodes `isAccessibilityEnabled()`, `getAccessibilityType()`, `triggerHaptic(HapticPattern)`, `getPlatformInfo()` — abstraction platform-specific retournant `Future<Result<...>>`

### Clean Architecture Verification (AC: #7)

- [ ] **Task 7.1 : Verifier manuellement que AUCUN fichier dans `domain/` n'importe de `data/`** — les seuls imports autorises depuis domain/ sont : `dart:` libraries, `package:flutter/foundation.dart` (pour VoidCallback), `core/errors/` (KitaFailure, Result), et d'autres fichiers domain/ dans la meme feature ou cross-feature

### Mocks partages (AC: #8)

- [ ] **Task 8.1 : Creer `test/mocks/mock_ai_provider.dart`** — classe `MockAIProvider` implementant `AIProvider` avec des reponses en dur issues des fixtures
- [ ] **Task 8.2 : Creer `test/mocks/mock_ai_router.dart`** — classe `MockAIRouter` implementant `AIRouter`
- [ ] **Task 8.3 : Creer `test/mocks/mock_request_classifier.dart`** — classe `MockRequestClassifier` implementant `RequestClassifier`
- [ ] **Task 8.4 : Creer `test/mocks/mock_camera_service.dart`** — classe `MockCameraService` implementant `CameraService`
- [ ] **Task 8.5 : Creer `test/mocks/mock_stt_service.dart`** — classe `MockSTTService` implementant `STTService`
- [ ] **Task 8.6 : Creer `test/mocks/mock_tts_service.dart`** — classe `MockTTSService` implementant `TTSService`
- [ ] **Task 8.7 : Creer `test/mocks/mock_haptic_service.dart`** — classe `MockHapticService` implementant `HapticService`
- [ ] **Task 8.8 : Creer `test/mocks/mock_audio_service.dart`** — classe `MockAudioService` implementant `AudioService`
- [ ] **Task 8.9 : Creer `test/mocks/mock_location_service.dart`** — classe `MockLocationService` implementant `LocationService`
- [ ] **Task 8.10 : Creer `test/mocks/mock_motion_service.dart`** — classe `MockMotionService` implementant `MotionService`
- [ ] **Task 8.11 : Creer `test/mocks/mock_memory_vault.dart`** — classe `MockMemoryVault` implementant `MemoryVault`
- [ ] **Task 8.12 : Creer `test/mocks/mock_plugin_sandbox.dart`** — classe `MockPluginSandbox` implementant `PluginSandbox`
- [ ] **Task 8.13 : Creer `test/mocks/mock_profile_adapter.dart`** — classe `MockProfileAdapter` implementant `ProfileAdapter`
- [ ] **Task 8.14 : Creer `test/mocks/mock_platform_bridge.dart`** — classe `MockPlatformBridge` implementant `PlatformBridge`
- [ ] **Task 8.15 : Creer `test/mocks/mocks.dart`** — barrel file exportant tous les mocks

### Golden Fixtures (AC: #9)

- [ ] **Task 9.1 : Creer `test/fixtures/ai_responses/vision_success.json`** — fixture reponse AI reussie (description d'image)
- [ ] **Task 9.2 : Creer `test/fixtures/ai_responses/vision_fallback.json`** — fixture reponse AI fallback/degradee
- [ ] **Task 9.3 : Creer `test/fixtures/ai_responses/text_success.json`** — fixture reponse AI texte standard
- [ ] **Task 9.4 : Creer `test/fixtures/memory/episode_sample.json`** — fixture episode memoire
- [ ] **Task 9.5 : Creer `test/fixtures/memory/user_profile_sample.json`** — fixture profil utilisateur
- [ ] **Task 9.6 : Creer `test/fixtures/memory/consent_entry_sample.json`** — fixture consentement RGPD
- [ ] **Task 9.7 : Creer `test/fixtures/plugins/valid_manifest.yaml`** — fixture manifest plugin valide (com.kita.describe)
- [ ] **Task 9.8 : Creer `test/fixtures/plugins/invalid_manifest.yaml`** — fixture manifest invalide (permissions manquantes)
- [ ] **Task 9.9 : Creer `test/fixtures/fixture_loader.dart`** — utilitaire pour charger les fixtures JSON/YAML dans les tests

### Tests de compilation (tous ACs)

- [ ] **Task 10.1 : Creer `test/features/ai/domain/interfaces_test.dart`** — test verifiant que toutes les interfaces AI sont importables et que les mocks compilent
- [ ] **Task 10.2 : Creer `test/features/io/domain/interfaces_test.dart`** — test verifiant les interfaces I/O
- [ ] **Task 10.3 : Creer `test/features/memory/domain/interfaces_test.dart`** — test verifiant les interfaces Memory
- [ ] **Task 10.4 : Creer `test/features/plugins/domain/interfaces_test.dart`** — test verifiant les interfaces Plugin
- [ ] **Task 10.5 : Creer `test/shared/multi_modal/profile_adapter_test.dart`** — test verifiant ProfileAdapter
- [ ] **Task 10.6 : Creer `test/platform/platform_bridge_test.dart`** — test verifiant PlatformBridge
- [ ] **Task 10.7 : Verifier `dart analyze` clean** — aucun warning ni erreur sur les nouveaux fichiers
- [ ] **Task 10.8 : Verifier `flutter test` pass** — tous les tests existants + nouveaux passent

## Dev Notes

### Architecture Pattern — abstract interface class

Cette story utilise le pattern Dart 3.x `abstract interface class` pour definir les contrats domain. Ce pattern :
- Empeche l'extension (heritage) en dehors de la library — on ne peut qu'implementer
- Force chaque implementation a fournir TOUTES les methodes du contrat
- Permet la verification exhaustive avec `switch` si combine avec `sealed`

```dart
// Pattern de base pour les interfaces domain
abstract interface class ServiceName {
  Future<Result<ReturnType>> methodName(ParamType param);
}
```

Pour les classes qui DOIVENT etre etendues (comme `KitaPlugin` qui a une structure de base), on utilise `abstract class` simple, pas `abstract interface class`.

### Regle : pourquoi `abstract interface class` vs `abstract class`

| Modificateur | Usage dans Kita | Exemple |
|---|---|---|
| `abstract interface class` | Contrat pur sans implementation — services, repositories, adapters | `AIRouter`, `CameraService`, `MemoryVault`, `ProfileAdapter` |
| `abstract class` | Contrat avec etat ou methodes de base partagees | `KitaPlugin` (a un getter manifest et une structure commune) |
| `enum` | Ensemble fini de valeurs | `ProviderTier`, `MemoryDomain`, `TrustLevel`, `RequestPriority` |
| `class` (final ou non) | Value objects, DTOs | `AIRequest`, `AIResponse`, `PluginManifest`, `Episode` |

### Imports autorises depuis domain/

Les fichiers dans `domain/` ne peuvent importer QUE :
- `dart:async`, `dart:typed_data` (pour Uint8List), `dart:ui` (pour VoidCallback si pas dans foundation)
- `package:flutter/foundation.dart` (pour `VoidCallback`, `@immutable`)
- `package:flutter/widgets.dart` (pour `BuildContext`, `Widget` — requis par `KitaPlugin.buildViewport`)
- `package:kita/core/errors/kita_failure.dart` et `result.dart`
- Autres fichiers `domain/` de la meme feature
- Fichiers `domain/` d'autres features (cross-feature via interface)

Interdit : tout import de `data/`, `presentation/`, packages externes (drift, http, etc.)

### Liste complete des interfaces avec signatures

#### AI Domain (`lib/features/ai/domain/`)

**`provider_tier.dart`:**
```dart
enum ProviderTier { local, cloudFast, cloudPowerful }
```

**`request_priority.dart`:**
```dart
enum RequestPriority { critical, urgent, standard, background }
```

**`image_data.dart`:**
```dart
import 'dart:typed_data';

class ImageData {
  const ImageData({required this.bytes, this.mimeType = 'image/jpeg', this.width, this.height});
  final Uint8List bytes;
  final String mimeType;
  final int? width;
  final int? height;
}
```

**`ai_request.dart`:**
```dart
class AIRequest {
  const AIRequest({
    required this.prompt,
    this.imageData,
    this.priority = RequestPriority.standard,
    this.context = const {},
    this.maxTokens,
  });
  final String prompt;
  final ImageData? imageData;
  final RequestPriority priority;
  final Map<String, dynamic> context;
  final int? maxTokens;
}
```

**`ai_response.dart`:**
```dart
enum AIResponseStatus { success, fallback, degraded, error }

class AIResponseMeta {
  const AIResponseMeta({
    required this.providerId,
    required this.latency,
    required this.tier,
    this.cached = false,
  });
  final String providerId;
  final Duration latency;
  final ProviderTier tier;
  final bool cached;
}

class AIResponse {
  const AIResponse({
    required this.content,
    required this.meta,
    required this.status,
  });
  final String content;
  final AIResponseMeta meta;
  final AIResponseStatus status;
}
```

**`ai_provider.dart`:**
```dart
abstract interface class AIProvider {
  String get id;
  String get displayName;
  ProviderTier get tier;
  bool get isAvailable;
  Future<Result<AIResponse>> complete(AIRequest request);
  Future<Result<AIResponse>> vision(ImageData image, String prompt);
  Future<Result<void>> validateApiKey(String key);
}
```

**`ai_router.dart`:**
```dart
abstract interface class AIRouter {
  Future<Result<AIResponse>> route(AIRequest request);
  List<AIProvider> get availableProviders;
}
```

**`request_classifier.dart`:**
```dart
abstract interface class RequestClassifier {
  Result<RequestPriority> classify(String prompt);
}
```

#### I/O Domain (`lib/features/io/domain/`)

**`camera_service.dart`:**
```dart
abstract interface class CameraService {
  bool get isAvailable;
  Future<Result<ImageData>> capturePhoto();
  Future<Result<void>> startStream(void Function(ImageData frame) onFrame);
  Future<Result<void>> stopStream();
}
```

**`audio_service.dart`:**
```dart
abstract interface class AudioService {
  bool get isListening;
  Future<Result<void>> startListening({void Function(List<int> audioData)? onData});
  Future<Result<void>> stopListening();
}
```

**`stt_service.dart`:**
```dart
typedef STTResultCallback = void Function(String transcript, bool isFinal);

abstract interface class STTService {
  bool get isAvailable;
  bool get isListening;
  Future<Result<void>> startRecognition({required STTResultCallback onResult});
  Future<Result<void>> stopRecognition();
}
```

**`tts_service.dart`:**
```dart
enum TTSPriority { critical, urgent, standard }

abstract interface class TTSService {
  bool get isSpeaking;
  Future<Result<void>> speak(String text, {TTSPriority priority = TTSPriority.standard});
  Future<Result<void>> stop();
}
```

**`haptic_service.dart`:**
```dart
enum HapticPattern { info, warning, danger, confirmation, custom }

abstract interface class HapticService {
  Future<Result<void>> trigger(HapticPattern pattern);
  Future<Result<void>> info();
  Future<Result<void>> warning();
  Future<Result<void>> danger();
}
```

**`location_service.dart`:**
```dart
class Position {
  const Position({required this.latitude, required this.longitude, this.altitude, this.accuracy});
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
}

class GeoAddress {
  const GeoAddress({this.street, this.city, this.country, this.postalCode, this.formattedAddress});
  final String? street;
  final String? city;
  final String? country;
  final String? postalCode;
  final String? formattedAddress;
}

class POI {
  const POI({required this.name, required this.position, this.category, this.distance});
  final String name;
  final Position position;
  final String? category;
  final double? distance;
}

abstract interface class LocationService {
  bool get isAvailable;
  Future<Result<Position>> getCurrentPosition();
  Future<Result<GeoAddress>> reverseGeocode(Position position);
  Future<Result<List<POI>>> getNearbyPOIs(Position position, {double radiusMeters = 500});
}
```

**`motion_service.dart`:**
```dart
enum MotionState { immobile, walking, running }

abstract interface class MotionService {
  MotionState get currentState;
  Future<Result<void>> startMonitoring({void Function(MotionState state)? onStateChanged});
  Future<Result<void>> stopMonitoring();
}
```

#### Memory Domain (`lib/features/memory/domain/`)

**`memory_domain.dart`:**
```dart
enum MemoryDomain { working, episodic, semantic, relational }
```

**`episode.dart`:**
```dart
class Episode {
  const Episode({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.summary,
    this.tags = const [],
    this.important = false,
    this.domain = MemoryDomain.episodic,
  });
  final String id;
  final DateTime timestamp;
  final String source;
  final String summary;
  final List<String> tags;
  final bool important;
  final MemoryDomain domain;
}
```

**`forget_request.dart`:**
```dart
enum ForgetScope { everything, domain, olderThan, specific }

class ForgetRequest {
  const ForgetRequest({
    required this.scope,
    this.domain,
    this.before,
    required this.confirmation,
    this.specificIds = const [],
  });
  final ForgetScope scope;
  final MemoryDomain? domain;
  final DateTime? before;
  final bool confirmation;
  final List<String> specificIds;
}
```

**`consent_entry.dart`:**
```dart
class ConsentEntry {
  const ConsentEntry({
    required this.id,
    required this.domain,
    required this.purpose,
    required this.grantedAt,
    this.revokedAt,
    required this.dataCategory,
  });
  final String id;
  final MemoryDomain domain;
  final String purpose;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String dataCategory;
}
```

**`memory_vault.dart`:**
```dart
abstract interface class MemoryVault {
  Future<Result<void>> forget(ForgetRequest request);
  Future<Result<Map<MemoryDomain, List<String>>>> whatDoYouKnow();
  Future<Result<void>> saveEpisode(Episode episode);
  Future<Result<String?>> getPreference(String key);
  Future<Result<void>> setPreference(String key, String value);
  Future<Result<List<ConsentEntry>>> getConsents();
  Future<Result<void>> grantConsent(ConsentEntry entry);
  Future<Result<void>> revokeConsent(String consentId);
}
```

#### Plugins Domain (`lib/features/plugins/domain/`)

**`trust_level.dart`:**
```dart
enum TrustLevel { official, communityVerified, unverified }
```

**`voice_command.dart`:**
```dart
class VoiceCommand {
  const VoiceCommand({required this.trigger, required this.description, this.aliases = const []});
  final String trigger;
  final String description;
  final List<String> aliases;
}
```

**`plugin_manifest.dart`:**
```dart
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.trustLevel,
    this.permissions = const [],
    this.capabilities = const [],
    this.compatibleProfiles = const [],
    this.voiceCommands = const [],
  });
  final String id;          // reverse domain: "com.kita.describe"
  final String name;
  final String version;
  final String description;
  final TrustLevel trustLevel;
  final List<String> permissions;
  final List<String> capabilities;
  final List<String> compatibleProfiles;
  final List<String> voiceCommands;
}
```

**`plugin_request.dart`:**
```dart
class PluginRequest {
  const PluginRequest({
    required this.command,
    this.params = const {},
    required this.sensors,
    required this.ai,
    this.memory,
  });
  final String command;
  final Map<String, dynamic> params;
  final SensorAccess sensors;
  final AIAccess ai;
  final MemoryAccess? memory;   // null si plugin non verifie
}
```

**`plugin_response.dart`:**
```dart
import 'package:flutter/widgets.dart'; // Requis pour Widget

enum PluginResponseType { text, image, alert, rich }

class PluginResponse {
  const PluginResponse({
    required this.type,
    required this.content,
    this.metadata,
    this.viewport,
  });
  final PluginResponseType type;
  final String content;
  final Map<String, dynamic>? metadata;
  /// Widget custom optionnel pour le rendu UI specifique au plugin dans le Shell.
  /// Conforme a architecture.md (section PluginResponse).
  final Widget? viewport;
}
```

**`kita_plugin.dart`:**
```dart
import 'package:flutter/widgets.dart';

abstract class KitaPlugin {
  PluginManifest get manifest;
  Future<void> onActivate();
  Future<void> onDeactivate();
  Future<Result<PluginResponse>> handleRequest(PluginRequest request);
  Widget? buildViewport(BuildContext context);
  List<VoiceCommand> get voiceCommands;
}
```

**`plugin_sandbox.dart`:**
```dart
abstract interface class PluginSandbox {
  Future<Result<PluginResponse>> execute(KitaPlugin plugin, PluginRequest request);
  Result<void> enforcePermissions(PluginManifest manifest, PluginRequest request);
}
```

**`sensor_access.dart`:**
```dart
abstract interface class SensorAccess {
  Future<Result<ImageData>> capturePhoto();
  Future<Result<Position>> getCurrentPosition();
  Future<Result<MotionState>> getMotionState();
}
```

**`ai_access.dart`:**
```dart
abstract interface class AIAccess {
  Future<Result<AIResponse>> complete(AIRequest request);
  Future<Result<AIResponse>> vision(ImageData image, String prompt);
}
```

**`memory_access.dart`:**
```dart
abstract interface class MemoryAccess {
  Future<Result<void>> saveEpisode(Episode episode);
  Future<Result<String?>> getPreference(String key);
  Future<Result<void>> setPreference(String key, String value);
}
```

#### Multi-modal (`lib/shared/multi_modal/`)

**`profile_adapter.dart`:**
```dart
import 'dart:ui' show VoidCallback;

abstract interface class ProfileAdapter {
  String get activeProfile;
  void feedback({VoidCallback? visual, VoidCallback? vocal, VoidCallback? haptic});
}
```

#### Platform (`lib/platform/`)

**`platform_bridge.dart`:**
```dart
abstract interface class PlatformBridge {
  Future<Result<bool>> isAccessibilityEnabled();
  Future<Result<String>> getAccessibilityType();  // "voiceover", "talkback", "none"
  Future<Result<void>> triggerHaptic(HapticPattern pattern);
  Future<Result<Map<String, dynamic>>> getPlatformInfo();
}
```

### Mock Pattern — Mocks manuels simples

Cette story utilise des **mocks manuels** (pas mocktail/mockito) car :
1. Les interfaces n'ont pas encore d'implementation — on definit les contrats
2. Les mocks servent de documentation vivante des retours attendus
3. Pas de dependance supplementaire a ajouter au projet

Pattern pour chaque mock :
```dart
class MockServiceName implements ServiceName {
  // Champs configurables pour les tests
  bool shouldFail = false;

  @override
  Future<Result<ReturnType>> methodName(ParamType param) async {
    if (shouldFail) return Result.failure(const NetworkFailure('Mock failure'));
    // Retourner des donnees issues des fixtures
    return Result.success(/* fixture data */);
  }
}
```

Les agents E2-E5 peuvent ensuite ajouter `mocktail` pour des mocks plus sophistiques dans leurs propres tests. Les mocks de cette story sont le socle minimal partage.

### Structure des fichiers de fixtures

```
test/fixtures/
├── ai_responses/
│   ├── vision_success.json        # {"content": "A park with...", "providerId": "claude", ...}
│   ├── vision_fallback.json       # {"content": "Image detected", "status": "fallback", ...}
│   └── text_success.json          # {"content": "The weather...", "providerId": "openai", ...}
├── memory/
│   ├── episode_sample.json        # {"id": "ep-001", "source": "plugin.describe", ...}
│   ├── user_profile_sample.json   # {"profile": "blind", "language": "fr", ...}
│   └── consent_entry_sample.json  # {"id": "c-001", "domain": "episodic", ...}
├── plugins/
│   ├── valid_manifest.yaml        # Manifest com.kita.describe complet
│   └── invalid_manifest.yaml      # Manifest avec permissions manquantes
└── fixture_loader.dart            # Helper pour charger les fixtures dans les tests
```

### Cross-feature imports permis

Les interfaces `SensorAccess`, `AIAccess`, `MemoryAccess` dans `features/plugins/domain/` importent des types de `features/ai/domain/` (`AIRequest`, `AIResponse`, `ImageData`), `features/io/domain/` (`Position`, `MotionState`), et `features/memory/domain/` (`Episode`). C'est autorise car ces imports sont uniquement sur des fichiers `domain/` — pas de violation Clean Architecture.

Diagramme d'imports cross-feature autorise :
```
plugins/domain/ --imports--> ai/domain/ (AIRequest, AIResponse, ImageData)
plugins/domain/ --imports--> io/domain/ (Position, MotionState, HapticPattern)
plugins/domain/ --imports--> memory/domain/ (Episode)
io/domain/     --imports--> ai/domain/ (ImageData)  ← CameraService.capturePhoto() retourne Result<ImageData>
platform/       --imports--> io/domain/ (HapticPattern)
shared/multi_modal/ --imports--> (aucun import cross-feature)
```

**Note sur `ImageData` — dependance cross-feature I/O vers AI :**
`CameraService.capturePhoto()` retourne `Future<Result<ImageData>>` mais `ImageData` est defini dans `ai/domain/image_data.dart`. Cela cree une dependance de `io/domain/` vers `ai/domain/`. Deux options :
1. **Option actuelle (import cross-feature)** : `io/domain/camera_service.dart` importe `ai/domain/image_data.dart`. Acceptable car c'est un import domain-to-domain, pas de violation Clean Architecture. Mais cela couple conceptuellement I/O a AI.
2. **Option recommandee (a considerer pour un refactoring futur)** : Deplacer `ImageData` vers `shared/` (ex: `lib/shared/types/image_data.dart`) car c'est un type generique utilise par AI, I/O et Plugins. Cela eliminerait la dependance directionnelle et rendrait `ImageData` un type partage neutre.

Pour cette story, on garde l'option 1 (import cross-feature `io/domain/` -> `ai/domain/`) car c'est ce que l'architecture actuelle prevoit et que deplacer le fichier sortirait du scope. L'agent E3 (I/O) doit etre conscient de cette dependance.

## Technical Intelligence

### Dart 3.x Class Modifiers — Guide pratique

Dart 3 (Dart 3.0+, le projet utilise Dart 3.11) offre des class modifiers qui controlent comment une classe peut etre utilisee en dehors de sa library.

| Modifier | Peut etre construit | Peut etre etendu (extends) | Peut etre implemente (implements) |
|---|---|---|---|
| `class` | oui | oui | oui |
| `abstract class` | non | oui | oui |
| `interface class` | oui | non | oui |
| `abstract interface class` | non | non | oui |
| `base class` | oui | oui | non (hors library) |
| `final class` | oui | non | non (hors library) |
| `sealed class` | non | oui (meme fichier) | non |

**Decision pour Kita :** Utiliser `abstract interface class` pour les contrats de service (AIRouter, CameraService, MemoryVault, etc.) car on veut forcer l'implementation sans permettre l'heritage. Exception : `KitaPlugin` utilise `abstract class` car les plugins doivent pouvoir etendre (partager un constructeur commun).

**Pourquoi pas `sealed` pour les interfaces ?** `sealed` force toutes les implementations dans le meme fichier — impossible pour des contrats implementes par d'autres features/packages.

### Mock libraries — Recommandation

| Library | Version | Code gen | Null-safe | Recommandation |
|---|---|---|---|---|
| `mocktail` | `^1.0.4` | Non | Oui | Recommande pour les tests de feature (E2-E8) |
| `mockito` | `^5.4.5` | Oui (build_runner) | Oui | Alternative si behavior verification complexe |
| Mocks manuels | N/A | Non | Oui | Utilise dans CETTE story pour les mocks de base |

**Decision :** Cette story cree des mocks manuels simples. Les agents E2-E5 pourront ajouter `mocktail` dans leurs tests specifiques s'ils ont besoin de `verify()` et `when()`. Les mocks manuels de cette story restent le socle partage pour les tests d'integration.

### Golden Fixtures — Pattern

Les golden fixtures sont des fichiers JSON/YAML de reference avec des donnees connues et stables. Elles servent de :
- **Source of truth** pour les donnees de test
- **Documentation** des formats attendus
- **Coherence** entre les mocks de differents agents

Le `fixture_loader.dart` utilise `dart:io` pour lire les fichiers de test :
```dart
import 'dart:convert';
import 'dart:io';

class FixtureLoader {
  static String loadString(String relativePath) {
    final file = File('test/fixtures/$relativePath');
    return file.readAsStringSync();
  }

  static Map<String, dynamic> loadJson(String relativePath) {
    return jsonDecode(loadString(relativePath)) as Map<String, dynamic>;
  }
}
```

## Pitfalls & Gotchas

### 1. Import de `package:flutter/widgets.dart` dans domain/

`KitaPlugin.buildViewport()` retourne `Widget?` et prend `BuildContext` — cela oblige un import de `package:flutter/widgets.dart` dans le fichier `kita_plugin.dart`. C'est la SEULE interface domain qui importe Flutter. Les autres interfaces sont en Dart pur. C'est accepte car `KitaPlugin` est par nature un composant Flutter (il produit des widgets).

### 2. `VoidCallback` — import correct

`VoidCallback` est defini dans `dart:ui` et re-exporte par `package:flutter/foundation.dart`. Pour `ProfileAdapter`, preferer `import 'dart:ui' show VoidCallback;` pour minimiser les imports Flutter dans `shared/multi_modal/`.

### 3. Ne PAS utiliser `freezed` pour les interfaces

Les interfaces de cette story sont des fichiers Dart simples — PAS de `@freezed`. `freezed` est pour les value objects immutables dans `data/`. Les interfaces `domain/` sont des contrats abstraits purs.

Les classes de donnees simples comme `AIRequest`, `AIResponse`, `Episode`, `PluginManifest` etc. sont des `class` normales avec `const` constructeurs. Elles peuvent etre converties en `freezed` par les agents E2-E5 si necessaire, mais cette story les definit comme des classes Dart simples pour eviter la dependance a `build_runner` dans les fichiers domain.

### 4. `Result<void>` — pattern pour les methodes sans retour

Beaucoup de methodes retournent `Future<Result<void>>`. Utiliser `Result.success(null)` pour indiquer le succes :
```dart
return const Result.success(null);
```

**Attention :** Le type `Result<void>` fonctionne car `Success<void>` accepte `null` comme valeur. Verifier que `result.dart` existant (Story 1.2) supporte `Success(null)`.

Verification : le `Result<T>` existant dans `core/errors/result.dart` utilise `const factory Result.success(T value) = Success<T>`. Pour `void`, Dart accepte `const Success<void>(null)` car `void` est un supertype de `Null`. Cela fonctionne correctement.

### 5. Pas de generation de code dans cette story

Cette story ne produit AUCUN fichier `.g.dart` ou `.freezed.dart`. Toutes les interfaces et classes sont du Dart pur. `build_runner` n'a pas besoin d'etre execute pour cette story (mais ne doit pas non plus casser si on le lance).

### 6. Nommage des fichiers — un fichier par type principal

Chaque fichier contient un type principal et ses types associes :
- `ai_response.dart` contient `AIResponse`, `AIResponseMeta`, `AIResponseStatus`
- `location_service.dart` contient `LocationService`, `Position`, `GeoAddress`, `POI`
- `plugin_response.dart` contient `PluginResponse`, `PluginResponseType`

Ne PAS creer de fichier barrel (`domain.dart`) dans chaque feature — les imports sont explicites fichier par fichier.

### 7. Cross-feature import direction

Les imports cross-feature dans domain/ vont TOUJOURS dans cette direction :
```
plugins/domain/ --> ai/domain/, io/domain/, memory/domain/
```
Jamais l'inverse. Si `ai/domain/` a besoin d'un type de `plugins/domain/`, c'est un signal d'architecture incorrecte.

### 8. PluginManifest.voiceCommands vs KitaPlugin.voiceCommands — type mismatch intentionnel

`PluginManifest.voiceCommands` est de type `List<String>` alors que `KitaPlugin.voiceCommands` retourne `List<VoiceCommand>`. Ce n'est PAS une erreur :
- **`PluginManifest`** stocke les donnees brutes parsees depuis le YAML (`plugin.kita.yaml`). Les commandes vocales y sont de simples chaines (ex: `["decris", "describe"]`).
- **`KitaPlugin`** hydrate ces chaines en objets `VoiceCommand` types (avec `trigger`, `description`, `aliases`).

Une methode de conversion sera necessaire dans le code de chargement des plugins (Epic 5, data layer) pour transformer les `List<String>` du manifest en `List<VoiceCommand>`. Par exemple :
```dart
// Dans le plugin loader (data layer, hors scope de cette story)
List<VoiceCommand> hydrateVoiceCommands(List<String> rawCommands) {
  return rawCommands.map((cmd) => VoiceCommand(trigger: cmd, description: '')).toList();
}
```
L'agent E5 (Plugins) devra implementer cette conversion.

### 9. Types Position et ImageData — attention aux conflits de nommage

`Position` est defini dans `io/domain/location_service.dart` mais le package `geolocator` definit aussi un `Position`. Comme les fichiers domain/ n'importent PAS de packages externes, il n'y a pas de conflit ici. Mais les implementations dans `data/` devront faire attention aux imports avec `show`/`hide` ou des prefixes (`as geo`).

`ImageData` est defini dans `ai/domain/image_data.dart`. Il n'y a pas de conflit avec d'autres packages car le nom est generique mais on l'importe toujours explicitement.

### 10. `dart:ui` import pour `VoidCallback` — testabilite Dart pur

`ProfileAdapter` utilise `import 'dart:ui' show VoidCallback;` pour obtenir le type `VoidCallback`. Cela rend le fichier **Flutter-only** : il ne peut pas etre teste avec `dart test` pur (sans Flutter), car `dart:ui` n'est disponible que dans l'environnement Flutter.

**Solution recommandee :** Definir un typedef local directement dans le fichier pour eviter la dependance a `dart:ui` :
```dart
// Au lieu de : import 'dart:ui' show VoidCallback;
// Utiliser :
typedef VoidCallback = void Function();
```
Cela rend `profile_adapter.dart` testable avec `dart test` et elimine l'import Flutter. Le typedef est fonctionnellement identique a `dart:ui.VoidCallback`. Si le fichier est deja dans un contexte Flutter (ce qui est le cas pour Kita), les deux approches sont compatibles — mais le typedef local est plus propre et plus portable.

### 11. Egalite des value objects — pas de `==`/`hashCode` par defaut

Les value objects de cette story (`AIRequest`, `AIResponse`, `AIResponseMeta`, `Episode`, `ForgetRequest`, `ConsentEntry`, `PluginManifest`, `PluginRequest`, `PluginResponse`, `VoiceCommand`, `ImageData`, `Position`, `GeoAddress`, `POI`) n'ont PAS de surcharge de `==` ni de `hashCode`.

**Consequence pour les tests :** Les comparaisons par valeur (`expect(a, equals(b))`) ne fonctionneront PAS — deux instances avec les memes champs seront considerees comme differentes (comparaison par reference). Les agents devront :
- Comparer champ par champ dans les assertions (`expect(response.content, equals('expected'))`)
- Ou ajouter `freezed` (qui genere `==`/`hashCode` automatiquement) quand ils implementent la feature
- Ou ajouter manuellement `@override bool operator ==(Object other)` et `@override int get hashCode` si `freezed` n'est pas souhaite

Cette story definit les classes simples volontairement — les agents E2-E5 et E8 ajoutent l'egalite quand necessaire dans le cadre de leur epic.

## Divergences intentionnelles par rapport a architecture.md

Cette story diverge volontairement de `architecture.md` sur deux points. Ces divergences sont des **ameliorations**, pas des contradictions :

### 1. `abstract interface class` au lieu de `abstract class` pour les contrats purs

`architecture.md` definit les interfaces de service avec `abstract class` (ex: `abstract class AIProvider`, `abstract class PluginSandbox`). Cette story utilise `abstract interface class` (Dart 3.x) pour les contrats purs (tout sauf `KitaPlugin`).

**Raison :** `abstract interface class` interdit `extends` en dehors de la library, ce qui force les implementations a utiliser `implements` uniquement. Cela garantit que chaque implementation fournit TOUTES les methodes du contrat sans pouvoir heriter d'une implementation partielle. C'est un renforcement du contrat, pas une modification de l'API.

### 2. `Result<T>` wrapping sur tous les types de retour

`architecture.md` definit les methodes avec des retours directs (ex: `Future<AIResponse> complete(AIRequest request)`). Cette story wrappe tous les retours dans `Result<T>` (ex: `Future<Result<AIResponse>> complete(AIRequest request)`).

**Raison :** Le CLAUDE.md impose `Result<T>` pour la gestion d'erreur (`sealed class KitaFailure + Result<T> — jamais de throw non type`). Le wrapping `Result<T>` rend les erreurs explicites dans la signature et elimine les `throw` non types. Chaque appelant est force de gerer le cas d'erreur.

Ces deux divergences s'appliquent a TOUTES les interfaces de cette story et doivent etre propagees dans les implementations des agents E2-E5 et E8.

## References

- Architecture : `_bmad-output/planning-artifacts/architecture.md` — sections "API & Communication Patterns", "Architectural Boundaries", "Implementation Patterns"
- Epics : `_bmad-output/planning-artifacts/epics.md` — Story 1.7
- Story 1.2 (dependance) : `_bmad-output/implementation-artifacts/1-2-core-patterns-gestion-erreurs-logging.md`
- Story 1.6 (dependance) : `_bmad-output/implementation-artifacts/1-6-infrastructure-drift-sqlcipher.md`
- Dart class modifiers : https://dart.dev/language/class-modifiers
- Dart class modifiers for APIs : https://dart.dev/language/class-modifiers-for-apis
- Mocktail package : https://pub.dev/packages/mocktail
- Effective Dart Design : https://dart.dev/effective-dart/design

## Dev Agent Record

### Agent Model Used

(a remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
