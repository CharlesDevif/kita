---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-02-23'
inputDocuments:
  - prd.md
  - prd-validation-report.md
  - product-brief-kita-2026-02-19.md
  - ux-design-specification.md
  - kita-architecture-party-mode-2026-02-19.md
workflowType: 'architecture'
project_name: 'kita'
user_name: 'Charles'
date: '2026-02-23'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (46 FRs, 7 domaines) :**

| Domaine | FRs | Implications architecturales |
|---------|-----|------------------------------|
| AI & Intelligence | 6 | AI Router 3 tiers, RequestClassifier, Fallback Chain never-fail, interface provider abstraite |
| Perception & Capteurs | 7 | Camera Service multi-mode, AudioMultiplexer, STT/GPS/accelerometre, mode passif permanent |
| Communication & Sortie | 6 | TTS avec file de priorite, HapticService 3 patterns, commandes vocales naturelles, interface texte equivalente |
| Memoire & Donnees | 7 | DB locale chiffree, 4 domaines memoire, MemoryVault (consent, forget, transparency), nettoyage auto |
| Plugin System | 7 | Interface KitaPlugin abstraite, manifest YAML, PluginSandbox, 3 niveaux confiance, chargement dynamique |
| Onboarding & Config | 8 | Vocal-first < 3 min, detection VoiceOver/TalkBack, packs auto, Permission Storytelling, BYOK, mode aidant |
| Securite & Vie Privee | 5 | Local-first, strict minimum cloud, strip EXIF, zero tracking, mode offline complet |

**Non-Functional Requirements (30 NFRs, 6 domaines) :**

| Domaine | NFRs | Contraintes cles |
|---------|------|-----------------|
| Performance | 7 | Alertes < 50ms, description < 5s, TTS < 100ms, STT < 200ms, cold start < 3s, batterie < 5%/h, RAM < 200MB |
| Securite | 6 | AES-256, zero PII dans logs, Keychain/Keystore, strip EXIF, RGPD Art.9, effacement verifiable |
| Accessibilite | 6 | WCAG 2.1 AA+, VoiceOver/TalkBack 100%, contraste 4.5:1+, labels 100%, navigation vocal-only |
| Fiabilite | 5 | 0 crash flows critiques, fallback 100%, offline critique 100%, stabilite 24h+, recovery < 10s |
| Integration | 3 | 2 dernieres versions API providers, interface plugin retrocompatible, ML Kit/CoreML stables |
| Testabilite | 3 | Couverture > 80%, tests a11y CI bloquants, 3 Android + 2 iOS reels |

**UX Architecture (Living Aura) :**

- Shell constant (header + orbe + input) + plugin viewport variable
- KitaOrb : widget anime signature (6 etats visuels), CustomPainter + AnimationController
- 9 composants custom : KitaShell, KitaOrb, KitaInput, KitaAlert, KitaPermissionCard, KitaStatusIndicator, PluginViewport, KitaFeedbackBubble, TranscriptionBubble
- Mix framework (utility-first styling) + couche multi-modale custom
- ProfileAdapter : routage dynamique des outputs par profil (aveugle, sourd, standard, aidant)

**Scale & Complexity :**

- Domaine primaire : Mobile cross-platform (Flutter + natif Swift/Kotlin)
- Niveau de complexite : Haute
- Composants architecturaux estimes : ~15 modules principaux
- Contexte : Greenfield — aucun code existant

### Technical Constraints & Dependencies

**Contraintes dures (non negociables) :**

1. **Latence alertes critiques < 50ms** — Impose le traitement 100% local pour les requetes critiques. Aucune dependance cloud sur le chemin critique.
2. **Fallback chain never-fail** — Les requetes critiques ne retournent JAMAIS d'erreur. Dernier recours = alerte brute sonore.
3. **Chiffrement AES-256 au repos** — Toutes les donnees locales chiffrees. Cles API dans Keychain (iOS) / Keystore (Android).
4. **RGPD Article 9** — Donnees de handicap = donnees sensibles. Consentement explicite, droit a l'oubli verifiable, zero transfert non anonymise.
5. **WCAG 2.1 AAA** — Standard le plus eleve. VoiceOver/TalkBack 100%. Tests a11y bloquants en CI.
6. **Battery < 5%/h en mode passif** — Capteurs adaptatifs, FPS adaptatif, capteurs off si immobile.
7. **Android 12+ / iOS 16+** — Plateformes cibles minimum.

**Dependencies technologiques (mises a jour post-recherche) :**

| Technologie | Usage | Statut 2026 | Risque |
|-------------|-------|-------------|--------|
| Flutter 3.38+ | Framework cross-platform | Stable, iOS 26 / Xcode 26 supportes | Faible |
| Riverpod 3.0 | State management | Mutations, auto-retry, offline caching | Faible |
| ~~Isar~~ | ~~DB locale chiffree~~ | ~~Abandonne par l'auteur~~ | ~~Critique~~ |
| **Drift + SQLCipher** | DB locale chiffree (remplacement Isar) | Mature, type-safe, SQL, bien maintenu | Faible |
| ML Kit (Android) | IA locale, OCR | Google-maintained, GenAI via Gemini Nano | Faible |
| CoreML (iOS) | IA locale | Apple-maintained, Foundation Models iOS 26+ | Faible |
| TFLite + YOLO | Detection obstacles temps reel | 30 FPS, modeles ~6MB, quantization | Faible |
| Mix | Styling utility-first | Actif juillet 2025, plan B = ThemeExtension | Moyen |
| anthropic_sdk_dart | SDK Claude pour Dart | Communautaire, Claude 4.5 supporte | Moyen |
| dart_openai | SDK OpenAI pour Dart | Communautaire, mature | Faible |
| flutter_background_service | Service arriere-plan | Mature Android, iOS tres restrictif | Moyen |
| speech_to_text / flutter_tts | STT et TTS locaux | Packages standards Flutter | Faible |

**Alerte technologique — Isar abandonne :**

Le PRD et le brainstorming mentionnent Isar (chiffrement AES-256) comme DB locale. La recherche web (fevrier 2026) revele que Isar a ete **abandonne par son createur** et n'est plus recommande pour les nouveaux projets. L'architecture doit utiliser une alternative : **Drift + SQLCipher** (SQL, type-safe, chiffrement, bien maintenu) est la recommandation.

**Decouverte — flutter_local_ai :**

Nouveau package qui wrappe les API IA natives des OS (Apple Foundation Models iOS 26+, ML Kit GenAI/Gemini Nano Android). Zero telechargement de modele. Pas utilisable pour le MVP (iOS 16+ requis) mais pertinent pour la roadmap.

### Cross-Cutting Concerns Identified

| Concern | Impact | Composants affectes |
|---------|--------|-------------------|
| **Multi-modal output** | Chaque output existe en 3 modalites (visuel, vocal, haptique). Le ProfileAdapter traverse tous les composants. | Tous les composants UI, plugins, alertes, onboarding |
| **Accessibilite** | Semantics API sur chaque widget, VoiceOver/TalkBack, navigation vocal-only, contraste AAA. | Tous les composants UI, tests, CI/CD |
| **Securite & Vie privee** | Chiffrement, consentement, strip EXIF, local-first, zero tracking. | Storage, AI Router, plugins, cloud requests |
| **Offline capability** | Fallback chain, fonctions critiques 100% locales, bascule transparente. | AI Router, plugins, storage, UI (indicateurs d'etat) |
| **Plugin isolation** | Sandbox, permissions enforced, quotas, isolation erreurs, 3 niveaux confiance. | Plugin System, AI Router, I/O Layer, Storage |
| **Gestion batterie** | FPS adaptatif, capteurs conditionnels, background service optimise. | I/O Layer, mode passif, service arriere-plan |
| **Error handling never-fail** | Chemin critique sans erreur possible, fallback en cascade, alerte brute. | AI Router, Fallback Chain, alertes, plugins |
| **Platform abstraction** | Background service Android (Foreground Service) vs iOS (Background Audio + Location). Architecture differente par plateforme. | Service arriere-plan, mode passif, gestion capteurs |

## Starter Template Evaluation

### Primary Technology Domain

Application mobile cross-platform Flutter + modules natifs Swift/Kotlin, architecture feature-first + clean architecture avec Riverpod 3.0 pour le state management.

### Starter Options Considered

| Option | Starter | Verdict | Raison |
|--------|---------|---------|--------|
| A | Very Good CLI | Rejete | Bloc (pas Riverpod), Material 3 (pas Mix), trop opinionated |
| B | Templates Riverpod GitHub | Rejete | Material 3, pas de Mix/multi-modal/plugin system |
| C | `flutter create` + structure custom | **Selectionne** | Table rase, chaque brique ajoutee intentionnellement |

### Selected Starter: flutter create + structure custom

**Rationale for Selection:**

L'architecture Kita est trop specifique pour un template existant. La combinaison Mix + Riverpod 3.0 + multi-modal output + plugin system + Drift chiffre + background service natif n'existe dans aucun starter. Partir d'une base propre garantit que chaque decision architecturale est intentionnelle et documentee.

**Initialization Command:**

```bash
flutter create --org com.kita --platforms android,ios kita
```

### Architectural Decisions Provided by Starter

**Language & Runtime:**

- Dart 3.x (null safety, records, patterns)
- Modules natifs : Swift 5+ (iOS), Kotlin 1.9+ (Android)
- Platform channels pour la communication Flutter <-> natif

**Styling Solution:**

- Mix framework (utility-first, design tokens, variants, modifiers)
- Couche KitaMultiModal custom (VoiceFeedback, HapticFeedback, ProfileAdapter)
- Pas de Material 3 — composants custom construits sur primitives Flutter + Mix

**State Management:**

- Riverpod 3.0 (Mutations, auto-retry, offline caching)
- Providers typesafe, compile-time validation

**Build Tooling:**

- Flutter build system standard
- Flavors : dev / staging / prod (configures manuellement)
- CI/CD : GitHub Actions (tests, lint, a11y, build)

**Testing Framework:**

- flutter_test (unit + widget tests)
- integration_test (tests E2E)
- Tests accessibilite Semantics bloquants en CI
- Couverture > 80% cible

**Code Organization:**

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + KitaTheme + routing
├── core/                       # DI, config, errors, utils, design tokens
│   ├── di/                     # Riverpod providers globaux
│   ├── config/                 # Configuration app, constantes
│   ├── errors/                 # Failure types, error handling
│   ├── theme/                  # Mix tokens, KitaTheme, MultiModalTokens
│   └── utils/                  # Extensions, helpers
├── features/
│   ├── ai/                     # AI Router, providers, classifier, fallback
│   │   ├── domain/             # AIRequest, AIResponse, AIProvider interface
│   │   ├── data/               # Claude, OpenAI, local providers
│   │   └── presentation/      # (pas d'UI propre)
│   ├── io/                     # Camera, audio, haptic, location, motion
│   │   ├── domain/             # IOService interface, events
│   │   ├── data/               # Platform-specific implementations
│   │   └── presentation/      # (pas d'UI propre)
│   ├── memory/                 # Drift store, collections, vault
│   │   ├── domain/             # MemoryVault, ForgetRequest, MemoryDomain
│   │   ├── data/               # Drift DAOs, SQLCipher config
│   │   └── presentation/      # (pas d'UI propre)
│   ├── plugins/                # Plugin interface, registry, sandbox
│   │   ├── domain/             # KitaPlugin, PluginManifest, PluginSandbox
│   │   ├── data/               # Plugin loading, YAML parsing
│   │   ├── presentation/      # PluginViewport
│   │   └── built_in/          # describe/, alert/
│   ├── onboarding/             # Flow complet, detection accessibilite
│   │   ├── domain/             # OnboardingState, ProfileDetection
│   │   ├── data/               # System accessibility detection
│   │   └── presentation/      # Ecrans onboarding, PermissionCards
│   ├── shell/                  # Ecran principal, Living Aura
│   │   └── presentation/      # KitaShell, KitaOrb, KitaInput
│   └── settings/               # Preferences, profil, forget
├── shared/                     # Composants partages
│   ├── widgets/                # KitaAlert, KitaFeedbackBubble, etc.
│   └── multi_modal/           # ProfileAdapter, VoiceFeedback, HapticFeedback
├── platform/                   # Code natif bridge
│   ├── ios/                    # Swift method channels
│   └── android/                # Kotlin method channels
```

**Development Experience:**

- Hot reload Flutter standard
- Dart DevTools pour profiling
- Flutter Inspector pour debug UI
- Lint rules strictes (flutter_lints + custom)

**Note:** L'initialisation du projet avec cette commande et la mise en place de la structure sera la premiere story d'implementation.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (bloquent l'implementation) :**

1. DB locale : Drift + SQLCipher (remplace Isar abandonne)
2. AI Router 3 tiers avec Fallback Chain never-fail
3. Plugin System : KitaPlugin interface + PluginSandbox
4. Multi-modal output : ProfileAdapter + 3 modalites
5. Background service : abstraction platform-specific (Android Foreground Service / iOS Background Audio + Location)

**Important Decisions (structurent l'architecture) :**

6. Routing : go_router (navigation minimale)
7. Stockage securise : flutter_secure_storage (Keychain/Keystore)
8. Error handling : never-fail pattern avec cascade
9. CI/CD : GitHub Actions avec tests a11y bloquants
10. Crash reporting : Sentry (opt-in)

**Decisions differees (post-MVP) :**

11. Cache par similarite semantique
12. Plugin marketplace
13. Kita Cloud (proxy API)
14. Multi-appareils (BLE, lunettes)
15. flutter_local_ai (requiert iOS 26+)
16. Profils vocaux / reconnaissance locuteurs

### Data Architecture

**Database : Drift + SQLCipher**

| Aspect | Decision |
|--------|----------|
| Technologie | Drift (ORM SQLite) + SQLCipher (chiffrement AES-256) |
| Rationale | Isar abandonne par l'auteur. Drift est type-safe, bien maintenu, SQL, migrations automatiques. SQLCipher ajoute le chiffrement transparent. |
| Affecte | Memory, plugins, profil, cache |

**Modelisation des donnees :**

| Domaine | Persistence | Table Drift | Contenu |
|---------|-------------|-------------|---------|
| Working | RAM (Riverpod state) | — | Conversation en cours, contexte actuel |
| Episodic | 30 jours | `episodes` | Evenements horodates, tags auto, resume IA |
| Semantic | Permanent | `preferences` | Cle-valeur categorise, score confiance |
| Relational | Permanent | `persons` | Graphe social, relation, interets, notes |
| Profile | Permanent | `user_profile` | Config, profil accessibilite, providers |
| Plugin data | Par plugin | `plugin_data` | Namespace par plugin_id, sandboxed |
| Cache | TTL variable | `request_cache` | Reponses IA cachees par RequestClassifier |
| Consent | Permanent | `consent_log` | Historique consentements RGPD, verifiable |

**Strategie de cache :**

| Type requete | Cache | TTL |
|-------------|-------|-----|
| Critical | Jamais (toujours frais) | — |
| Urgent | Cache court | 30s |
| Standard | Cache medium | 5 min |
| Background | Cache long | 1h |

### Securite & Authentification

**Pas d'authentification traditionnelle** — Kita est local-first, pas de backend, pas de comptes utilisateur.

**Stockage securise des cles API :**

| Donnee | Stockage | Methode |
|--------|----------|---------|
| Cles API providers (Claude, OpenAI) | Keychain (iOS) / Keystore (Android) | flutter_secure_storage |
| Profil utilisateur + preferences | Drift + SQLCipher | Chiffrement DB entiere |
| Donnees sensibles (handicap) | Drift + SQLCipher | Meme DB, consentement RGPD trace |

**Securite des requetes cloud :**

- Strip EXIF avant envoi (package `image` ou natif)
- Jamais de profil utilisateur dans les requetes IA
- Timeout agressif (3s par tier)
- HTTPS only
- Pas de retry sur donnees sensibles

**Plugin Sandbox — modele de securite :**

| Niveau | Acces | Controle |
|--------|-------|----------|
| Officiel | Tous capteurs declares, IA, memoire partagee | Audit complet |
| Communautaire verifie | Capteurs declares, IA, memoire sandboxed | Code review |
| Non verifie | Capteurs declares uniquement, IA limitee, pas de memoire | Warning utilisateur, sandbox renforce |

### API & Communication Patterns

**AI Provider Interface :**

```dart
abstract class AIProvider {
  String get id;
  String get displayName;
  ProviderTier get tier;          // local, cloudFast, cloudPowerful
  bool get isAvailable;
  Future<AIResponse> complete(AIRequest request);
  Future<AIResponse> vision(ImageData image, String prompt);
  Future<void> validateApiKey(String key);
}
```

**Plugin Interface :**

```dart
abstract class KitaPlugin {
  PluginManifest get manifest;
  Future<void> onActivate();
  Future<void> onDeactivate();
  Future<PluginResponse> handleRequest(PluginRequest request);
  Widget? buildViewport(BuildContext context);
  List<VoiceCommand> get voiceCommands;
}
```

**Platform Channels :**

| Channel | Direction | Usage |
|---------|-----------|-------|
| `com.kita/haptic` | Flutter -> natif | HapticAdapter (iOS UIImpactFeedback / Android VibrationEffect) |
| `com.kita/camera` | Bidirectionnel | CameraService modes (capture, stream, triggered) |
| `com.kita/secure_storage` | Flutter -> natif | Keychain/Keystore |
| `com.kita/background` | Bidirectionnel | Background service management |
| `com.kita/accessibility` | Natif -> Flutter | VoiceOver/TalkBack detection |

**Error Handling — Never-Fail Pattern :**

```
Requete -> RequestClassifier -> AIRouter
  |-- cloud-powerful (timeout 3s) -> succes -> reponse
  |-- cloud-fast (timeout 3s) -> succes -> reponse
  |-- local (ML Kit/CoreML) -> succes -> reponse (degradee)
  '-- alerte brute -> succes GARANTI -> reponse minimale
```

Chaque niveau catch ses erreurs et cascade. Le dernier niveau (alerte brute) ne peut PAS echouer — son/vibration hardcode.

### Frontend Architecture

**Routing : go_router**

| Route | Ecran | Usage |
|-------|-------|-------|
| `/` | KitaShell (Living Aura) | Ecran principal — 95% du temps |
| `/onboarding` | OnboardingFlow | Premier lancement |
| `/settings` | SettingsScreen | Preferences, profil, plugins |
| `/settings/plugins` | PluginManager | Gestion plugins |
| `/settings/memory` | MemoryView | "Qu'est-ce que tu sais sur moi" |
| `/settings/forget` | ForgetScreen | Droit a l'oubli |

Navigation minimale — Kita est conversation-first, pas menu-first.

**Architecture des composants :**

Chaque composant custom suit :
1. Widget Flutter standalone style avec Mix
2. Multi-modal integre via ProfileAdapter (injecte par Riverpod)
3. Semantics wrapper obligatoire (lint rule custom)
4. Tests unitaires + tests a11y

**Performance animations :**

- KitaOrb : CustomPainter + AnimationController, 60fps
- `prefers-reduced-motion` -> transitions instantanees
- Durees : micro 150ms, transitions 300ms, etats 500ms
- Isolate dedie pour le traitement d'image (pas de jank UI)

### Infrastructure & Deploiement

**CI/CD : GitHub Actions**

| Etape | Outil | Bloquant |
|-------|-------|----------|
| Lint | `dart analyze` + rules custom | Oui |
| Tests unitaires | `flutter test` | Oui |
| Tests a11y | Semantics matchers | Oui |
| Couverture | `flutter test --coverage` (>80%) | Oui |
| Build Android | `flutter build apk/appbundle` | — |
| Build iOS | `flutter build ipa` | — |
| Deploiement | Fastlane (stores) | Manuel |

**Monitoring :**

| Aspect | Outil | Consentement |
|--------|-------|-------------|
| Crash reporting | Sentry (open source, self-host possible) | Opt-in |
| Analytics | Aucun au MVP — pas de tracking | — |
| Performance | Monitoring batterie/RAM in-app | Automatique local |

**Open Source :**

- License : MIT
- Repo : GitHub public
- Contribution : PR + code review
- Plugin SDK : package pub.dev (post-MVP)

### Decision Impact Analysis

**Sequence d'implementation :**

1. Projet Flutter + structure feature-first + Riverpod 3.0 + Mix + go_router
2. Drift + SQLCipher — schema initial (user_profile, preferences, consent_log)
3. AI Router + interface AIProvider + premier provider (Claude)
4. I/O Layer — STT/TTS + CameraService (capture unique) + HapticService
5. Plugin System — KitaPlugin interface + PluginSandbox + PluginRegistry
6. Plugin Describe — photo -> description vocale
7. Plugin Alert — detection obstacles locale (TFLite/YOLO)
8. Shell Living Aura — KitaShell + KitaOrb + KitaInput + PluginViewport
9. Onboarding — detection accessibilite + Permission Storytelling + packs
10. Multi-modal — ProfileAdapter + VoiceFeedback + HapticFeedback
11. Background service — mode passif (Android Foreground Service / iOS Background Audio)
12. Tests + CI/CD + polish

**Cross-Component Dependencies :**

| Composant | Depend de |
|-----------|-----------|
| Plugin Describe | AI Router, CameraService, TTS, PluginSandbox |
| Plugin Alert | CameraService, TFLite/YOLO, HapticService, TTS |
| KitaShell | KitaOrb, KitaInput, PluginViewport, ProfileAdapter |
| Onboarding | ProfileDetection, PermissionCards, PluginRegistry, TTS |
| AI Router | AIProvider implementations, RequestClassifier, Drift (cache) |
| MemoryVault | Drift + SQLCipher, ConsentLog |
| Background Service | I/O Layer, Platform Channels, Battery Monitor |
| ProfileAdapter | Riverpod (profil actif), VoiceFeedback, HapticFeedback, UI |

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Points de conflit potentiels identifies :** 8 categories ou les agents IA pourraient prendre des decisions differentes si non specifie.

### Naming Patterns

**Dart/Flutter — Dart Style Guide :**

| Element | Convention | Exemple |
|---------|-----------|---------|
| Classes | UpperCamelCase | `AIRouter`, `KitaPlugin`, `MemoryVault` |
| Fichiers | snake_case | `ai_router.dart`, `kita_plugin.dart` |
| Variables/fonctions | lowerCamelCase | `isAvailable`, `handleRequest()` |
| Constantes | lowerCamelCase | `maxRetryCount`, `defaultTimeout` |
| Enums | UpperCamelCase + lowerCamelCase values | `RequestPriority.critical` |
| Providers Riverpod | lowerCamelCase + Provider suffix | `aiRouterProvider`, `userProfileProvider` |
| Extensions | on + TypeName | `extension on BuildContext` |
| Prives | prefixe `_` | `_fallbackChain`, `_processRequest()` |

**Drift (DB) :**

| Element | Convention | Exemple |
|---------|-----------|---------|
| Tables | snake_case pluriel | `episodes`, `persons`, `user_profiles` |
| Colonnes | snake_case | `created_at`, `plugin_id`, `confidence_score` |
| DAOs | UpperCamelCase + Dao suffix | `EpisodeDao`, `PreferenceDao` |
| Migrations | version numerique | `from1To2`, `from2To3` |

**Plugin System :**

| Element | Convention | Exemple |
|---------|-----------|---------|
| Plugin ID | reverse domain | `com.kita.describe`, `com.kita.alert` |
| Plugin class | Kita + Name + Plugin | `KitaDescribePlugin`, `KitaAlertPlugin` |
| Manifest file | `plugin.kita.yaml` | Toujours ce nom, racine du plugin |
| Voice commands | francais, infinitif | `"decris"`, `"lis ca"`, `"aide"` |

**Platform Channels :**

| Element | Convention | Exemple |
|---------|-----------|---------|
| Channel name | `com.kita/` + feature | `com.kita/haptic`, `com.kita/camera` |
| Method name | lowerCamelCase | `triggerImpact`, `captureFrame` |
| Arguments | Map<String, dynamic> | `{"intensity": "heavy", "pattern": "danger"}` |

### Structure Patterns

**Regle de dependance (Clean Architecture) :**

```
domain/ <-- data/ <-- presentation/

- domain/ n'importe JAMAIS data/ ni presentation/
- data/ n'importe JAMAIS presentation/
- presentation/ peut importer domain/ (pas data/ directement)
- Les providers Riverpod font le lien data/ <-> presentation/
```

**Placement des fichiers :**

| Quoi | Ou | Regle |
|------|-----|-------|
| Tests unitaires | `test/features/{feature}/` miroir de `lib/` | Test co-localise avec le fichier source, meme arborescence |
| Tests d'integration | `integration_test/` | Par journey (onboarding_test, describe_test) |
| Interfaces/abstractions | `{feature}/domain/` | Jamais d'import de `data/` depuis `domain/` |
| Implementations | `{feature}/data/` | Peut importer `domain/` mais pas `presentation/` |
| Widgets/ecrans | `{feature}/presentation/` | Peut importer `domain/` |
| Widgets partages | `shared/widgets/` | Utilises par 2+ features |
| Multi-modal | `shared/multi_modal/` | ProfileAdapter, VoiceFeedback, HapticFeedback |
| Code natif bridge | `platform/{ios,android}/` | Jamais de logique metier cote natif |
| Config/constantes | `core/config/` | Valeurs injectees par Riverpod |
| Assets | `assets/{images,sounds,models}/` | Modeles TFLite dans `assets/models/` |

### Format Patterns

**AI Provider — format de reponse unifie :**

```dart
class AIResponse {
  final String content;
  final AIResponseMeta meta;        // provider, latency, tier, cached
  final AIResponseStatus status;    // success, fallback, degraded, error
}
```

Tous les providers retournent un `AIResponse`. Jamais de format custom par provider.

**Plugin — format de requete/reponse :**

```dart
class PluginRequest {
  final String command;             // "decris", "alerte"
  final Map<String, dynamic> params;
  final SensorAccess sensors;       // acces sandbox aux capteurs
  final AIAccess ai;                // acces sandbox a l'AI Router
  final MemoryAccess? memory;       // null si plugin non verifie
}

class PluginResponse {
  final PluginResponseType type;    // text, image, alert, rich
  final String content;
  final Map<String, dynamic>? metadata;
  final Widget? viewport;           // widget custom optionnel
}
```

**Evenements — format unifie :**

```dart
class KitaEvent {
  final String source;              // "ai_router", "plugin.describe", "io.camera"
  final String type;                // "state_changed", "response_ready", "error"
  final DateTime timestamp;
  final Map<String, dynamic> data;
}
```

Naming : `source.type` en snake_case — `ai_router.fallback_triggered`, `plugin.describe.response_ready`.

**Dates :** ISO 8601 partout (`DateTime.toIso8601String()`). Pas de timestamps Unix, pas de format custom.

### Communication Patterns

**Riverpod Providers — organisation :**

| Type | Naming | Usage |
|------|--------|-------|
| State | `{feature}StateProvider` | Etat UI reactif |
| Notifier | `{feature}NotifierProvider` | Logique metier avec state |
| Future | `{feature}Provider` | Chargement async one-shot |
| Stream | `{feature}StreamProvider` | Flux temps reel (capteurs, events) |
| Service | `{feature}ServiceProvider` | Singleton injecte (AIRouter, MemoryVault) |

**Regles Riverpod :**

- Providers definis dans `{feature}/domain/` ou `core/di/`
- Jamais de provider defini dans un widget
- `ref.watch()` dans les widgets, `ref.read()` dans les callbacks
- `ref.listen()` pour les side effects (navigation, toast)

**Multi-modal — declenchement coherent :**

Chaque composant qui produit un output DOIT passer par `ProfileAdapter` :

```dart
// BON — utilise ProfileAdapter
final adapter = ref.read(profileAdapterProvider);
adapter.feedback(
  visual: () => showSnackBar("Description prete"),
  vocal: () => tts.speak("Voici la description"),
  haptic: () => haptic.confirmation(),
);

// MAUVAIS — output direct sans ProfileAdapter
tts.speak("Voici la description");  // ignore pour profil sourd
```

### Process Patterns

**Error Handling — hierarchie :**

```dart
sealed class KitaFailure {
  String get userMessage;           // Message pour l'utilisateur
  String get logMessage;            // Message pour les logs
}

class NetworkFailure extends KitaFailure { ... }
class AIProviderFailure extends KitaFailure { ... }
class PluginFailure extends KitaFailure { ... }
class StorageFailure extends KitaFailure { ... }
class PermissionFailure extends KitaFailure { ... }
```

**Regles d'erreur :**

- Jamais de `throw` non type — toujours `KitaFailure`
- Jamais de `catch (e)` generique — `catch (e, stack)` avec logging
- `Result<T>` pattern (Either) pour les retours — `Success(data)` ou `Failure(error)`
- Chemin critique : JAMAIS de throw, cascade vers alerte brute

**Loading States — pattern unifie :**

Riverpod 3.0 `AsyncValue<T>` est le standard. Chaque provider async utilise `AsyncValue<T>`.

**Logging — niveaux et format :**

| Niveau | Usage | Exemple |
|--------|-------|---------|
| `debug` | Dev only | `[AIRouter] Routing to cloud-powerful` |
| `info` | Etat normal | `[Plugin.Describe] Photo captured, sending to AI` |
| `warning` | Degradation | `[AIRouter] Cloud timeout, fallback to local` |
| `error` | Erreur recuperable | `[Plugin.Alert] Model loading failed, retry` |
| `critical` | Ne devrait jamais arriver | `[Fallback] All providers failed, brute alert` |

Format : `[Source] Message` — jamais de PII dans les logs (NFR-SEC-002).

### Enforcement Guidelines

**Tous les agents IA DOIVENT :**

1. Suivre le Dart Style Guide pour le naming
2. Utiliser `ProfileAdapter` pour tout output multi-modal
3. Utiliser `Result<T>` pour les retours d'erreur (pas de throw non type)
4. Placer les tests en miroir de `lib/` dans `test/`
5. Respecter la regle de dependance Clean Architecture (domain <- data <- presentation)
6. Ajouter `Semantics` wrapper a chaque widget interactif
7. Ne jamais acceder aux capteurs/IA directement depuis un plugin — passer par `SensorAccess`/`AIAccess`
8. Logger sans PII — jamais de donnees utilisateur dans les logs
9. Utiliser `AsyncValue<T>` (Riverpod) pour les etats async
10. Nommer les providers avec le suffix `Provider` et le prefixe feature

**Pattern Enforcement :**

- Lint rules custom dans `analysis_options.yaml`
- Code review sur chaque PR (meme agent-generated)
- Tests CI bloquants pour Semantics coverage et no-PII-in-logs

## Project Structure & Boundaries

### Mapping FR → Composants architecturaux

| Categorie FR | Repertoire principal | Composants impliques |
|---|---|---|
| **AI & Intelligence** (FR-AI-001→006) | `lib/features/ai/` | AIRouter, AIProvider impls, RequestClassifier, FallbackChain, cache Drift |
| **Perception & Capteurs** (FR-PER-001→007) | `lib/features/io/` | CameraService, AudioMultiplexer, STTService, GPSService, MotionService |
| **Communication & Sortie** (FR-COM-001→006) | `lib/shared/multi_modal/` + `lib/features/io/` | ProfileAdapter, TTSService, HapticService, VoiceFeedback |
| **Memoire & Donnees** (FR-MEM-001→007) | `lib/features/memory/` | Drift DAOs, MemoryVault, ForgetService, ConsentLog, nettoyage auto |
| **Plugin System** (FR-PLG-001→007) | `lib/features/plugins/` | KitaPlugin, PluginRegistry, PluginSandbox, PluginManifest, built-in plugins |
| **Onboarding & Config** (FR-ONB-001→008) | `lib/features/onboarding/` + `lib/features/settings/` | OnboardingFlow, ProfileDetection, PermissionCards, PackInstaller |
| **Securite & Vie Privee** (FR-SEC-001→005) | `lib/core/` + transversal | SecureStorageService, EXIF stripping, ConsentLog, encryption config |

**Fonctionnalites transversales :**

| Concern | Repertoires impactes |
|---|---|
| Multi-modal output | `lib/shared/multi_modal/` → traverse toutes les features |
| Accessibilite WCAG | Tous les `presentation/` + `test/` (Semantics matchers) |
| Error handling never-fail | `lib/core/errors/` → traverse AI, plugins, I/O |
| Offline capability | `lib/features/ai/data/` (fallback) + `lib/features/memory/data/` |
| Securite donnees | `lib/core/config/` (SQLCipher) + `lib/features/memory/` |

### Complete Project Directory Structure

```
kita/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                          # Lint + tests + a11y + couverture
│   │   ├── build-android.yml               # Build APK/AAB
│   │   └── build-ios.yml                   # Build IPA
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/com/kita/
│   │   │   │   ├── MainActivity.kt
│   │   │   │   ├── channels/
│   │   │   │   │   ├── HapticChannel.kt     # VibrationEffect API
│   │   │   │   │   ├── CameraChannel.kt     # CameraX bridge
│   │   │   │   │   ├── BackgroundChannel.kt # Foreground Service
│   │   │   │   │   └── AccessibilityChannel.kt # TalkBack detection
│   │   │   │   └── services/
│   │   │   │       └── KitaForegroundService.kt
│   │   │   └── AndroidManifest.xml
│   │   └── build.gradle.kts
│   ├── build.gradle.kts
│   └── settings.gradle.kts
├── ios/
│   ├── Runner/
│   │   ├── AppDelegate.swift
│   │   ├── Channels/
│   │   │   ├── HapticChannel.swift          # UIImpactFeedbackGenerator
│   │   │   ├── CameraChannel.swift          # AVFoundation bridge
│   │   │   ├── BackgroundChannel.swift      # Background Audio + Location
│   │   │   └── AccessibilityChannel.swift   # VoiceOver detection
│   │   ├── Services/
│   │   │   └── BackgroundAudioService.swift
│   │   ├── Info.plist
│   │   └── Runner.entitlements
│   ├── Runner.xcodeproj/
│   └── Podfile
├── lib/
│   ├── main.dart                            # Entry point, ProviderScope
│   ├── app.dart                             # KitaApp, go_router config, KitaTheme
│   ├── core/
│   │   ├── di/
│   │   │   ├── providers.dart               # Providers globaux (AIRouter, MemoryVault)
│   │   │   └── service_locator.dart         # Initialisation services au boot
│   │   ├── config/
│   │   │   ├── app_config.dart              # Constantes, timeouts, limites
│   │   │   ├── database_config.dart         # Drift + SQLCipher init
│   │   │   └── environment.dart             # Flavors dev/staging/prod
│   │   ├── errors/
│   │   │   ├── kita_failure.dart            # sealed class KitaFailure
│   │   │   ├── result.dart                  # Result<T> = Success | Failure
│   │   │   └── failure_handler.dart         # Logging + ProfileAdapter error feedback
│   │   ├── theme/
│   │   │   ├── kita_theme.dart              # Mix design tokens, variants
│   │   │   ├── mix_tokens.dart              # Couleurs, spacing, typo, radii
│   │   │   ├── multi_modal_tokens.dart      # Durees anim, haptic intensities
│   │   │   └── accessibility_tokens.dart    # Contraste, tailles min, focus
│   │   ├── utils/
│   │   │   ├── extensions.dart              # Extensions BuildContext, DateTime
│   │   │   ├── logger.dart                  # [Source] Message, zero PII
│   │   │   └── validators.dart              # Validation API keys, inputs
│   │   └── constants/
│   │       ├── durations.dart               # Timeouts, TTL cache, animations
│   │       └── limits.dart                  # RAM, battery, quotas plugins
│   ├── features/
│   │   ├── ai/
│   │   │   ├── domain/
│   │   │   │   ├── ai_provider.dart         # abstract class AIProvider
│   │   │   │   ├── ai_request.dart          # AIRequest, RequestPriority
│   │   │   │   ├── ai_response.dart         # AIResponse, AIResponseMeta
│   │   │   │   ├── ai_router.dart           # AIRouter interface
│   │   │   │   ├── request_classifier.dart  # RequestClassifier interface
│   │   │   │   └── provider_tier.dart       # enum ProviderTier
│   │   │   ├── data/
│   │   │   │   ├── ai_router_impl.dart      # AIRouter implementation
│   │   │   │   ├── request_classifier_impl.dart
│   │   │   │   ├── fallback_chain.dart      # FallbackChain never-fail
│   │   │   │   ├── response_cache.dart      # Drift-based cache
│   │   │   │   └── providers/
│   │   │   │       ├── claude_provider.dart  # Anthropic API
│   │   │   │       ├── openai_provider.dart  # OpenAI API
│   │   │   │       ├── mlkit_provider.dart   # ML Kit (Android)
│   │   │   │       └── coreml_provider.dart  # CoreML (iOS)
│   │   │   └── presentation/               # (vide — pas d'UI propre)
│   │   ├── io/
│   │   │   ├── domain/
│   │   │   │   ├── io_service.dart          # Interface abstraite capteurs
│   │   │   │   ├── camera_service.dart      # CameraService interface
│   │   │   │   ├── audio_service.dart       # AudioMultiplexer interface
│   │   │   │   ├── stt_service.dart         # STTService interface
│   │   │   │   ├── tts_service.dart         # TTSService interface
│   │   │   │   ├── haptic_service.dart      # HapticService interface (3 patterns)
│   │   │   │   ├── location_service.dart    # GPSService interface
│   │   │   │   └── motion_service.dart      # Accelerometre interface
│   │   │   ├── data/
│   │   │   │   ├── camera_service_impl.dart # Platform channel camera
│   │   │   │   ├── audio_service_impl.dart
│   │   │   │   ├── stt_service_impl.dart    # speech_to_text package
│   │   │   │   ├── tts_service_impl.dart    # flutter_tts package
│   │   │   │   ├── haptic_service_impl.dart # Platform channel haptic
│   │   │   │   ├── location_service_impl.dart
│   │   │   │   ├── motion_service_impl.dart
│   │   │   │   └── exif_stripper.dart       # Strip EXIF avant envoi cloud
│   │   │   └── presentation/               # (vide — pas d'UI propre)
│   │   ├── memory/
│   │   │   ├── domain/
│   │   │   │   ├── memory_vault.dart        # MemoryVault interface
│   │   │   │   ├── memory_domain.dart       # enum MemoryDomain (4 domaines)
│   │   │   │   ├── forget_request.dart      # ForgetRequest, ForgetScope
│   │   │   │   └── consent_entry.dart       # ConsentEntry model
│   │   │   ├── data/
│   │   │   │   ├── database.dart            # KitaDatabase (Drift generated)
│   │   │   │   ├── database.g.dart          # Drift generated code
│   │   │   │   ├── tables/
│   │   │   │   │   ├── episodes_table.dart
│   │   │   │   │   ├── preferences_table.dart
│   │   │   │   │   ├── persons_table.dart
│   │   │   │   │   ├── user_profiles_table.dart
│   │   │   │   │   ├── plugin_data_table.dart
│   │   │   │   │   ├── request_cache_table.dart
│   │   │   │   │   └── consent_log_table.dart
│   │   │   │   ├── daos/
│   │   │   │   │   ├── episode_dao.dart
│   │   │   │   │   ├── preference_dao.dart
│   │   │   │   │   ├── person_dao.dart
│   │   │   │   │   ├── profile_dao.dart
│   │   │   │   │   ├── plugin_data_dao.dart
│   │   │   │   │   ├── cache_dao.dart
│   │   │   │   │   └── consent_dao.dart
│   │   │   │   ├── memory_vault_impl.dart
│   │   │   │   └── auto_cleanup.dart        # Nettoyage episodes > 30j
│   │   │   └── presentation/               # (vide — pas d'UI propre)
│   │   ├── plugins/
│   │   │   ├── domain/
│   │   │   │   ├── kita_plugin.dart         # abstract class KitaPlugin
│   │   │   │   ├── plugin_manifest.dart     # PluginManifest (parsed YAML)
│   │   │   │   ├── plugin_sandbox.dart      # PluginSandbox interface
│   │   │   │   ├── plugin_request.dart      # PluginRequest
│   │   │   │   ├── plugin_response.dart     # PluginResponse
│   │   │   │   ├── sensor_access.dart       # SensorAccess (sandbox proxy)
│   │   │   │   ├── ai_access.dart           # AIAccess (sandbox proxy)
│   │   │   │   ├── memory_access.dart       # MemoryAccess (sandbox proxy)
│   │   │   │   └── trust_level.dart         # enum TrustLevel (3 niveaux)
│   │   │   ├── data/
│   │   │   │   ├── plugin_registry.dart     # Enregistrement + lifecycle
│   │   │   │   ├── plugin_sandbox_impl.dart # Enforcement permissions
│   │   │   │   ├── plugin_loader.dart       # Chargement + YAML parsing
│   │   │   │   └── plugin_quota_manager.dart # Quotas par plugin
│   │   │   ├── presentation/
│   │   │   │   └── plugin_viewport.dart     # Widget viewport delegue
│   │   │   └── built_in/
│   │   │       ├── describe/
│   │   │       │   ├── describe_plugin.dart  # KitaDescribePlugin
│   │   │       │   ├── describe_viewport.dart
│   │   │       │   └── plugin.kita.yaml      # Manifest
│   │   │       └── alert/
│   │   │           ├── alert_plugin.dart      # KitaAlertPlugin
│   │   │           ├── alert_viewport.dart
│   │   │           ├── obstacle_detector.dart # TFLite/YOLO wrapper
│   │   │           └── plugin.kita.yaml      # Manifest
│   │   ├── onboarding/
│   │   │   ├── domain/
│   │   │   │   ├── onboarding_state.dart    # OnboardingState, steps
│   │   │   │   └── profile_detection.dart   # ProfileDetection interface
│   │   │   ├── data/
│   │   │   │   ├── profile_detection_impl.dart # VoiceOver/TalkBack detection
│   │   │   │   └── pack_installer.dart      # Installation packs auto
│   │   │   └── presentation/
│   │   │       ├── onboarding_screen.dart    # Flow principal vocal-first
│   │   │       ├── permission_card.dart      # KitaPermissionCard storytelling
│   │   │       ├── profile_selector.dart     # Choix profil accessibilite
│   │   │       └── api_key_setup.dart        # BYOK screen
│   │   ├── shell/
│   │   │   └── presentation/
│   │   │       ├── kita_shell.dart           # Ecran principal Living Aura
│   │   │       ├── kita_orb.dart             # Orbe anime (6 etats)
│   │   │       ├── kita_input.dart           # Input vocal/texte adaptatif
│   │   │       └── transcription_bubble.dart # TranscriptionBubble
│   │   └── settings/
│   │       ├── domain/
│   │       │   └── user_preferences.dart     # Modele preferences
│   │       ├── data/
│   │       │   └── preferences_repository.dart
│   │       └── presentation/
│   │           ├── settings_screen.dart
│   │           ├── plugin_manager_screen.dart
│   │           ├── memory_view_screen.dart   # "Qu'est-ce que tu sais sur moi"
│   │           └── forget_screen.dart        # Droit a l'oubli
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── kita_alert.dart              # Alerte multi-modale
│   │   │   ├── kita_feedback_bubble.dart    # Bulle feedback contextuel
│   │   │   ├── kita_status_indicator.dart   # Indicateur etat connexion/mode
│   │   │   └── kita_loading.dart            # Loading adaptatif
│   │   └── multi_modal/
│   │       ├── profile_adapter.dart         # Routage output par profil
│   │       ├── voice_feedback.dart          # Wrapper TTS avec priorite
│   │       └── haptic_feedback.dart         # Wrapper haptic 3 patterns
│   └── platform/
│       ├── platform_bridge.dart             # Interface abstraite
│       ├── ios_bridge.dart                  # Implementation iOS channels
│       └── android_bridge.dart              # Implementation Android channels
├── test/
│   ├── core/
│   │   ├── errors/
│   │   │   ├── kita_failure_test.dart
│   │   │   └── result_test.dart
│   │   └── utils/
│   │       └── logger_test.dart
│   ├── features/
│   │   ├── ai/
│   │   │   ├── domain/
│   │   │   │   └── request_classifier_test.dart
│   │   │   └── data/
│   │   │       ├── ai_router_impl_test.dart
│   │   │       ├── fallback_chain_test.dart
│   │   │       ├── response_cache_test.dart
│   │   │       └── providers/
│   │   │           ├── claude_provider_test.dart
│   │   │           └── openai_provider_test.dart
│   │   ├── io/
│   │   │   └── data/
│   │   │       ├── exif_stripper_test.dart
│   │   │       └── haptic_service_impl_test.dart
│   │   ├── memory/
│   │   │   ├── data/
│   │   │   │   ├── memory_vault_impl_test.dart
│   │   │   │   ├── auto_cleanup_test.dart
│   │   │   │   └── daos/
│   │   │   │       ├── episode_dao_test.dart
│   │   │   │       ├── preference_dao_test.dart
│   │   │   │       └── consent_dao_test.dart
│   │   │   └── domain/
│   │   │       └── forget_request_test.dart
│   │   ├── plugins/
│   │   │   ├── data/
│   │   │   │   ├── plugin_registry_test.dart
│   │   │   │   ├── plugin_sandbox_impl_test.dart
│   │   │   │   └── plugin_loader_test.dart
│   │   │   └── built_in/
│   │   │       ├── describe/
│   │   │       │   └── describe_plugin_test.dart
│   │   │       └── alert/
│   │   │           ├── alert_plugin_test.dart
│   │   │           └── obstacle_detector_test.dart
│   │   ├── onboarding/
│   │   │   ├── data/
│   │   │   │   └── profile_detection_impl_test.dart
│   │   │   └── presentation/
│   │   │       └── onboarding_screen_test.dart
│   │   ├── shell/
│   │   │   └── presentation/
│   │   │       ├── kita_shell_test.dart
│   │   │       ├── kita_orb_test.dart
│   │   │       └── kita_input_test.dart
│   │   └── settings/
│   │       └── presentation/
│   │           └── forget_screen_test.dart
│   ├── shared/
│   │   ├── widgets/
│   │   │   └── kita_alert_test.dart
│   │   └── multi_modal/
│   │       └── profile_adapter_test.dart
│   └── helpers/
│       ├── test_providers.dart               # Providers mockes pour tests
│       ├── mock_ai_provider.dart
│       ├── mock_database.dart
│       └── accessibility_matchers.dart       # Semantics matchers custom
├── integration_test/
│   ├── onboarding_flow_test.dart
│   ├── describe_journey_test.dart
│   ├── alert_journey_test.dart
│   ├── forget_journey_test.dart
│   └── helpers/
│       └── test_app.dart
├── assets/
│   ├── images/
│   │   └── kita_logo.svg
│   ├── sounds/
│   │   ├── alert_danger.wav                 # Alerte brute fallback
│   │   ├── alert_warning.wav
│   │   └── confirmation.wav
│   └── models/
│       └── yolo_v8_nano.tflite              # Modele detection obstacles ~6MB
├── pubspec.yaml
├── analysis_options.yaml                    # Lint rules strictes + customs
├── .env.example                             # Template cles API
├── .gitignore
├── LICENSE                                  # MIT
├── README.md
├── CONTRIBUTING.md
└── fastlane/
    ├── Fastfile
    ├── Appfile
    └── Matchfile
```

### Architectural Boundaries

**Frontieres API (interfaces internes) :**

Kita n'a pas d'API REST externe. Les frontieres sont des interfaces Dart internes :

| Frontiere | Interface | Cote producteur | Cote consommateur |
|---|---|---|---|
| AI Provider | `AIProvider` | `data/providers/*.dart` | `AIRouter` |
| Plugin System | `KitaPlugin` | `built_in/` + plugins externes | `PluginRegistry`, `PluginSandbox` |
| Sensor Access | `SensorAccess` | `io/data/*_impl.dart` | Plugins (via sandbox) |
| Memory Access | `MemoryAccess` | `memory/data/` DAOs | Plugins (via sandbox) |
| Platform Bridge | `PlatformBridge` | `platform/{ios,android}_bridge.dart` | `io/data/` implementations |
| Profile Adapter | `ProfileAdapter` | `shared/multi_modal/` | Tous les composants UI |

Regle fondamentale : tout franchissement de frontiere passe par une interface abstraite definie dans `domain/`. Jamais d'import direct cross-feature de `data/`.

**Frontieres de composants (state management) :**

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  KitaShell ─── PluginViewport ─── SettingsScreen         │
│       │              │                   │               │
│  ref.watch()    ref.watch()         ref.watch()          │
└───────┬──────────────┬───────────────────┬───────────────┘
        │              │                   │
┌───────┴──────────────┴───────────────────┴───────────────┐
│                   Riverpod Providers                      │
│  aiRouterProvider ─ pluginRegistryProvider ─ profileProv  │
│       │                    │                  │           │
└───────┬────────────────────┬──────────────────┬──────────┘
        │                    │                  │
┌───────┴──────┐  ┌──────────┴────────┐  ┌─────┴─────────┐
│  AI Feature  │  │  Plugin Feature   │  │ Memory Feature│
│  domain/     │  │  domain/          │  │ domain/       │
│  data/       │  │  data/            │  │ data/         │
└──────────────┘  └───────────────────┘  └───────────────┘
```

Regles de communication inter-features :
- Features communiquent uniquement via Riverpod providers
- Jamais d'import direct `feature_a/data/` depuis `feature_b/`
- Les imports cross-feature sont autorises uniquement sur `domain/` (interfaces)
- `shared/` est importable par toutes les features
- `core/` est importable par tout le monde

**Frontieres de donnees :**

| Frontiere | Mecanisme | Regle |
|---|---|---|
| DB <-> Domain | DAOs Drift → modeles domain | Les DAOs retournent des objets domain, jamais des row objects |
| Plugin <-> DB | `MemoryAccess` proxy | Plugins n'accedent jamais a la DB directement. Namespace enforced par plugin_id |
| Cloud <-> App | SDK HTTP (Claude, OpenAI) | Strip EXIF, zero PII, timeout 3s, HTTPS only |
| RAM <-> DB | Riverpod (working memory) | Conversation courante en RAM, persistance explicite |
| Capteurs <-> App | Platform Channels | Donnees brutes normalisees cote Flutter, jamais d'acces natif direct |

**Frontieres de securite :**

```
┌─────────────────────────────────────────────────────────────┐
│  Sandbox Plugin (non verifie)                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ SensorAccess limite │ AIAccess limite │ Pas de Memory  │  │
│  └────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Sandbox Plugin (communautaire verifie)                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ SensorAccess declares │ AIAccess │ Memory sandboxed    │  │
│  └────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Plugin officiel                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Tous capteurs declares │ AIAccess │ Memory partagee    │  │
│  └────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Core Kita (trusted)                                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Acces complet DB │ Keychain/Keystore │ Platform Channels│  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Requirements to Structure Mapping

**AI & Intelligence :**

| FR | Fichier(s) principal(s) | Test(s) |
|---|---|---|
| FR-AI-001 (Router 3 tiers) | `ai/data/ai_router_impl.dart`, `ai/domain/provider_tier.dart` | `ai/data/ai_router_impl_test.dart` |
| FR-AI-002 (Fallback chain) | `ai/data/fallback_chain.dart` | `ai/data/fallback_chain_test.dart` |
| FR-AI-003 (RequestClassifier) | `ai/data/request_classifier_impl.dart` | `ai/domain/request_classifier_test.dart` |
| FR-AI-004 (Local ML) | `ai/data/providers/mlkit_provider.dart`, `coreml_provider.dart` | `ai/data/providers/` |
| FR-AI-005 (Cache) | `ai/data/response_cache.dart` | `ai/data/response_cache_test.dart` |
| FR-AI-006 (Multi-provider) | `ai/data/providers/claude_provider.dart`, `openai_provider.dart` | tests providers |

**Plugin System :**

| FR | Fichier(s) principal(s) | Test(s) |
|---|---|---|
| FR-PLG-001 (Interface plugin) | `plugins/domain/kita_plugin.dart` | `plugins/data/plugin_registry_test.dart` |
| FR-PLG-002 (Manifest YAML) | `plugins/data/plugin_loader.dart`, `plugins/domain/plugin_manifest.dart` | `plugins/data/plugin_loader_test.dart` |
| FR-PLG-003 (Sandbox) | `plugins/data/plugin_sandbox_impl.dart` | `plugins/data/plugin_sandbox_impl_test.dart` |
| FR-PLG-004 (Plugin Describe) | `plugins/built_in/describe/describe_plugin.dart` | `plugins/built_in/describe/describe_plugin_test.dart` |
| FR-PLG-005 (Plugin Alert) | `plugins/built_in/alert/alert_plugin.dart`, `obstacle_detector.dart` | `plugins/built_in/alert/` |
| FR-PLG-006 (Voice commands) | `plugins/domain/kita_plugin.dart` (voiceCommands getter) | tests plugin |
| FR-PLG-007 (Lifecycle) | `plugins/data/plugin_registry.dart` | `plugins/data/plugin_registry_test.dart` |

**Memoire & Donnees :**

| FR | Fichier(s) principal(s) |
|---|---|
| FR-MEM-001 (DB chiffree) | `core/config/database_config.dart`, `memory/data/database.dart` |
| FR-MEM-002 (4 domaines) | `memory/domain/memory_domain.dart`, `memory/data/tables/` |
| FR-MEM-003 (Consentement) | `memory/data/tables/consent_log_table.dart`, `memory/data/daos/consent_dao.dart` |
| FR-MEM-004 (Droit a l'oubli) | `memory/domain/forget_request.dart`, `memory/data/memory_vault_impl.dart` |
| FR-MEM-005 (Transparence) | `settings/presentation/memory_view_screen.dart` |
| FR-MEM-006 (Nettoyage auto) | `memory/data/auto_cleanup.dart` |
| FR-MEM-007 (Priorite) | `memory/data/daos/episode_dao.dart` (scoring) |

### Integration Points

**Communication interne :**

```
KitaShell
  ├── ref.watch(aiRouterProvider) ──→ AIRouter
  │     └── RequestClassifier → Provider selection → FallbackChain
  ├── ref.watch(pluginRegistryProvider) ──→ PluginRegistry
  │     └── activePlugin.handleRequest() → PluginSandbox → SensorAccess/AIAccess
  ├── ref.watch(profileAdapterProvider) ──→ ProfileAdapter
  │     └── feedback(visual, vocal, haptic) → TTS / Haptic / UI
  └── ref.watch(ioServiceProvider) ──→ I/O Layer
        └── CameraService / STTService → Platform Channels → Natif
```

**Integrations externes :**

| Service | Package/SDK | Point d'entree | Donnees envoyees |
|---|---|---|---|
| Claude API | anthropic_sdk_dart | `ai/data/providers/claude_provider.dart` | Prompt + image (EXIF stripped), jamais de PII |
| OpenAI API | dart_openai | `ai/data/providers/openai_provider.dart` | Idem |
| ML Kit | google_mlkit_* | `ai/data/providers/mlkit_provider.dart` | Image locale uniquement |
| Sentry | sentry_flutter | `core/di/service_locator.dart` | Crash data, opt-in, zero PII |

**Flux de donnees principal (describe photo) :**

```
1. Utilisateur dit "decris" → STTService → commande vocale
2. PluginRegistry identifie KitaDescribePlugin
3. KitaDescribePlugin.handleRequest() via PluginSandbox
4. SensorAccess.capturePhoto() → CameraService → Platform Channel → image
5. ExifStripper.strip(image) → image propre
6. AIAccess.vision(image, prompt) → AIRouter → RequestClassifier → cloud-powerful
7. AIResponse → PluginResponse (text)
8. ProfileAdapter.feedback(vocal: tts.speak(description))
9. MemoryVault.saveEpisode() → Drift → episodes table
```

### File Organization Patterns

**Configuration :**

| Fichier | Role |
|---|---|
| `pubspec.yaml` | Dependances Dart/Flutter |
| `analysis_options.yaml` | Lint rules strictes, Semantics enforcement |
| `.env.example` | Template variables environnement (cles API format) |
| `android/app/build.gradle.kts` | Config Android (minSdk 31, compileSdk 35) |
| `ios/Runner/Info.plist` | Permissions iOS (camera, micro, location, background) |
| `fastlane/Fastfile` | Automatisation build + deploiement stores |

**Organisation des tests :**

| Type | Repertoire | Convention |
|---|---|---|
| Unitaires | `test/` miroir de `lib/` | `{file}_test.dart`, meme arborescence |
| Widgets | `test/features/*/presentation/` | Tests Semantics obligatoires |
| Integration | `integration_test/` | Par user journey (`describe_journey_test.dart`) |
| Helpers | `test/helpers/` | Mocks, matchers, providers de test |
| A11y | Integres aux widget tests | `expectSemanticsLabel()`, `expectSemanticsAction()` |

**Organisation des assets :**

| Type | Repertoire | Convention |
|---|---|---|
| Images | `assets/images/` | SVG prefere, `kita_*.svg` |
| Sons | `assets/sounds/` | WAV 16-bit, `{type}_{variante}.wav` |
| Modeles ML | `assets/models/` | TFLite quantized, `{model}_v{version}.tflite` |
| Plugin manifests | `plugins/built_in/{plugin}/` | `plugin.kita.yaml` |

### Development Workflow Integration

**Dev local :**

- `flutter run` avec hot reload standard
- Flavors : `--dart-define=ENV=dev` (dev/staging/prod)
- Dart DevTools pour profiling memoire/CPU
- Flutter Inspector pour debug arbre widgets

**Build :**

- Android : `flutter build appbundle --release`
- iOS : `flutter build ipa --release`
- Drift : `dart run build_runner build` (generation code DB)

**Deploiement :**

- CI : GitHub Actions → tests bloquants → build artifacts
- CD : Fastlane → Play Store (internal/beta) + App Store (TestFlight)
- Release : Tags git `v{major}.{minor}.{patch}`

## Architecture Validation Results

### Coherence Validation

**Compatibilite des decisions :**

| Decision A | Decision B | Compatibilite | Notes |
|---|---|---|---|
| Flutter 3.38+ | Drift + SQLCipher | Compatible | Drift supporte Flutter, SQLCipher via `sqlcipher_flutter_libs` |
| Riverpod 3.0 | Clean Architecture | Compatible | Providers font le pont data <-> presentation, `domain/` reste pur |
| Mix (utility-first) | Composants custom (pas Material) | Compatible | Mix construit sur primitives Flutter, pas de dependance Material |
| go_router | Navigation minimale (6 routes) | Compatible | go_router standard Flutter, leger |
| TFLite/YOLO (local) | AI Router 3 tiers | Compatible | TFLite = tier local, AI Router orchestre les 3 tiers |
| Platform Channels | flutter_secure_storage | Compatible | Channels pour haptic/camera, flutter_secure_storage utilise ses propres channels Keychain/Keystore |
| Drift (code generation) | Riverpod 3.0 (code generation) | Compatible | Deux build_runners independants, pas de conflit |
| anthropic_sdk_dart + dart_openai | AIProvider abstraction | Compatible | Chaque SDK implemente l'interface AIProvider |

Aucun conflit de compatibilite detecte. Toutes les technologies coexistent sans friction.

**Coherence des patterns :**

| Pattern | Alignement avec les decisions | Statut |
|---|---|---|
| Naming (Dart Style Guide) | Coherent avec Flutter/Riverpod conventions | OK |
| Clean Architecture (domain <- data <- presentation) | Aligne avec feature-first + Riverpod DI | OK |
| Never-fail error handling | Supporte par sealed KitaFailure + FallbackChain | OK |
| ProfileAdapter multi-modal | Riverpod injection, traverse toutes les features | OK |
| Plugin sandbox (3 niveaux) | SensorAccess/AIAccess/MemoryAccess proxy isolent les plugins | OK |
| Result\<T\> pattern | Coherent avec sealed KitaFailure, pas de throw non type | OK |
| AsyncValue\<T\> (Riverpod) | Standard Riverpod 3.0 pour les etats async | OK |

**Alignement structure :**

| Aspect | Verifie | Notes |
|---|---|---|
| Structure feature-first supporte Clean Architecture | Oui | Chaque feature a domain/data/presentation/ |
| Boundaries respectees dans l'arborescence | Oui | Imports cross-feature limites a domain/ |
| Tests miroir de lib/ | Oui | test/features/ reflete lib/features/ |
| Assets organises par type | Oui | images/, sounds/, models/ |
| Code natif isole | Oui | android/channels/, ios/Channels/ + platform/ bridge cote Flutter |
| Plugins built-in bien localises | Oui | plugins/built_in/{plugin}/ avec manifest |

### Requirements Coverage Validation

**Functional Requirements (46 FRs) :**

| Categorie | FRs | Couverture architecturale | Statut |
|---|---|---|---|
| AI & Intelligence | FR-AI-001→006 | AIRouter, AIProvider, RequestClassifier, FallbackChain, ResponseCache, providers | 6/6 |
| Perception & Capteurs | FR-PER-001→007 | CameraService, AudioMultiplexer, STT/TTS, GPS, Motion, BackgroundService | 7/7 |
| Communication & Sortie | FR-COM-001→006 | ProfileAdapter, TTSService, HapticService, VoiceCommands, KitaInput | 6/6 |
| Memoire & Donnees | FR-MEM-001→007 | Drift+SQLCipher, 4 domaines, ConsentLog, ForgetRequest, MemoryView, AutoCleanup | 7/7 |
| Plugin System | FR-PLG-001→007 | KitaPlugin, PluginManifest, PluginSandbox, Describe, Alert, VoiceCommands, Registry | 7/7 |
| Onboarding & Config | FR-ONB-001→008 | OnboardingFlow, ProfileDetection, PermissionCards, PackInstaller, APIKeySetup | 8/8 |
| Securite & Vie Privee | FR-SEC-001→005 | SecureStorage, ExifStripper, ConsentLog, zero tracking, offline mode | 5/5 |

**Total : 46/46 FRs couverts architecturalement.**

**Non-Functional Requirements (30 NFRs) :**

| Categorie | Support architectural | Statut |
|---|---|---|
| Performance (7) | TFLite local < 50ms, timeout 3s par tier, lazy init, capteurs adaptatifs, Isolate image | 7/7 |
| Securite (6) | SQLCipher AES-256, logger zero PII, flutter_secure_storage, ExifStripper, ConsentLog, MemoryVault.forget() | 6/6 |
| Accessibilite (6) | Mix + accessibility_tokens, Semantics wrappers + CI, contraste 4.5:1+, lint labels, VoiceCommands | 6/6 |
| Fiabilite (5) | Never-fail + KitaFailure, FallbackChain, tier local offline, AutoCleanup + RAM monitoring, service_locator reinit | 5/5 |
| Integration (3) | AIProvider.validateApiKey(), PluginManifest versionne, providers isoles | 3/3 |
| Testabilite (3) | CI bloquant > 80%, Semantics matchers, integration_test/ | 3/3 |

**Total : 30/30 NFRs supportes architecturalement.**

### Implementation Readiness Validation

**Completude des decisions :**

- Decisions critiques documentees avec versions (Drift, Riverpod 3.0, Flutter 3.38+, SQLCipher)
- Patterns d'implementation suffisants (naming, structure, format, communication, process)
- Regles de coherence claires (10 enforcement guidelines)
- Exemples fournis (AIProvider, KitaPlugin, ProfileAdapter, KitaFailure, Result\<T\>, PluginRequest/Response, KitaEvent)

**Completude structurelle :**

- Arborescence complete et specifique (~120 fichiers listes avec commentaires)
- Tous les fichiers et repertoires definis (lib/, test/, integration_test/, assets/, natif, CI/CD)
- Points d'integration specifies (Platform Channels, Riverpod, frontieres API internes)
- Frontieres de composants bien definies (4 types : API, composants, donnees, securite)

**Completude des patterns :**

- 8 categories de patterns couvrant les points de conflit potentiels
- Conventions de nommage exhaustives (Dart, Drift, plugins, channels, providers)
- Patterns de communication specifies (Riverpod, ProfileAdapter, Platform Channels)
- Process patterns complets (KitaFailure, Result\<T\>, AsyncValue, logging)

### Gap Analysis Results

**Lacunes critiques : 0**

**Lacunes importantes : 2**

1. **Mode aidant (FR-ONB-008)** — Mentionne dans le mapping FR mais aucun fichier specifique dans l'arborescence. Devrait etre un ecran dans `settings/presentation/` ou `onboarding/presentation/`. Impact faible — ecran UI, pas decision architecturale.

2. **Battery Monitor** — Mentionne dans les cross-component dependencies et NFRs (< 5%/h) mais pas de fichier dedie. Pourrait vivre dans `core/utils/battery_monitor.dart`. Impact faible — utilitaire, pas decision structurante.

**Lacunes mineures : 3**

1. **Schema de migration Drift** — Tables definies mais strategie de migration initiale sans fichier dedie. Gerable via pattern standard Drift `from1To2`.

2. **Configuration Fastlane detaillee** — Lanes specifiques non detaillees. Configuration d'infra, pas d'architecture.

3. **Plugin SDK documentation** — Interfaces definies, documentation SDK pour developpeurs externes a prevoir post-MVP.

### Architecture Completeness Checklist

**Requirements Analysis :**

- [x] Contexte projet analyse (46 FRs, 30 NFRs, UX, contraintes)
- [x] Echelle et complexite evaluees (~15 modules, haute complexite)
- [x] Contraintes techniques identifiees (7 contraintes dures)
- [x] Concerns transversaux mappes (8 concerns)

**Architectural Decisions :**

- [x] Decisions critiques documentees avec versions
- [x] Stack technologique entierement specifie
- [x] Patterns d'integration definis (API internes, channels, Riverpod)
- [x] Considerations de performance adressees (latence, batterie, RAM)

**Implementation Patterns :**

- [x] Conventions de nommage etablies (Dart, Drift, plugins, channels)
- [x] Patterns de structure definis (Clean Architecture, feature-first)
- [x] Patterns de communication specifies (Riverpod, ProfileAdapter)
- [x] Patterns de process documentes (errors, logging, async states)

**Project Structure :**

- [x] Arborescence complete definie (~120 fichiers)
- [x] Frontieres de composants etablies (4 types)
- [x] Points d'integration mappes
- [x] Mapping FR → structure complet

### Architecture Readiness Assessment

**Statut global : PRET POUR L'IMPLEMENTATION**

**Niveau de confiance : Eleve**

**Forces cles :**

- Architecture local-first coherente avec les exigences de securite et d'accessibilite
- Plugin system bien isole avec 3 niveaux de confiance
- Never-fail pattern garantit la fiabilite pour les utilisateurs handicapes
- Clean Architecture + feature-first permet l'implementation modulaire par epic
- Remplacement proactif d'Isar (abandonne) par Drift + SQLCipher
- Recherche web 2026 validant toutes les decisions technologiques

**Ameliorations futures :**

- flutter_local_ai quand iOS 26+ sera le minimum supporte
- Cache par similarite semantique (post-MVP)
- Plugin marketplace et SDK pub.dev
- Multi-appareils (BLE, lunettes connectees)
- Profils vocaux / reconnaissance locuteurs

### Implementation Handoff

**Directives pour les agents IA :**

- Suivre toutes les decisions architecturales exactement comme documentees
- Utiliser les patterns d'implementation de maniere coherente sur tous les composants
- Respecter la structure du projet et les frontieres
- Se referer a ce document pour toute question architecturale
- Ne jamais devier des conventions de nommage etablies
- Toujours passer par ProfileAdapter pour les outputs multi-modaux
- Toujours utiliser Result\<T\> pour les retours d'erreur

**Premiere priorite d'implementation :**

```bash
flutter create --org com.kita --platforms android,ios kita
```

Puis : structure feature-first + Riverpod 3.0 + Mix + go_router + Drift + SQLCipher (schema initial)
