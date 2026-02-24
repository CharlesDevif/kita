# Story 1.8: CI/CD stub et infrastructure open source

Status: done

## Story

As a **developpeur**,
I want **le pipeline CI de base et les fichiers open source en place**,
So that **chaque PR est automatiquement lintee et testee des le premier commit**.

## Acceptance Criteria

1. **Given** le projet est complet avec patterns et interfaces (Stories 1.1-1.7) **When** l'infrastructure CI est mise en place **Then** `.github/workflows/ci.yml` execute : `dart analyze`, `flutter test`, couverture de code

2. **And** `dart run build_runner build` est execute comme step CI obligatoire avant les tests

3. **And** les tests existants (Stories 1.2, 1.3, 1.5, 1.6) passent dans la CI

4. **And** `flutter test --tags accessibility` verifie la presence des Semantics sur les widgets interactifs

5. **And** `.env.example` contient le template des cles API

6. **And** `.gitignore` exclut correctement les fichiers sensibles et generes

7. **And** `test/fixtures/` contient les golden fixtures partagees : `ai_responses/` (vision_success.json, vision_fallback.json), `images/` (test_photo.jpg avec EXIF, test_photo_stripped.jpg), `plugins/` (valid_manifest.yaml, invalid_manifest.yaml), `memory/` (episode_sample.json, user_profile_sample.json)

8. **And** `LICENSE` contient la licence MIT

9. **And** les templates GitHub (bug report, feature request, PR template) sont crees dans `.github/`

10. **And** `assets/sounds/` contient les fichiers son de fallback (alert_danger.wav, alert_warning.wav, confirmation.wav)

## Tasks / Subtasks

- [x] **Task 1 : Creer le workflow CI GitHub Actions** (AC: #1, #2, #3, #4)
  - [x]Creer `.github/workflows/ci.yml`
  - [x]Configurer le trigger : `on: push` (branches `main`, `develop`) + `on: pull_request` (branches `main`, `develop`)
  - [x]Step 1 : `actions/checkout@v4`
  - [x]Step 2 : `subosito/flutter-action@v2` avec `flutter-version: '3.41.2'` et `channel: 'stable'` + cache activee
  - [x]Step 3 : `flutter pub get`
  - [x]Step 4 : `dart run build_runner build --delete-conflicting-outputs`
  - [x]Step 5 : `dart analyze --fatal-infos`
  - [x]Step 6 : `flutter test --coverage` — execute tous les tests
  - [x]Step 7 : `flutter test --tags accessibility` — step separee pour verifier les Semantics
  - [x]Step 7b : Installer lcov (`sudo apt-get update && sudo apt-get install -y lcov`) — necessaire car lcov n'est pas pre-installe sur les runners GitHub Actions
  - [x]Step 8 : Filtrer la couverture avec `lcov --remove` pour exclure les fichiers generes. Utiliser des patterns recursifs (`'**/*.g.dart'`, `'**/*.freezed.dart'`, `'**/*.drift.dart'`) — les patterns bare (`'*.g.dart'`) ne matchent pas les chemins complets
  - [x]Step 9 : Verifier le seuil de couverture (ajouter un script inline bash ou utiliser une action)
  - [x]Configurer le cache pub dependencies avec la cle basee sur `pubspec.lock`

- [x] **Task 2 : Mettre a jour .gitignore** (AC: #6)
  - [x]Verifier que `.gitignore` existant couvre bien tous les patterns requis
  - [x]Ajouter `*.drift.dart` si absent
  - [x]Verifier la presence de `*.env`, `*.env.*`, `*.jks`, `*.keystore`, `**/secrets/`, `**/credentials/`
  - [x]Ajouter `coverage/` et `*.lcov` si absent
  - [x]Verifier que `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` sont bien exclus

- [x] **Task 3 : Creer .env.example** (AC: #5)
  - [x]Creer `.env.example` a la racine du projet avec le template des cles API
  - [x]Inclure : `ANTHROPIC_API_KEY=`, `OPENAI_API_KEY=`, `SENTRY_DSN=` (optionnel)
  - [x]Ajouter un commentaire header expliquant l'usage
  - [x]Verifier que `.env` et `.env.*` sont dans `.gitignore`

- [x] **Task 4 : Creer les golden fixtures** (AC: #7)
  - [x]Creer `test/fixtures/ai_responses/vision_success.json` — reponse AI simulee pour une description photo reussie
  - [x]Creer `test/fixtures/ai_responses/vision_fallback.json` — reponse AI degradee/fallback
  - [x]Creer `test/fixtures/images/test_photo.jpg` — image de test minimale (1x1px JPEG) avec EXIF metadata
  - [x]Creer `test/fixtures/images/test_photo_stripped.jpg` — meme image sans EXIF
  - [x]Creer `test/fixtures/plugins/valid_manifest.yaml` — manifest plugin valide (format `plugin.kita.yaml`)
  - [x]Creer `test/fixtures/plugins/invalid_manifest.yaml` — manifest avec erreurs (champs manquants, types invalides)
  - [x]Creer `test/fixtures/memory/episode_sample.json` — episode memoire type avec tous les champs
  - [x]Creer `test/fixtures/memory/user_profile_sample.json` — profil utilisateur type avec preferences

- [x] **Task 5 : Creer le fichier LICENSE** (AC: #8)
  - [x]Creer `LICENSE` a la racine avec la licence MIT complete
  - [x]Annee 2026, titulaire "Kita Contributors"

- [x] **Task 6 : Creer les templates GitHub** (AC: #9)
  - [x]Creer `.github/ISSUE_TEMPLATE/bug_report.md` avec frontmatter YAML et sections structurees
  - [x]Creer `.github/ISSUE_TEMPLATE/feature_request.md` avec frontmatter YAML et sections structurees
  - [x]Creer `.github/PULL_REQUEST_TEMPLATE.md` avec checklist de review
  - [x](Optionnel) Creer `.github/ISSUE_TEMPLATE/config.yml` pour le chooser d'issues

- [x] **Task 7 : Creer les assets son de fallback** (AC: #10)
  - [x]Creer `assets/sounds/alert_danger.wav` — fichier WAV 16-bit mono valide (peut etre un silence court ou un ton genere)
  - [x]Creer `assets/sounds/alert_warning.wav` — fichier WAV 16-bit mono valide
  - [x]Creer `assets/sounds/confirmation.wav` — fichier WAV 16-bit mono valide
  - [x]Ajouter la declaration `assets/sounds/` dans la section `flutter: assets:` de `pubspec.yaml` — cette section n'existe pas encore, il faut la creer. Ne pas se contenter de verifier : `pubspec.yaml` n'a actuellement aucune declaration d'assets

- [x] **Task 8 : Verification finale** (AC: #1-#10)
  - [x]Executer `dart analyze --fatal-infos` — doit etre clean
  - [x]Executer `flutter test` — tous les tests existants passent
  - [x]Verifier que le workflow CI est syntaxiquement valide (optionnel: `actionlint` ou validation manuelle YAML)
  - [x]Verifier que les fixtures JSON sont du JSON valide
  - [x]Verifier que les fichiers WAV ont un header valide
  - [x]Mettre a jour `sprint-status.yaml` quand la story change de statut

## Dev Notes

### Architecture CI/CD (architecture.md)

Le pipeline CI est defini dans l'architecture comme suit :

| Etape | Outil | Bloquant |
|-------|-------|----------|
| Lint | `dart analyze` + rules custom | Oui |
| Tests unitaires | `flutter test` | Oui |
| Tests a11y | Semantics matchers | Oui |
| Couverture | `flutter test --coverage` (>80%) | Oui |
| Build Android | `flutter build apk/appbundle` | Non (Story 11.1) |
| Build iOS | `flutter build ipa` | Non (Story 11.1) |

**Important :** Story 1.8 cree le **stub CI** — lint + tests + couverture uniquement. Les builds Android/iOS et le pipeline complet sont dans Story 11.1 (Phase 5). Le seuil de couverture >80% est l'objectif final; pour le stub, configurer le mecanisme sans bloquer sur un seuil precis (les premieres stories n'auront pas 80% de couverture globale).

### Relation avec Story 11.1

Story 11.1 etendra ce CI stub avec :
- Workflows separes `build-android.yml` et `build-ios.yml`
- Tests a11y BLOQUANTS (pas juste informatifs)
- Seuil de couverture >80% enforced
- Flavors dev/staging/prod dans les builds
- Fastlane integration

Le stub de Story 1.8 doit etre concu pour etre facilement etendu.

### Propriete des fichiers

Story 1.8 est dans E1 (Fondation) — elle a le droit de modifier tous les fichiers du projet, y compris `core/` et `pubspec.yaml`. Cependant, cette story ne devrait modifier `pubspec.yaml` que si necessaire (ex: ajout de `lcov` parsing ou assets declaration).

### Structure des fichiers crees

```
kita/
├── .github/
│   ├── workflows/
│   │   └── ci.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── config.yml                # Optionnel: chooser
│   └── PULL_REQUEST_TEMPLATE.md
├── .env.example
├── .gitignore                         # MAJ si necessaire
├── LICENSE                            # MIT
├── assets/
│   └── sounds/
│       ├── alert_danger.wav
│       ├── alert_warning.wav
│       └── confirmation.wav
└── test/
    └── fixtures/
        ├── ai_responses/
        │   ├── vision_success.json
        │   └── vision_fallback.json
        ├── images/
        │   ├── test_photo.jpg
        │   └── test_photo_stripped.jpg
        ├── plugins/
        │   ├── valid_manifest.yaml
        │   └── invalid_manifest.yaml
        └── memory/
            ├── episode_sample.json
            └── user_profile_sample.json
```

### Test tags Flutter

Les tags de test Flutter permettent de filtrer les tests a executer. Pour marquer un test avec le tag `accessibility` :

**Au niveau du fichier :**
```dart
@Tags(['accessibility'])
library;

import 'package:flutter_test/flutter_test.dart';
// ...
```

**Au niveau d'un test individuel :**
```dart
testWidgets('widget has Semantics', (tester) async {
  // ...
}, tags: ['accessibility']);
```

**Configuration `dart_test.yaml` (racine du projet) :**
```yaml
tags:
  accessibility:
    description: "Tests verifying accessibility Semantics compliance"
```

**Execution :**
```bash
flutter test --tags accessibility    # uniquement les tests tagges
flutter test                          # tous les tests
```

### Golden fixtures — format attendu

Les fixtures sont des fichiers de reference utilises par les tests de toutes les features. Elles doivent etre coherentes avec les interfaces definies dans Story 1.7.

**`vision_success.json` — Format AIResponse :**
```json
{
  "content": "A busy street crossing with a traffic light showing red. Two people are waiting on the left sidewalk.",
  "meta": {
    "provider": "claude",
    "latency_ms": 2340,
    "tier": "cloudPowerful",
    "cached": false
  },
  "status": "success"
}
```

**`vision_fallback.json` — Format AIResponse degrade :**
```json
{
  "content": "Image detected. Unable to provide detailed description.",
  "meta": {
    "provider": "mlkit_local",
    "latency_ms": 45,
    "tier": "local",
    "cached": false
  },
  "status": "degraded"
}
```

**`valid_manifest.yaml` — Format plugin.kita.yaml :**
```yaml
id: com.kita.test-plugin
name: Test Plugin
version: 1.0.0
description: A test plugin for fixture validation
author: Kita Team
trust_level: official
min_kita_version: 1.0.0
permissions:
  sensors:
    - camera
    - microphone
  ai:
    - vision
    - text
  memory: read_write
profiles:
  - blind
  - low_vision
  - general
voice_commands:
  - "test"
  - "demo"
```

**`invalid_manifest.yaml` — Manifest avec erreurs :**
```yaml
# Missing required fields: id, name, version
description: An invalid manifest
trust_level: unknown_level
permissions:
  sensors: "not_a_list"
```

**`episode_sample.json` — Format Episode :**
```json
{
  "id": "ep_001",
  "timestamp": "2026-02-23T14:30:00.000Z",
  "type": "describe",
  "summary": "User described a street scene",
  "plugin_id": "com.kita.describe",
  "tags": ["outdoor", "navigation"],
  "data": {
    "photo_hash": "abc123",
    "description": "A busy street crossing"
  },
  "important": false
}
```

**`user_profile_sample.json` — Format UserProfile :**
```json
{
  "id": "user_001",
  "profile_type": "blind",
  "display_name": "Marie",
  "created_at": "2026-02-20T10:00:00.000Z",
  "preferences": {
    "tts_speed": 1.2,
    "tts_voice": "default",
    "haptic_enabled": true,
    "reduced_motion": false,
    "font_scale": 1.0
  },
  "active_plugins": ["com.kita.describe", "com.kita.alert"],
  "providers": {
    "primary": "claude",
    "api_key_configured": true
  },
  "accessibility": {
    "screen_reader_active": true,
    "screen_reader_type": "voiceover"
  }
}
```

## Technical Intelligence

### GitHub Actions — Flutter CI workflow

**Action recommandee :** `subosito/flutter-action@v2` (>5k stars, activement maintenu)

Version actuelle : v2 (derniere release : v2.18+). Supporte :
- `flutter-version` : version exacte ou pattern (`3.41.x`)
- `channel` : `stable`, `beta`, `master`
- `cache` : cache le SDK Flutter et pub packages
- `flutter-version-file` : lire la version depuis `pubspec.yaml`

**Workflow CI complet recommande :**
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  analyze-and-test:
    name: Analyze & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.2'
          channel: 'stable'
          cache: true
          cache-key: 'flutter-:os:-:channel:-:version:-:arch:-:hash:'
          cache-path: '${{ runner.tool_cache }}/flutter/:channel:-:version:-:arch:'

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code (build_runner)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Run tests with coverage
        run: flutter test --coverage

      - name: Run accessibility tests
        continue-on-error: true  # Informational in stub CI — will become blocking in Story 11.1
        run: flutter test --tags accessibility

      - name: Install lcov
        run: sudo apt-get update && sudo apt-get install -y lcov

      - name: Filter coverage (exclude generated files)
        run: |
          lcov --remove coverage/lcov.info \
            '**/*.g.dart' \
            '**/*.freezed.dart' \
            '**/*.drift.dart' \
            -o coverage/lcov_filtered.info

      - name: Check coverage threshold
        run: |
          if [ -f coverage/lcov.info ]; then
            echo "Coverage report generated successfully"
            # Threshold enforcement will be added in Story 11.1
          fi
```

**Cles de conception :**
- `concurrency` avec `cancel-in-progress: true` — annule les runs precedents sur la meme branche/PR pour economiser des minutes CI
- `cache: true` dans flutter-action — cache le SDK Flutter + pub dependencies automatiquement
- `--fatal-infos` sur `dart analyze` — traite les infos comme des erreurs (plus strict)
- La step accessibility est separee pour une visibilite claire dans les logs CI

### Caching dans GitHub Actions

**Cache automatique par flutter-action :**
`subosito/flutter-action@v2` avec `cache: true` gere le cache du SDK Flutter et des pub packages automatiquement. La cle de cache est basee sur l'OS, le channel, la version et l'architecture.

**Cache supplementaire optionnel :**
Si les temps CI sont trop longs, ajouter un cache explicite pour `.dart_tool/` et `build/` :
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ${{ github.workspace }}/.dart_tool
      ${{ github.workspace }}/build
    key: build-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
    restore-keys: |
      build-${{ runner.os }}-
```

### Coverage — lcov filtering

Flutter genere le fichier de couverture dans `coverage/lcov.info`. Les fichiers generes (`*.g.dart`, `*.freezed.dart`) polluent les metriques. La commande `lcov --remove` filtre ces fichiers :

```bash
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  '**/*.freezed.dart' \
  '**/*.drift.dart' \
  -o coverage/lcov_filtered.info
```

**Important :** Les patterns doivent utiliser `**/*.g.dart` (recursive glob) et non `*.g.dart` (bare glob). Les bare patterns ne matchent pas les chemins complets comme `lib/features/ai/domain/models/ai_response.g.dart` — seuls les globs recursifs fonctionnent correctement avec `lcov --remove`.

**Note :** `lcov` n'est pas installe par defaut sur `ubuntu-latest`. Il faut l'installer explicitement via une step CI :
```yaml
- name: Install lcov
  run: sudo apt-get update && sudo apt-get install -y lcov
```
Ne pas utiliser de garde conditionnelle `if command -v lcov` — installer lcov explicitement garantit un comportement deterministe.

### Fichiers WAV — generation minimale

Les fichiers WAV de fallback doivent etre des fichiers audio valides. Pour le stub, des fichiers WAV minimaux (silence ou ton simple) suffisent. Un fichier WAV valide a un header de 44 bytes minimum.

**Option 1 — Generer avec `sox` (si disponible) :**
```bash
sox -n -r 44100 -c 1 -b 16 alert_danger.wav synth 0.5 sine 880
sox -n -r 44100 -c 1 -b 16 alert_warning.wav synth 0.5 sine 660
sox -n -r 44100 -c 1 -b 16 confirmation.wav synth 0.3 sine 440
```

**Option 2 — Generer avec `ffmpeg` :**
```bash
ffmpeg -f lavfi -i "sine=frequency=880:duration=0.5" -ar 44100 -ac 1 -sample_fmt s16 alert_danger.wav
ffmpeg -f lavfi -i "sine=frequency=660:duration=0.5" -ar 44100 -ac 1 -sample_fmt s16 alert_warning.wav
ffmpeg -f lavfi -i "sine=frequency=440:duration=0.3" -ar 44100 -ac 1 -sample_fmt s16 confirmation.wav
```

**Option 3 — Ecrire les bytes manuellement :**
Si aucun outil n'est disponible, creer un script Dart qui ecrit un fichier WAV minimal (header 44 bytes + quelques samples PCM). Voir section Pitfalls #5.

**Specifications :**
- Format : WAV PCM 16-bit
- Canaux : Mono (1 channel)
- Sample rate : 44100 Hz
- `alert_danger.wav` : ~0.5s, ton aigu (880 Hz)
- `alert_warning.wav` : ~0.5s, ton moyen (660 Hz)
- `confirmation.wav` : ~0.3s, ton bas (440 Hz)

### Images de test — EXIF metadata

`test_photo.jpg` doit contenir des metadonnees EXIF (GPS, camera model, etc.) pour tester le stripping EXIF dans les stories futures.

**Option 1 — Utiliser `exiftool` :**
```bash
# Creer une image JPEG minimale puis ajouter EXIF
convert -size 100x100 xc:gray test_photo.jpg
exiftool -GPSLatitude=48.8566 -GPSLongitude=2.3522 -Make="TestCamera" -Model="TestModel" test_photo.jpg
```

**Option 2 — Image binaire minimale :**
Creer un JPEG valide minimal (quelques centaines d'octets) avec un segment EXIF. Le format JPEG supporte un segment APP1 pour les donnees EXIF.

`test_photo_stripped.jpg` est la meme image sans le segment EXIF.

### GitHub Templates — format recommande

**Bug report (`bug_report.md`) :**
```markdown
---
name: Bug Report
about: Report a bug to help us improve Kita
title: "[Bug] "
labels: bug
assignees: ''
---

## Description
A clear description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Screenshots
If applicable, add screenshots.

## Environment
- Device: [e.g., Pixel 8, iPhone 15]
- OS: [e.g., Android 14, iOS 17]
- Kita version: [e.g., 1.0.0]
- Screen reader: [e.g., TalkBack, VoiceOver, none]

## Accessibility Impact
Does this bug affect accessibility features? If so, describe.

## Additional Context
Any other context about the problem.
```

**Feature request (`feature_request.md`) :**
```markdown
---
name: Feature Request
about: Suggest a feature for Kita
title: "[Feature] "
labels: enhancement
assignees: ''
---

## Problem
What problem does this feature solve?

## Proposed Solution
Describe the feature you'd like.

## Accessibility Considerations
How does this feature affect users with disabilities?

## Alternatives Considered
Other solutions you've considered.

## Additional Context
Any other context or screenshots.
```

**PR template (`PULL_REQUEST_TEMPLATE.md`) :**
```markdown
## Summary
Brief description of changes.

## Related Issue
Fixes #(issue number)

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation
- [ ] CI/CD

## Checklist
- [ ] `dart analyze` is clean
- [ ] Tests pass (`flutter test`)
- [ ] New code has tests
- [ ] Semantics wrappers on interactive widgets
- [ ] No PII in logs
- [ ] Accessibility: contrast >= 4.5:1, touch targets >= 48x48px

## Accessibility Review
- [ ] Screen reader tested (VoiceOver/TalkBack)
- [ ] Semantic labels are descriptive
- [ ] N/A (no UI changes)

## Screenshots / Recordings
If applicable, add screenshots of UI changes.
```

### dart_test.yaml configuration

Creer un fichier `dart_test.yaml` a la racine pour declarer les tags personnalises :

```yaml
tags:
  accessibility:
    description: "Tests verifying accessibility Semantics compliance"
```

Sans ce fichier, `flutter test --tags accessibility` affiche un warning sur les tags inconnus.

## Pitfalls & Gotchas

### 1. Flutter version pinning dans la CI

**Probleme :** Si la CI utilise `channel: 'stable'` sans version exacte, la version Flutter peut changer entre deux runs, causant des echecs imprevisibles.

**Solution :** Toujours specifier `flutter-version: '3.41.2'` dans le workflow. Mettre a jour cette version explicitement quand le projet migre.

### 2. build_runner AVANT les tests

**Probleme :** Si `build_runner` n'est pas execute avant `flutter test`, les fichiers generes (`*.g.dart`, `*.freezed.dart`) manquent et les tests echouent.

**Solution :** Le step `dart run build_runner build --delete-conflicting-outputs` doit etre place AVANT `dart analyze` ET `flutter test`. L'ordre est : `pub get` -> `build_runner` -> `analyze` -> `test`.

### 3. lcov pas installe sur ubuntu-latest

**Probleme :** `lcov` n'est pas disponible par defaut sur les runners GitHub Actions `ubuntu-latest`.

**Solution :** Ajouter une step :
```yaml
- name: Install lcov
  run: sudo apt-get install -y lcov
```
Ou contourner en parsant `lcov.info` directement avec un script bash/dart.

### 4. Cache invalidation apres mise a jour Flutter

**Probleme :** Le cache de `subosito/flutter-action` peut devenir stale si la version Flutter change mais le cache n'est pas invalide.

**Solution :** La cle de cache par defaut inclut la version Flutter. Si le cache est suspect, changer la `cache-key` dans le workflow ou incrementer manuellement un suffixe.

### 5. Generation de fichiers WAV binaires

**Probleme :** Les fichiers WAV doivent etre des binaires valides, pas du texte. Si `sox` ou `ffmpeg` ne sont pas disponibles, il faut les generer autrement.

**Solution Dart (script de generation) :**
```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Generates a minimal WAV file with a sine wave tone.
void generateWav(String path, double frequency, double durationSec) {
  const sampleRate = 44100;
  const bitsPerSample = 16;
  const numChannels = 1;
  final numSamples = (sampleRate * durationSec).toInt();
  final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  var offset = 0;

  // RIFF header
  void writeString(String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset++, s.codeUnitAt(i));
    }
  }
  writeString('RIFF');
  buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
  writeString('WAVE');

  // fmt subchunk
  writeString('fmt ');
  buffer.setUint32(offset, 16, Endian.little); offset += 4;
  buffer.setUint16(offset, 1, Endian.little); offset += 2; // PCM
  buffer.setUint16(offset, numChannels, Endian.little); offset += 2;
  buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
  buffer.setUint32(offset, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 4;
  buffer.setUint16(offset, numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 2;
  buffer.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

  // data subchunk
  writeString('data');
  buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

  // PCM samples
  for (var i = 0; i < numSamples; i++) {
    final sample = (sin(2 * pi * frequency * i / sampleRate) * 16000).toInt();
    buffer.setInt16(offset, sample, Endian.little); offset += 2;
  }

  File(path).writeAsBytesSync(buffer.buffer.asUint8List());
}
```

Ce script peut etre place dans `tool/generate_wav.dart` et execute avec `dart run tool/generate_wav.dart`. Alternativement, les fichiers WAV peuvent etre generes une fois localement et commites directement.

### 6. Images JPEG de test — taille minimale

**Probleme :** Creer un JPEG valide avec EXIF est non-trivial en pur Dart.

**Solution :** Utiliser `ImageMagick` ou `ffmpeg` pour generer l'image :
```bash
# Image 100x100 grise avec EXIF
convert -size 100x100 xc:gray test_photo.jpg
exiftool -GPSLatitude=48.8566 -GPSLongitude=2.3522 test_photo.jpg
cp test_photo.jpg test_photo_stripped.jpg
exiftool -all= test_photo_stripped.jpg
```

Si ces outils ne sont pas disponibles, inclure des fichiers JPEG binaires pre-generes (quelques Ko).

### 7. Seuil de couverture — ne pas bloquer au debut

**Probleme :** Les stories 1.1-1.7 n'auront pas 80% de couverture globale. Forcer ce seuil dans le stub CI bloquerait toutes les PR.

**Solution :** Dans le stub CI, mesurer et reporter la couverture SANS bloquer. Le seuil bloquant >80% sera ajoute dans Story 11.1 quand le projet aura suffisamment de code et de tests.

### 8. Accessibility tests — tag configuration requise

**Probleme :** `flutter test --tags accessibility` echoue avec un warning si le tag n'est pas declare dans `dart_test.yaml`.

**Solution :** Creer `dart_test.yaml` a la racine du projet (voir section Technical Intelligence). Si aucun test n'est tagge `accessibility` dans les stories 1.2-1.7, la step CI reussira mais n'executera rien. C'est OK pour le stub — les tests accessibility seront ajoutes par les stories UI (Phase 2+).

### 9. concurrency — eviter les runs paralleles couteux

**Probleme :** Plusieurs pushes rapides sur la meme branche lancent des workflows en parallele, consommant des minutes CI inutilement.

**Solution :** Configurer `concurrency` dans le workflow :
```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```
Cela annule automatiquement les runs precedents quand un nouveau push arrive.

### 10. .env.example — ne PAS inclure de vraies cles

**Probleme :** Un developpeur pourrait accidentellement remplir `.env.example` avec de vraies cles API.

**Solution :** `.env.example` ne contient que des placeholders vides ou des descriptions. Les vraies cles vont dans `.env` (qui est dans `.gitignore`). Ajouter un commentaire en haut du fichier pour rappeler cette regle.

### 11. pubspec.lock — conflit entre .gitignore et cache CI

**Probleme :** Le `.gitignore` actuel exclut `pubspec.lock`. Or, pour un projet application (pas un package), Dart/Flutter recommande de commiter `pubspec.lock` pour garantir des builds reproductibles. De plus, la strategie de cache CI utilise `hashFiles('pubspec.lock')` comme cle — ce qui echoue si le fichier n'est pas dans le repo.

**Solution :** Retirer `pubspec.lock` du `.gitignore`. Pour un projet application comme Kita, commiter `pubspec.lock` est la bonne pratique. Alternativement, si on choisit de garder `pubspec.lock` dans `.gitignore`, changer la cle de cache CI pour utiliser `hashFiles('pubspec.yaml')` a la place. L'option recommandee est de retirer `pubspec.lock` du `.gitignore`.

### 12. *.drift.dart absent de analysis_options.yaml

**Probleme :** `analysis_options.yaml` exclut `*.g.dart` et `*.freezed.dart` de l'analyse, mais pas `*.drift.dart`. Les fichiers generes par Drift (`*.drift.dart`) peuvent contenir du code qui declenche des warnings ou infos. Avec `dart analyze --fatal-infos` dans la CI, cela peut causer des echecs inattendus sur du code genere.

**Solution :** Ajouter `'**/*.drift.dart'` a la liste `analyzer: exclude:` dans `analysis_options.yaml`, aux cotes de `*.g.dart` et `*.freezed.dart` :
```yaml
analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
    - '**/*.drift.dart'
```

### 13. ubuntu-latest — version non deterministe

**Probleme :** `runs-on: ubuntu-latest` dans le workflow CI peut changer de version Ubuntu sous-jacente sans preavis (ex: passage de Ubuntu 22.04 a 24.04). Cela peut causer des echecs CI imprevisibles, notamment avec les packages natifs (lcov, SQLCipher build tools).

**Solution :** Envisager de pinner la version Ubuntu dans le workflow : `runs-on: ubuntu-24.04` au lieu de `ubuntu-latest`. Cela garantit un environnement stable et des mises a jour controlees.

### 14. --coverage + --tags — couverture incomplete

**Probleme :** Ne PAS combiner `flutter test --coverage --tags accessibility` dans une seule commande. Le flag `--tags` filtre les tests executes, donc `--coverage` ne mesurerait que la couverture des tests accessibility — pas la couverture globale du projet. Cela genererait un rapport `lcov.info` incomplet et fausse.

**Solution :** Garder les deux steps separees comme dans le workflow actuel :
1. `flutter test --coverage` — execute TOUS les tests et genere le rapport de couverture complet
2. `flutter test --tags accessibility` — execute uniquement les tests d'accessibilite (sans `--coverage`)

Ne jamais fusionner ces deux steps.

## References

- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure & Deploiement]
- [Source: _bmad-output/planning-artifacts/architecture.md#Complete Project Directory Structure]
- [Source: _bmad-output/planning-artifacts/architecture.md#File Organization Patterns]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.8]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.1] (CI complet — Story 1.8 est le stub)
- [Source: CLAUDE.md#Conventions de code]
- [Source: CLAUDE.md#Pieges techniques globaux]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- H1 fix: `.gitignore` pattern `*.env.*` was catching `.env.example` — added `!.env.example` negation
- H2 fix: ImageMagick `-set EXIF:Make` did not inject real APP1 segment — used Python script to inject proper EXIF TIFF structure

### Completion Notes List

- CI workflow uses `ubuntu-24.04` (pinned) instead of `ubuntu-latest` per Pitfall #13
- Accessibility tests `continue-on-error: true` (informational stub, will become blocking in Story 11.1)
- Coverage threshold not enforced yet (stub only, Story 11.1)
- Fixtures in `test/fixtures/` created by Story 1.7 — format matches domain interfaces (flat camelCase), not the nested format in Story 1.8 spec. 1.7 format retained as canonical.
- `pubspec.lock` removed from `.gitignore` per Pitfall #11 (app, not package)
- `*.drift.dart` added to both `.gitignore` and `analysis_options.yaml` exclude
- WAV files generated via ffmpeg (PCM 16-bit mono 44100Hz)
- JPEG test images: `test_photo.jpg` has EXIF APP1 segment (Make=TestCamera, Model=TestModel), `test_photo_stripped.jpg` is clean JFIF

### File List

**Created:**
- `.github/workflows/ci.yml`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.env.example`
- `LICENSE`
- `dart_test.yaml`
- `assets/sounds/alert_danger.wav`
- `assets/sounds/alert_warning.wav`
- `assets/sounds/confirmation.wav`
- `test/fixtures/images/test_photo.jpg`
- `test/fixtures/images/test_photo_stripped.jpg`

**Modified:**
- `.gitignore` — added `*.drift.dart`, removed `pubspec.lock`, added `!.env.example`
- `analysis_options.yaml` — added `"**/*.drift.dart"` to exclude list
- `pubspec.yaml` — added `assets/sounds/` to flutter assets
- `test/core/navigation/router_test.dart` — added `tags: ['accessibility']` to Semantics tests
