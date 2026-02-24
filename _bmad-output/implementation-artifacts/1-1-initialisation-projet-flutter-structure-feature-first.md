# Story 1.1: Initialisation du projet Flutter et structure feature-first

Status: done

## Story

As a **développeur**,
I want **un projet Flutter initialisé avec la structure feature-first + Clean Architecture**,
So that **tous les agents peuvent commencer à travailler dans des répertoires isolés et bien définis**.

## Acceptance Criteria

1. **Given** aucun code source n'existe **When** le projet est initialisé avec `flutter create --org com.kita --platforms android,ios kita` **Then** le projet compile et s'exécute sur un émulateur Android et un simulateur iOS

2. **And** la structure de répertoires feature-first est créée :
   - `lib/core/` (di/, config/, errors/, theme/, utils/)
   - `lib/features/ai/` (domain/, data/, presentation/)
   - `lib/features/io/` (domain/, data/, presentation/)
   - `lib/features/memory/` (domain/, data/, presentation/)
   - `lib/features/plugins/` (domain/, data/, presentation/ + built_in/)
   - `lib/features/onboarding/` (domain/, data/, presentation/)
   - `lib/features/shell/` (domain/, presentation/)
   - `lib/features/settings/` (domain/, presentation/)
   - `lib/shared/` (widgets/, multi_modal/)
   - `lib/platform/` (ios/, android/)

3. **And** chaque feature contient les sous-répertoires `domain/`, `data/`, `presentation/`

4. **And** `test/` miroir la structure de `lib/`

5. **And** `analysis_options.yaml` est configuré avec les lint rules strictes (flutter_lints + Semantics enforcement)

6. **And** `pubspec.yaml` contient toutes les dépendances du projet (voir section Tasks pour la liste exacte versionnée)

7. **And** les dev_dependencies incluent : `build_runner`, `riverpod_generator`, `drift_dev`, `freezed`, `json_serializable`, `riverpod_lint`, `custom_lint`

8. **And** `.gitignore` exclut les fichiers générés (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`)

9. **And** `dart run build_runner build --delete-conflicting-outputs` s'exécute sans erreur (valide que le code generation pipeline fonctionne)

## Tasks / Subtasks

- [ ] **Task 1 : Initialiser le projet Flutter** (AC: #1)
  - [ ] Exécuter `flutter create --org com.kita --platforms android,ios kita` dans un répertoire temporaire (ex: `/tmp/kita-init/`)
  - [ ] Déplacer le contenu généré (`lib/`, `pubspec.yaml`, `android/`, `ios/`, `test/`, `web/`, `.metadata`, `.gitignore`) à la racine du repo `/home/charles/lab/kita/` — **ATTENTION : ne PAS écraser les dossiers existants** (`_bmad/`, `_bmad-output/`, `.claude/`, `docs/`)
  - [ ] Vérifier que `flutter run` fonctionne sur émulateur/simulateur
  - [ ] Mettre à jour le SDK constraint dans `pubspec.yaml` : `sdk: ^3.10.0`

- [ ] **Task 2 : Créer la structure de répertoires** (AC: #2, #3, #4)
  - [ ] Créer tous les répertoires listés dans AC#2 avec un fichier `.gitkeep` dans chaque répertoire vide
  - [ ] Créer le miroir complet dans `test/` : `test/features/{feature}/domain/`, `test/features/{feature}/data/`, etc.
  - [ ] Créer `test/fixtures/` (ai_responses/, images/, plugins/, memory/)
  - [ ] Créer `test/mocks/`
  - [ ] Créer `integration_test/`

- [ ] **Task 3 : Configurer pubspec.yaml avec les dépendances versionnées** (AC: #6, #7)
  - [ ] Ajouter les dependencies (voir section "Library/Framework Requirements" pour les versions exactes)
  - [ ] Ajouter les dev_dependencies
  - [ ] Exécuter `flutter pub get` — doit résoudre sans conflit
  - [ ] **CRITIQUE :** Vérifier avec `flutter pub deps` que `sqlite3_flutter_libs` n'est PAS dans l'arbre de dépendances (conflit avec sqlcipher)

- [ ] **Task 4 : Configurer analysis_options.yaml** (AC: #5)
  - [ ] Configurer `flutter_lints` comme base
  - [ ] Activer `custom_lint` pour `riverpod_lint`
  - [ ] Désactiver `invalid_annotation_target` (requis pour freezed)
  - [ ] Exclure `*.g.dart` et `*.freezed.dart` de l'analyse
  - [ ] Vérifier que `dart analyze` est clean

- [ ] **Task 5 : Configurer .gitignore** (AC: #8)
  - [ ] Ajouter les patterns : `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.drift.dart`
  - [ ] Ajouter `.env`, `*.jks`, `*.keystore`, `key.properties`
  - [ ] Conserver les exclusions Flutter standard

- [ ] **Task 6 : Initialiser git et vérifier** (tous ACs)
  - [ ] `git init` + premier commit
  - [ ] Créer branche `develop` depuis `main`
  - [ ] Créer branche `epic/e1-fondation` depuis `develop`
  - [ ] Vérifier `flutter analyze` clean
  - [ ] Vérifier `flutter test` pass (tests par défaut)

## Dev Notes

### Architecture — Clean Architecture + Feature-First

Règle de dépendance stricte :
```
domain/ ← data/ ← presentation/
```
- `domain/` n'importe JAMAIS `data/` ni `presentation/`
- `data/` n'importe JAMAIS `presentation/`
- `presentation/` peut importer `domain/` (pas `data/` directement)
- Les providers Riverpod font le lien `data/` ↔ `presentation/`

### Naming Conventions (Dart Style Guide)

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Classes | UpperCamelCase | `AIRouter`, `KitaPlugin` |
| Fichiers | snake_case | `ai_router.dart`, `kita_plugin.dart` |
| Variables/fonctions | lowerCamelCase | `isAvailable`, `handleRequest()` |
| Providers Riverpod | lowerCamelCase + Provider | `aiRouterProvider` |
| Enums | UpperCamelCase + lowerCamelCase values | `RequestPriority.critical` |

### Commande d'initialisation

```bash
flutter create --org com.kita --platforms android,ios kita
```

Le projet sera créé dans un dossier temporaire (ex: `/tmp/kita-init/`). Déplacer le contenu Flutter (`lib/`, `pubspec.yaml`, `android/`, `ios/`, `test/`, `web/`, `.metadata`) à la racine du repo `/home/charles/lab/kita/`.

**CRITIQUE :** Le repo contient déjà `_bmad/`, `_bmad-output/`, `.claude/`, `docs/`. Ne PAS écraser ces dossiers. Copier uniquement les fichiers Flutter générés.

**Attention :** `flutter create` génère un `lib/main.dart` et un widget de démo. Garder `main.dart` mais remplacer le contenu de démo par un placeholder minimal qui compile.

### Project Structure Notes

Structure cible complète :
```
lib/
├── main.dart
├── app.dart                    # MaterialApp + KitaTheme + routing (Story 1.5)
├── core/
│   ├── di/                     # Riverpod providers globaux (Story 1.3)
│   ├── config/                 # app_config, environment, database_config
│   ├── errors/                 # KitaFailure, Result<T> (Story 1.2)
│   ├── theme/                  # Mix tokens, KitaTheme (Story 1.4)
│   └── utils/                  # Extensions, helpers, logger (Story 1.2)
├── features/
│   ├── ai/
│   │   ├── domain/             # AIProvider, AIRequest, AIResponse interfaces
│   │   ├── data/               # Provider implementations (E2)
│   │   └── presentation/       # (pas d'UI propre)
│   ├── io/
│   │   ├── domain/             # CameraService, STT, TTS, Haptic interfaces
│   │   ├── data/               # Platform implementations (E3)
│   │   └── presentation/       # (pas d'UI propre)
│   ├── memory/
│   │   ├── domain/             # MemoryVault, MemoryDomain interfaces
│   │   ├── data/               # Drift DAOs, tables (E4)
│   │   └── presentation/       # (pas d'UI propre)
│   ├── plugins/
│   │   ├── domain/             # KitaPlugin, PluginManifest, PluginSandbox
│   │   ├── data/               # Plugin loading, YAML parsing (E5)
│   │   ├── presentation/       # PluginViewport
│   │   └── built_in/           # describe/, alert/ (E6, E7)
│   ├── onboarding/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── shell/
│   │   └── presentation/       # KitaShell, KitaOrb, KitaInput (E8)
│   └── settings/
│       └── presentation/
├── shared/
│   ├── widgets/                # KitaAlert, KitaFeedbackBubble, etc.
│   └── multi_modal/            # ProfileAdapter, VoiceFeedback, HapticFeedback
└── platform/
    ├── ios/                    # Swift method channels
    └── android/                # Kotlin method channels
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Code Organization]
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1]
- [Source: _bmad-output/planning-artifacts/epics.md#Conventions de développement multi-agents]

## Technical Intelligence

### Flutter 3.41.2 / Dart 3.11.0 (février 2026)

- **Flutter SDK :** 3.41.2 (stable, publié février 2026)
- **Dart SDK :** 3.11.0 (bundled avec Flutter 3.41)
- **SDK constraint par défaut de `flutter create` :** `sdk: ^3.10.0`
- **Issue connue :** Test coverage cassé avec pub workspaces + `test_api` version pinning — corrigé dans 3.41.2
- **Pas d'issue connue** sur `flutter create` lui-même dans 3.41.x

### Riverpod 3.0 — Setup code generation

| Package | Version |
|---------|---------|
| `flutter_riverpod` | `^3.2.1` |
| `riverpod_annotation` | `^4.0.2` |
| `riverpod_generator` | `^4.0.3` (dev_dependency) |
| `riverpod_lint` | `^3.1.3` (dev_dependency) |
| `custom_lint` | `^0.8.1` (dev_dependency) |

**Breaking changes 3.0 :**
- `StateProvider`, `StateNotifierProvider` → déplacés dans `legacy.dart` → **NE PAS utiliser**
- Utiliser `Notifier`, `AsyncNotifier` + `@riverpod` code generation
- `Ref` n'a plus de type parameter — ref unifié
- Auto-retry activé par défaut (200ms → 6.4s backoff) — désactiver si besoin
- Notifiers recréés à chaque rebuild — ne pas stocker de ressources long-lived dedans
- `ProviderException` wrapping pour `ref.read()` / `.future`

**analysis_options.yaml requis :**
```yaml
analyzer:
  plugins:
    - custom_lint
```

### Drift 2.31.0 + SQLCipher

| Package | Version |
|---------|---------|
| `drift` | `^2.31.0` |
| `drift_dev` | `^2.31.0` (dev_dependency) |
| `sqlcipher_flutter_libs` | `^0.6.8` |
| `sqlite3` | `^2.9.4` |

**CRITIQUE — NE PAS utiliser :**
- `sqlcipher_flutter_libs` 0.7.0+ → c'est un stub EOL vide
- `drift_flutter` → importe transitivement `sqlite3_flutter_libs` → conflit natif avec sqlcipher
- `sqlite3_flutter_libs` → conflit de symboles avec `sqlcipher_flutter_libs`

**Drift n'a PAS migré vers `sqlite3` v3** (issue #3710). Rester sur `sqlite3: ^2.9.4`.

### Versions exactes de toutes les dépendances

**dependencies :**
```yaml
flutter_riverpod: ^3.2.1
riverpod_annotation: ^4.0.2
go_router: ^17.1.0
mix: ^1.7.0
drift: ^2.31.0
sqlite3: ^2.9.4
sqlcipher_flutter_libs: ^0.6.8
flutter_secure_storage: ^10.0.0
speech_to_text: ^7.3.0
flutter_tts: ^4.2.5
camera: ^0.11.4
geolocator: ^14.0.2
geocoding: ^4.0.0
sensors_plus: ^7.0.0
http: ^1.4.0
yaml: ^3.1.3
tflite_flutter: ^0.12.1
image: ^4.8.0
path_provider: ^2.1.5
path: ^1.9.0
freezed_annotation: ^3.1.0
json_annotation: ^4.11.0
permission_handler: ^12.0.1
google_mlkit_object_detection: ^0.15.1
```

**dev_dependencies :**
```yaml
build_runner: ^2.11.1
riverpod_generator: ^4.0.3
drift_dev: ^2.31.0
freezed: ^3.2.5
json_serializable: ^6.13.0
riverpod_lint: ^3.1.3
custom_lint: ^0.8.1
flutter_test:
  sdk: flutter
flutter_lints: ^5.0.0
```

### Mix 1.7.0

- Dernière version stable : `1.7.0` (juillet 2025)
- v2.0.0-rc.1 existe (février 2026) mais c'est une RC — utiliser la stable `^1.7.0`
- API : `Style()` avec utilitaires `box.height()`, `text.style.color()`, widgets `Box`, `StyledText`, `FlexBox`, `Pressable`
- Import : `import 'package:mix/mix.dart';`

## Pitfalls & Gotchas

### 1. `drift_flutter` interdit avec SQLCipher
`drift_flutter` dépend transitivement de `sqlite3_flutter_libs`. Cela crée un conflit natif avec `sqlcipher_flutter_libs` — les deux fournissent le même symbole `.so/.dylib`. **Utiliser `NativeDatabase` manuellement**, pas `drift_flutter`.

### 2. Vérifier l'arbre de dépendances après `pub get`
Exécuter `flutter pub deps | grep sqlite3_flutter_libs`. Si ce package apparaît, identifier quelle dépendance le tire et utiliser `dependency_overrides` pour le neutraliser.

### 3. `sqlcipher_flutter_libs` 0.7.0 est un stub EOL
La version 0.7.0+eol publiée en février 2026 est un no-op. **Toujours spécifier `^0.6.8`** explicitement.

### 4. analysis_options.yaml — désactiver `invalid_annotation_target`
Sans ça, `freezed` + `json_serializable` génèrent des warnings sur les annotations. Ajouter :
```yaml
analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```

### 5. Riverpod 3.0 — ne pas importer `legacy.dart`
Les anciens patterns (`StateProvider`, etc.) existent dans `legacy.dart` mais ne doivent PAS être utilisés dans ce projet. Utiliser exclusivement `@riverpod` + code generation.

### 6. `sentry_flutter` — ne pas inclure dans cette story
Sentry est opt-in et sera ajouté dans E11 (Qualité & Déploiement) quand le consentement opt-in sera implémenté. Ne pas l'ajouter au pubspec pour l'instant — ni en dependency, ni en dev_dependency.

### 7. Git branching — initialiser correctement
Après `flutter create`, initialiser git immédiatement :
```bash
git init
git add -A
git commit -m "chore: flutter create --org com.kita"
git branch develop
git checkout develop
git checkout -b epic/e1-fondation
```
Puis faire les modifications de structure sur `epic/e1-fondation`.

### 8. iOS linker flags pour SQLCipher
Sur iOS, ajouter `-framework SQLCipher` comme **premier** entry dans "Other Linker Flags" de Xcode. Ce n'est pas nécessaire pour cette story (pas d'ouverture de DB), mais documenter pour les stories suivantes.

### 9. AGP (Android Gradle Plugin) — rester sur 8.x
`flutter create` peut générer un `android/build.gradle` avec AGP 9. Vérifier et downgrader vers AGP 8.x si nécessaire — AGP 9 a des incompatibilités potentielles avec certains plugins Flutter.

### 10. Fichiers générés — ne pas les commiter
Ajouter dans `.gitignore` AVANT le premier `build_runner` :
```
*.g.dart
*.freezed.dart
*.mocks.dart
*.drift.dart
```

## Architecture Compliance

- **Clean Architecture :** `domain/` ne doit jamais importer `data/` ou `presentation/`
- **Feature isolation :** Chaque feature dans son répertoire, pas de cross-imports non déclarés
- **Core ownership :** `core/` est propriété exclusive de E1 — les autres epics n'y touchent pas
- **pubspec.yaml ownership :** Modifié uniquement par E1 — les autres epics ajoutent des `dependency_overrides` locaux si nécessaire
- **database.dart ownership :** Modifié uniquement par E1 — les features ajoutent des tables `.drift` dans leur répertoire

## Testing Requirements

- `flutter test` doit passer après chaque task
- `dart analyze` doit être clean (0 warning, 0 error)
- `dart run build_runner build --delete-conflicting-outputs` doit s'exécuter sans erreur
- Vérifier que `flutter pub deps` ne contient pas `sqlite3_flutter_libs`
- Le projet doit compiler pour Android et iOS (pas nécessaire de tester sur device pour cette story)

## Dev Agent Record

### Agent Model Used

(à remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
