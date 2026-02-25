# Story 11.1 : Pipeline CI/CD complet

Status: review

## Story

En tant que **développeur**,
je veux **un pipeline CI/CD qui teste, lintte, vérifie l'accessibilité et build automatiquement**,
afin que **chaque PR est validée automatiquement et les releases sont fiables**.

## Acceptance Criteria

**AC1 — Pipeline CI principal (`.github/workflows/ci.yml`) :**
- **Given** le CI stub existe (1-8-ci-cd-stub-infrastructure-open-source)
- **When** le pipeline est déclenché sur push/PR vers `main` ou `develop`
- **Then** les étapes s'exécutent séquentiellement : `dart analyze --fatal-infos` → `flutter test --coverage` → vérification couverture > 80% → tests d'accessibilité (Semantics matchers)

**AC2 — Tests accessibilité BLOQUANTS :**
- **Given** le pipeline CI tourne
- **When** un test avec `@Tags(['accessibility'])` échoue ou qu'un widget interactif n'a pas de `Semantics` wrapper
- **Then** le job échoue et la PR est bloquée (pas de `continue-on-error: true` sur l'étape a11y)

**AC3 — Couverture > 80% bloquante :**
- **Given** `flutter test --coverage` a généré `coverage/lcov.info`
- **When** la couverture filtrée (hors `*.g.dart`, `*.freezed.dart`, `*.drift.dart`) est calculée
- **Then** le job échoue si la couverture est < 80% via `VeryGoodOpenSource/very_good_coverage@v2`

**AC4 — Build Android (`.github/workflows/build-android.yml`) :**
- **Given** le CI principal passe
- **When** le workflow `build-android.yml` se déclenche
- **Then** l'APK et l'AAB release sont buildés avec le flavor `--dart-define=ENV=prod`
- **And** les artifacts sont uploadés (actions/upload-artifact)

**AC5 — Build iOS (`.github/workflows/build-ios.yml`) :**
- **Given** le CI principal passe
- **When** le workflow `build-ios.yml` se déclenche sur `macos-latest`
- **Then** l'IPA est buildé en release avec `--no-codesign` (pour CI sans Apple certificate)
- **And** les artifacts `.xcarchive` ou `.ipa` sont uploadés

**AC6 — Flavors supportés :**
- **Given** les workflows build Android et iOS
- **When** les builds sont lancés
- **Then** les trois flavors `dev`, `staging`, `prod` sont supportés via `--dart-define=ENV={flavor}`
- **And** les builds CI utilisent le flavor `prod` par défaut

**AC7 — Tests vérifiant le pipeline :**
- **Given** les workflows GitHub Actions existent
- **When** les tests du projet sont lancés (`flutter test`)
- **Then** un fichier de test `test/ci/pipeline_validation_test.dart` vérifie la présence et la structure des 3 fichiers workflow
- **And** les tests passent en local sans dépendance GitHub

## Tasks / Subtasks

- [ ] Task 1 : Finaliser `.github/workflows/ci.yml` (AC1, AC2, AC3)
  - [ ] 1.1 : Supprimer `continue-on-error: true` sur l'étape tests accessibilité — les rendre BLOQUANTS
  - [ ] 1.2 : Remplacer le check de couverture manuel par `VeryGoodOpenSource/very_good_coverage@v2` avec `min-coverage: 80`
  - [ ] 1.3 : S'assurer que le path lcov passé à very_good_coverage est **absolu** : `${{ github.workspace }}/coverage/lcov.info`
  - [ ] 1.4 : Ajouter l'exclusion des fichiers générés dans very_good_coverage via le paramètre `exclude`
  - [ ] 1.5 : Vérifier que le job `analyze-and-test` a `flutter test --tags accessibility` SANS `continue-on-error`
  - [ ] 1.6 : Ajouter un step `Upload coverage report` via `actions/upload-artifact` (optionnel, non bloquant)

- [ ] Task 2 : Créer `.github/workflows/build-android.yml` (AC4, AC6)
  - [ ] 2.1 : Créer le fichier workflow avec `on: workflow_dispatch` + `push: tags: ['v*']`
  - [ ] 2.2 : Runner `ubuntu-24.04`, setup Flutter 3.41.2, `flutter pub get`
  - [ ] 2.3 : Step `Generate code` : `dart run build_runner build --delete-conflicting-outputs`
  - [ ] 2.4 : Step `Build APK` : `flutter build apk --release --dart-define=ENV=prod`
  - [ ] 2.5 : Step `Build AAB` : `flutter build appbundle --release --dart-define=ENV=prod`
  - [ ] 2.6 : Step `Upload artifacts` : uploader `build/app/outputs/flutter-apk/app-release.apk` et `build/app/outputs/bundle/release/app-release.aab`
  - [ ] 2.7 : Ajouter support flavors via input `env` avec `workflow_dispatch.inputs.env` (dev/staging/prod, défaut: prod)

- [ ] Task 3 : Créer `.github/workflows/build-ios.yml` (AC5, AC6)
  - [ ] 3.1 : Créer le fichier workflow avec `on: workflow_dispatch` + `push: tags: ['v*']`
  - [ ] 3.2 : Runner `macos-latest` (requis pour build iOS)
  - [ ] 3.3 : Setup Flutter 3.41.2 avec cache
  - [ ] 3.4 : Step `Install CocoaPods dependencies` : `cd ios && pod install`
  - [ ] 3.5 : Step `Build iOS` : `flutter build ipa --release --no-codesign --dart-define=ENV=prod`
  - [ ] 3.6 : Step `Upload artifacts` : uploader le dossier `build/ios/archive/`
  - [ ] 3.7 : Ajouter support flavors via `workflow_dispatch.inputs.env` (dev/staging/prod, défaut: prod)

- [ ] Task 4 : Créer les tests de validation pipeline (AC7)
  - [ ] 4.1 : Créer le répertoire `test/ci/`
  - [ ] 4.2 : Créer `test/ci/pipeline_validation_test.dart`
  - [ ] 4.3 : Test : vérifier que `.github/workflows/ci.yml` existe
  - [ ] 4.4 : Test : vérifier que `.github/workflows/build-android.yml` existe
  - [ ] 4.5 : Test : vérifier que `.github/workflows/build-ios.yml` existe
  - [ ] 4.6 : Test : vérifier que `ci.yml` contient `dart analyze --fatal-infos`
  - [ ] 4.7 : Test : vérifier que `ci.yml` contient `flutter test --coverage`
  - [ ] 4.8 : Test : vérifier que `ci.yml` contient `very_good_coverage` (couverture bloquante)
  - [ ] 4.9 : Test : vérifier que `ci.yml` NE contient PAS `continue-on-error: true` pour les tests accessibilité
  - [ ] 4.10 : Test : vérifier que `build-android.yml` contient `flutter build appbundle`
  - [ ] 4.11 : Test : vérifier que `build-ios.yml` contient `flutter build ipa --no-codesign`
  - [ ] 4.12 : Test : vérifier que les flavors `ENV=prod` sont présents dans les build workflows

- [ ] Task 5 : Vérification et nettoyage final
  - [ ] 5.1 : Lancer `dart analyze --fatal-infos` — doit être clean
  - [ ] 5.2 : Lancer `flutter test` — tous les tests passent (incluant les nouveaux tests pipeline)
  - [ ] 5.3 : Vérifier manuellement la syntaxe YAML des 3 workflows (pas d'erreur d'indentation)
  - [ ] 5.4 : Mettre à jour `sprint-status.yaml` → story `11-1-pipeline-ci-cd-complet` et epic `epic-11` en `in-progress`

## Dev Notes

### Technical Intelligence

#### 1. Stub CI existant (`.github/workflows/ci.yml`)

Le stub créé en Story 1.8 est déjà fonctionnel avec :
- `dart analyze --fatal-infos` ✓
- `flutter test --coverage` ✓
- `dart run build_runner build --delete-conflicting-outputs` ✓
- Filtrage lcov (exclusion `*.g.dart`, `*.freezed.dart`, `*.drift.dart`) ✓
- Flutter 3.41.2 via `subosito/flutter-action@v2` ✓

**Ce qui manque et doit être fixé :**
1. Tests accessibilité avec `continue-on-error: true` → **BLOQUER** (supprimer ce flag)
2. Seuil de couverture non implémenté → **ajouter very_good_coverage**
3. Aucun workflow build Android/iOS → **créer**

#### 2. VeryGoodOpenSource/very_good_coverage@v2

**Action GitHub recommandée pour l'enforcement du seuil de couverture :**

```yaml
- name: Check coverage threshold
  uses: VeryGoodOpenSource/very_good_coverage@v2
  with:
    path: '${{ github.workspace }}/coverage/lcov.info'
    min_coverage: 80
    exclude: |
      **/*.g.dart
      **/*.freezed.dart
      **/*.drift.dart
      **/generated/**
```

**Point critique :** Le paramètre `path` doit être un **chemin absolu**. L'action ignore le `working-directory` du job. Utiliser `${{ github.workspace }}/coverage/lcov.info`.

**Note :** Le paramètre `exclude` dans very_good_coverage permet de spécifier des patterns glob (un par ligne) pour exclure des fichiers de la mesure. Cependant, le filtrage lcov avec `lcov --remove` doit AUSSI être conservé pour que les fichiers exclus ne gonflent pas artificiellement le nombre de lignes couvertes.

**Alternative manuelle (si très_good_coverage pose problème) :**
```bash
COVERAGE=$(lcov --summary coverage/lcov_filtered.info 2>&1 | grep "lines" | grep -oP '\d+\.\d+(?=%)' | head -1)
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
  echo "Coverage $COVERAGE% is below 80% threshold"
  exit 1
fi
```

#### 3. Tests d'accessibilité bloquants

Dans le stub actuel :
```yaml
- name: Run accessibility tests
  continue-on-error: true  # ← SUPPRIMER cette ligne
  run: flutter test --tags accessibility
```

**Convention de tags dans le projet Kita :** Les tests d'accessibilité utilisent `@Tags(['accessibility'])` via `package:test/test.dart`. Exemple :
```dart
@Tags(['accessibility'])
library;

void main() {
  testWidgets('KitaOrb has semantics label', (tester) async {
    // ...
    expect(semantics, hasSemantics(/* ... */));
  });
}
```

**Vérification :** Les tags `accessibility` existent dans les tests du projet (chercher dans `test/features/shell/presentation/`). Si aucun test n'a le tag `accessibility` actuellement, le step `flutter test --tags accessibility` ne fera rien mais ne plantera pas — c'est correct, il sera bloquant quand les tests s'y conformeront.

#### 4. Build Android — Flavors via dart-define

**Architecture Kita (CLAUDE.md)** : Les flavors utilisent `--dart-define=ENV=dev|staging|prod`.

**Dans `build-android.yml` :**
```yaml
- name: Build APK (release)
  run: flutter build apk --release --dart-define=ENV=${{ inputs.env || 'prod' }}

- name: Build AAB (release)
  run: flutter build appbundle --release --dart-define=ENV=${{ inputs.env || 'prod' }}
```

**Chemin des artifacts :**
- APK : `build/app/outputs/flutter-apk/app-release.apk`
- AAB : `build/app/outputs/bundle/release/app-release.aab`

**Note `android/app/build.gradle.kts` :** Le fichier actuel utilise `flutter.minSdkVersion` (résolu par le plugin Flutter Gradle à API 31 conforme au CLAUDE.md). La config de signing release est en `debug` (TODO dans le stub) — **ne pas toucher** pour Story 11.1, c'est pour Story 11.3 (Fastlane).

#### 5. Build iOS — No Codesign

Pour CI sans Apple Developer Certificate, `flutter build ipa --no-codesign` produit l'archive sans signer :
```yaml
- name: Build iOS (no codesign)
  run: flutter build ipa --release --no-codesign --dart-define=ENV=${{ inputs.env || 'prod' }}
```

**Artifact produit :** `build/ios/archive/Runner.xcarchive` (pas un vrai `.ipa` signé). L'artifact est uploadé pour être traité par Fastlane en Story 11.3.

**Runner `macos-latest`** : Obligatoire pour iOS. Le runner Linux ne peut pas compiler pour iOS.

**CocoaPods :** Requis avant le build iOS :
```yaml
- name: Install CocoaPods dependencies
  run: cd ios && pod install
  working-directory: ${{ github.workspace }}
```

#### 6. Tests de validation pipeline — Approche dart:io

Les tests `test/ci/pipeline_validation_test.dart` lisent les fichiers YAML comme du texte et vérifient leur contenu :

```dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Pipeline CI/CD validation', () {
    test('ci.yml exists', () {
      final file = File('.github/workflows/ci.yml');
      expect(file.existsSync(), isTrue, reason: '.github/workflows/ci.yml doit exister');
    });

    test('ci.yml contains dart analyze --fatal-infos', () {
      final content = File('.github/workflows/ci.yml').readAsStringSync();
      expect(content, contains('dart analyze --fatal-infos'));
    });

    test('a11y tests are blocking (no continue-on-error)', () {
      final content = File('.github/workflows/ci.yml').readAsStringSync();
      // Vérifier que "accessibility" n'est pas accompagné de "continue-on-error: true"
      final lines = content.split('\n');
      bool inA11yStep = false;
      for (final line in lines) {
        if (line.contains('accessibility')) inA11yStep = true;
        if (inA11yStep && line.contains('continue-on-error: true')) {
          fail('Tests accessibilité ne doivent pas avoir continue-on-error: true');
        }
        if (inA11yStep && line.trimLeft().startsWith('- name:')) inA11yStep = false;
      }
    });
  });
}
```

**Important :** Ces tests utilisent des chemins **relatifs** (`File('.github/workflows/ci.yml')`). Ils doivent être lancés depuis la racine du projet (`flutter test test/ci/`). En CI, le `working-directory` est toujours la racine du repo, donc c'est correct.

#### 7. Concurrence et cache

Le CI existant gère déjà la concurrence :
```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```
**Ne pas modifier** — cette configuration est optimale pour les PRs (annule les runs précédents sur la même branche).

### Pitfalls & Gotchas

1. **`very_good_coverage` chemin absolu obligatoire** — Le paramètre `path` doit être `${{ github.workspace }}/coverage/lcov.info`, PAS `./coverage/lcov.info`. L'action ignore le `working-directory` du step. C'est une erreur classique qui cause silencieusement une coverage à 0% ou un skip de la vérification. [Source : VeryGoodOpenSource/very_good_coverage README]

2. **`continue-on-error: true` supprimé sur a11y** — Le stub 1.8 a cette ligne pour ne pas bloquer avant que les tests a11y soient complets. Story 11.1 DOIT la supprimer. Sans cette suppression, AC2 n'est pas rempli.

3. **`flutter test --tags accessibility` sans tests tagués** — Si aucun test dans le projet n'a `@Tags(['accessibility'])`, la commande retourne exit code 0 (pas de tests = pas d'erreur). Ce n'est pas un problème pour cette story — les tests tagués sont dans les features shell/UI et seront découverts correctement.

4. **iOS build sur `macos-latest`** — GitHub Actions facture les runners macOS plus cher que Linux (10x). Le workflow `build-ios.yml` doit être déclenché manuellement (`workflow_dispatch`) ou sur tags `v*` uniquement, pas sur chaque PR, pour limiter les coûts.

5. **`pod install` vs `pod update`** — Toujours utiliser `pod install` (pas `update`) en CI pour reproduire l'environnement exact du `Podfile.lock`. Si `Podfile.lock` n'est pas commité → c'est un problème séparé, ne pas le résoudre dans cette story.

6. **Signing Android release** — Le `build.gradle.kts` actuel utilise `signingConfigs.getByName("debug")` pour les builds release (TODO du stub). Le build APK/AAB fonctionnera en CI mais l'APK ne sera pas déployable sans signing réel. C'est intentionnel pour MVP — le signing production sera géré en Story 11.3 via Fastlane.

7. **`build_runner` en CI** — Toujours lancer `dart run build_runner build --delete-conflicting-outputs` AVANT `dart analyze` et `flutter test`. Les fichiers `*.g.dart` et `*.freezed.dart` ne sont pas commités (`.gitignore`), donc le CI doit les régénérer. Le stub 1.8 le fait déjà correctement.

8. **Tests pipeline `dart:io` path** — Les tests `test/ci/pipeline_validation_test.dart` utilisent `File('.github/workflows/ci.yml')`. Ces chemins **relatifs** fonctionnent uniquement si le répertoire courant est la racine du projet. En CI (`flutter test`), c'est toujours le cas. En local, lancer depuis `/home/charles/lab/kita/`.

9. **lcov filter avant very_good_coverage** — Garder LES DEUX étapes : le filtrage `lcov --remove` ET very_good_coverage. L'étape lcov produit `coverage/lcov_filtered.info` mais very_good_coverage lit `coverage/lcov.info`. Solution : soit passer `lcov_filtered.info` à very_good_coverage, soit utiliser le paramètre `exclude` de very_good_coverage pour éviter de doubler le filtrage.

10. **Workflow YAML indentation** — GitHub Actions YAML est strict sur l'indentation. Toujours utiliser 2 espaces, jamais de tabs. Une indentation incorrecte cause une erreur cryptique "Invalid workflow file" sans ligne précise.

### Architecture Compliance

- **Fichiers touchés** : uniquement `.github/workflows/` et `test/ci/` — aucun fichier `lib/` modifié
- **Propriété des fichiers** : L'agent E11 possède `.github/workflows/` et les tests de validation
- **Fichiers protégés** : Ne pas modifier `pubspec.yaml`, `lib/core/`, `analysis_options.yaml`
- **Convention de nommage** : Les workflows suivent le pattern `{action}-{plateforme}.yml` (`build-android.yml`, `build-ios.yml`)
- **Flavors** : Utiliser `--dart-define=ENV=dev|staging|prod` (CLAUDE.md architecture.md §Development Workflow Integration)
- **Tests** : Les tests `test/ci/` font partie du test suite standard — ils s'exécutent avec `flutter test`

### Project Structure Notes

```
.github/
└── workflows/
    ├── ci.yml              ← MODIFIER (stub existant, corriger a11y + couverture)
    ├── build-android.yml   ← CRÉER
    └── build-ios.yml       ← CRÉER

test/
└── ci/
    └── pipeline_validation_test.dart  ← CRÉER
```

**Pas de modification dans `lib/`** — Cette story est purement infrastructure CI/CD + tests de validation.

### References

- [Source: `.github/workflows/ci.yml`] — Stub CI créé en Story 1.8 à corriger
- [Source: `_bmad-output/planning-artifacts/architecture.md` §Infrastructure & Deploiement] — Pipeline CI/CD table : étapes bloquantes
- [Source: `_bmad-output/planning-artifacts/architecture.md` §Development Workflow Integration] — Commandes build, flavors, dart-define
- [Source: `_bmad-output/planning-artifacts/architecture.md` §File Organization Patterns] — Structure `integration_test/`, `test/`
- [Source: `_bmad-output/planning-artifacts/epics.md` §Story 11.1] — Acceptance Criteria originaux
- [Source: `android/app/build.gradle.kts`] — Config Gradle actuelle (signing debug, minSdk flutter)
- [Source: CLAUDE.md §Pièges techniques globaux] — Conventions Dart/Flutter, qualité tests
- [Source: VeryGoodOpenSource/very_good_coverage@v2](https://github.com/VeryGoodOpenSource/very_good_coverage) — Action GitHub pour enforcement seuil couverture
- [Source: subosito/flutter-action@v2](https://github.com/subosito/flutter-action) — Setup Flutter en GitHub Actions
- [Source: flutter build ipa --no-codesign](https://github.com/flutter/flutter/issues/101765) — Build iOS sans certificate en CI

### Learnings des stories précédentes (Phase 4 → Phase 5)

**De Story 10.4 (Integration Gate Phase 4) :**
- Le projet a maintenant ~100+ fichiers de test et une suite qui passe (sauf 1 pre-existing failure dans `widget_test.dart` non liée au pipeline)
- Les tests `test/integration/` utilisent un pattern de mocks complets des services natifs — ce pattern doit être maintenu
- `dart analyze --fatal-infos` est propre depuis la Story 10.4

**Git intelligence (commits récents) :**
- `d046101 Phase 4 retrospective + stories marked done` — toutes les stories Phase 4 sont done
- `22a85b1 Fix Phase 4 code review findings` — qualité code est bonne
- Le projet est prêt pour la Phase 5 (E11)

**État de la couverture actuelle :** Inconnue précisément (non mesurée en CI de façon bloquante). Le seuil 80% peut être ambitieux — si la couverture réelle est en dessous, il faudra soit ajouter des tests (Story 11.2), soit réduire temporairement le seuil. **Recommandation :** Implémenter le pipeline, lancer une fois en mode "measure only" (seuil à 0%), mesurer la couverture réelle, puis remonter le seuil progressivement.

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Date

2026-02-25

### Completion Notes List

- Les 3 fichiers workflow existaient déjà (`.github/workflows/ci.yml`, `build-android.yml`, `build-ios.yml`) et `test/ci/pipeline_validation_test.dart` également — travail antérieur d'un autre agent.
- Le `ci.yml` était déjà correct : pas de `continue-on-error` sur le step accessibilité, `VeryGoodOpenSource/very_good_coverage@v2` présent avec chemin absolu, filtrage lcov en place.
- Les workflows `build-android.yml` et `build-ios.yml` étaient complets avec flavors, artifacts et runners corrects.
- **Seul correctif nécessaire :** Les tests de validation `test/ci/pipeline_validation_test.dart` échouaient car ils cherchaient la chaîne littérale `ENV=prod` alors que le YAML utilise l'expression GitHub Actions `ENV=${{ inputs.env || 'prod' }}`. Corrigé les 2 tests pour vérifier `--dart-define=ENV=` et `|| 'prod'` séparément.
- `dart analyze --fatal-infos lib/` : clean (aucune issue).
- `flutter test` : 1431 tests passent, exit code 0.

### File List

**Modifié :**
- `test/ci/pipeline_validation_test.dart` — correction des 2 tests "contains ENV=prod flavor" pour vérifier le pattern correct (`--dart-define=ENV=` + `|| 'prod'`)
- `_bmad-output/implementation-artifacts/11-1-pipeline-ci-cd-complet.md` — Dev Agent Record rempli + statut review
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — statut `11-1-pipeline-ci-cd-complet` → `review`

**Existants (conformes, non modifiés) :**
- `.github/workflows/ci.yml` — pipeline principal avec a11y bloquant + very_good_coverage + filtrage lcov
- `.github/workflows/build-android.yml` — build APK + AAB avec flavors et artifacts
- `.github/workflows/build-ios.yml` — build IPA no-codesign sur macos-latest avec flavors et artifacts

### Change Log

- 2026-02-25 : Correction des tests de validation pipeline (ENV=prod literal → pattern correct) + Dev Agent Record
