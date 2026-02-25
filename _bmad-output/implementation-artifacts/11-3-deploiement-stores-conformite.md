---
story_id: "11.3"
title: "Déploiement stores et conformité"
epic: "E11 — Prêt pour le monde — Qualité & Déploiement"
phase: "5"
status: review
priority: high
estimated_complexity: M
depends_on: ["11.1"]
blocks: []
---

# Story 11.3 : Déploiement stores et conformité

## Story

En tant que **responsable produit (Charles)**,
je veux **Fastlane configuré pour déployer sur les stores et la conformité vérifiée**,
afin que **Kita soit prête pour la beta fermée sur App Store et Play Store**.

## Acceptance Criteria

**AC1 — Fastfile avec lanes beta_android et beta_ios**
- `fastlane/Fastfile` existe à la racine du projet et contient la lane `beta_android` qui :
  - Build le AAB Flutter en release (`flutter build appbundle --release`)
  - Upload vers Play Store internal testing track via `upload_to_play_store` avec `track: 'internal'`
- `fastlane/Fastfile` contient la lane `beta_ios` qui :
  - Build l'IPA Flutter en release (`flutter build ipa --release`)
  - Upload vers TestFlight via `upload_to_testflight`
- `fastlane/Appfile` configure `package_name("com.kita.kita")` et `app_identifier("com.kita.kita")`
- `Gemfile` et `Gemfile.lock` présents à la racine avec `gem "fastlane"`

**AC2 — Justifications permissions Apple (Info.plist)**
- `ios/Runner/Info.plist` contient les justifications de permissions avec des textes corrects (accents inclus) :
  - `NSCameraUsageDescription` : justification complète avec accents
  - `NSMicrophoneUsageDescription` : justification complète avec accents
  - `NSLocationAlwaysAndWhenInUseUsageDescription` : justification complète avec accents
  - `NSLocationWhenInUseUsageDescription` : justification complète avec accents
  - `NSMotionUsageDescription` : justification complète avec accents
- Les justifications expliquent clairement le bénéfice pour un utilisateur aveugle (persona Marie)

**AC3 — Politique de confidentialité RGPD**
- Un fichier `docs/privacy-policy.md` contient la politique de confidentialité en français
- La politique mentionne explicitement :
  - Local-first : aucune donnée personnelle n'est transmise sans consentement explicite
  - Chiffrement AES-256 des données au repos (SQLCipher)
  - Droit à l'oubli (feature "forget everything" — Epic 4)
  - Données de handicap = données sensibles Art. 9 RGPD
  - Clés API stockées en Keychain/Keystore — jamais transmises
  - Contact RGPD et procédure d'exercice des droits
- Un `docs/privacy-policy-url.txt` contient l'URL placeholder où la politique sera hébergée

**AC4 — Data safety section Google Play**
- Un fichier `docs/google-play-data-safety.md` documente les réponses à la Data Safety section :
  - Data collected: aucune (local-first, pas de collecte serveur)
  - Data shared: aucune (les requêtes IA incluent uniquement le contenu de la requête, pas de PII)
  - Security practices: données chiffrées en transit (HTTPS) et au repos (AES-256)
  - Data deletion: oui, via feature "oubli" intégrée à l'app
- Le document sert de référence pour remplir manuellement le formulaire Play Console

**AC5 — Versioning git tags**
- `pubspec.yaml` a `version: 1.0.0-beta.1+1` (version initiale beta)
- `fastlane/Fastfile` contient une lane `bump_version` qui :
  - Lit la version courante depuis `pubspec.yaml`
  - Permet d'incrémenter major/minor/patch
  - Met à jour `pubspec.yaml` et incrémente le build number
- Un commentaire dans le Fastfile documente le pattern de release : `v{major}.{minor}.{patch}` via tags git

**AC6 — CONTRIBUTING.md**
- `CONTRIBUTING.md` existe à la racine du projet avec :
  - Comment cloner et configurer l'environnement de développement
  - Prérequis (Flutter 3.41+, Dart 3.11+, Android SDK, Xcode 15+)
  - Workflow de contribution (branches, PRs, code review)
  - Standards de code (lint, tests obligatoires, Accessibility Tax)
  - Comment lancer les tests (`flutter test`, `dart analyze`)
  - Politique d'accessibilité WCAG 2.1 AA+ — exigence non négociable
  - Références vers les documents BMAD (architecture, UX)

## Tasks / Subtasks

- [ ] Task 1 : Setup Fastlane (AC1)
  - [ ] 1.1 Créer `Gemfile` à la racine avec source rubygems.org et gem fastlane
  - [ ] 1.2 Créer `fastlane/Appfile` avec package_name et app_identifier pour `com.kita.kita`
  - [ ] 1.3 Créer `fastlane/Fastfile` avec lane `beta_android` (build AAB + upload Play Store internal)
  - [ ] 1.4 Ajouter lane `beta_ios` dans Fastfile (build IPA + upload TestFlight)
  - [ ] 1.5 Ajouter lane `bump_version` dans Fastfile (lecture/écriture pubspec.yaml)
  - [ ] 1.6 Créer `fastlane/README.md` documentant les lanes et prérequis
  - [ ] 1.7 Créer `Gemfile.lock` (généré par `bundle install` ou créé manuellement avec contenu vide pour CI)
  - [ ] 1.8 Ajouter `fastlane/report.xml`, `fastlane/screenshots/`, `fastlane/metadata/` au `.gitignore`

- [ ] Task 2 : Corriger les justifications permissions Apple (AC2)
  - [ ] 2.1 Lire `ios/Runner/Info.plist` existant (les textes actuels manquent d'accents)
  - [ ] 2.2 Corriger `NSCameraUsageDescription` avec accents complets
  - [ ] 2.3 Corriger `NSMicrophoneUsageDescription` avec accents complets
  - [ ] 2.4 Corriger `NSLocationAlwaysAndWhenInUseUsageDescription` avec accents complets
  - [ ] 2.5 Corriger `NSLocationWhenInUseUsageDescription` avec accents complets
  - [ ] 2.6 Corriger `NSMotionUsageDescription` avec accents complets
  - [ ] 2.7 S'assurer que les textes expliquent le bénéfice accessibilité (persona Marie)

- [ ] Task 3 : Politique de confidentialité RGPD (AC3)
  - [ ] 3.1 Créer `docs/privacy-policy.md` en français, complet RGPD
  - [ ] 3.2 Inclure section "données collectées" (local-first = aucune collecte serveur)
  - [ ] 3.3 Inclure section "données sensibles Art. 9" (données de handicap)
  - [ ] 3.4 Inclure section "droit à l'oubli" (procédure in-app + délai 30j)
  - [ ] 3.5 Inclure section "sécurité" (AES-256, Keychain/Keystore)
  - [ ] 3.6 Inclure section "contact RGPD" avec adresse placeholder
  - [ ] 3.7 Créer `docs/privacy-policy-url.txt` avec URL placeholder

- [ ] Task 4 : Data safety Google Play (AC4)
  - [ ] 4.1 Créer `docs/google-play-data-safety.md` avec toutes les réponses documentées
  - [ ] 4.2 Documenter chaque question du formulaire Data Safety avec réponse et justification
  - [ ] 4.3 Inclure section sur les APIs tierces utilisées (Anthropic Claude, OpenAI — requêtes uniquement, pas de PII)

- [ ] Task 5 : Versioning et pubspec.yaml (AC5)
  - [ ] 5.1 Mettre à jour `pubspec.yaml` : version `1.0.0-beta.1+1`
  - [ ] 5.2 Documenter le pattern de versioning dans `fastlane/Fastfile` (commentaires)
  - [ ] 5.3 Vérifier que `android/app/build.gradle.kts` utilise bien `flutter.versionCode` et `flutter.versionName`

- [ ] Task 6 : CONTRIBUTING.md (AC6)
  - [ ] 6.1 Créer `CONTRIBUTING.md` à la racine
  - [ ] 6.2 Section "Prérequis" (Flutter 3.41+, Dart, Android SDK, Xcode)
  - [ ] 6.3 Section "Setup développement" (clone, pub get, build_runner)
  - [ ] 6.4 Section "Workflow de contribution" (branches, PRs squash-merge, code review)
  - [ ] 6.5 Section "Standards qualité" (lint, tests, Accessibility Tax obligatoire)
  - [ ] 6.6 Section "Accessibilité" (WCAG 2.1 AA+ non négociable, Semantics requis)
  - [ ] 6.7 Section "Déploiement" (Fastlane, stores, tags git)

- [ ] Task 7 : Tests et validation (tous les ACs)
  - [ ] 7.1 Vérifier que `dart analyze --fatal-infos` est toujours clean après modifications pubspec.yaml
  - [ ] 7.2 Vérifier que `flutter test` passe toujours (aucun test cassé par les changements de version)
  - [ ] 7.3 Valider syntaxe du Fastfile (Ruby) — au moins parsing sans erreur évidente
  - [ ] 7.4 Vérifier que `ios/Runner/Info.plist` est valide XML avec `xmllint --noout`
  - [ ] 7.5 Écrire un test unitaire dart qui vérifie que la version dans pubspec.yaml respecte le pattern semver
  - [ ] 7.6 Mettre à jour sprint-status.yaml

## Dev Notes

### Architecture et ownership

Cette story appartient à **E11 (Phase 5)**. L'agent développeur peut modifier :
- Fichiers Fastlane (nouveaux) : `fastlane/`, `Gemfile`, `Gemfile.lock`
- Documentation : `docs/`, `CONTRIBUTING.md`
- Config iOS existante : `ios/Runner/Info.plist` (correction accents)
- `pubspec.yaml` **uniquement pour la version** — ne pas toucher aux dépendances

**Attention propriété fichiers protégés :** `pubspec.yaml` appartient normalement au leader (E1), mais la modification de la version (`0.1.0+1` → `1.0.0-beta.1+1`) est explicitement autorisée dans cette story E11. Si la CI/CD nécessite d'autres changements à `pubspec.yaml`, soumettre un message au leader.

### Structure Fastlane — Organisation recommandée

Kita utilise une structure Fastlane **centralisée à la racine** (pas de dossiers séparés android/ et ios/ comme dans certains guides) :

```
kita/
├── Gemfile                    # Nouveau — gem "fastlane"
├── Gemfile.lock               # Nouveau — lockfile Ruby
└── fastlane/
    ├── Appfile                # Nouveau — identifiants stores
    ├── Fastfile               # Nouveau — lanes de déploiement
    └── README.md              # Nouveau — doc des lanes
```

L'architecture confirme ce pattern : `fastlane/Fastfile`, `fastlane/Appfile`, `fastlane/Matchfile` sont attendus à la racine. [Source: architecture.md#File Organization Patterns, ligne 996-999]

### Fastfile — Contenu exact attendu

```ruby
# Gemfile (racine du projet)
source "https://rubygems.org"
gem "fastlane"
```

```ruby
# fastlane/Appfile
package_name("com.kita.kita")        # Android
app_identifier("com.kita.kita")      # iOS
# apple_id("YOUR_APPLE_ID@email.com")  # À remplir par Charles
# itc_team_id("YOUR_ITC_TEAM_ID")      # À remplir par Charles
# team_id("YOUR_TEAM_ID")              # À remplir par Charles
```

```ruby
# fastlane/Fastfile
default_platform(:ios)

# Versioning pattern: v{major}.{minor}.{patch} via tags git
# Exemple: git tag v1.0.0 && git push origin v1.0.0

platform :android do
  desc "Build and upload to Play Store internal testing track"
  lane :beta_android do
    # Construire l'AAB Flutter en release
    sh("flutter build appbundle --release")

    # Uploader vers Play Store internal testing
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      json_key: ENV['PLAY_STORE_JSON_KEY_PATH'] || 'fastlane/google-play-service-account.json',
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
    UI.success("Upload Android beta terminé!")
  end
end

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta_ios do
    # Construire l'IPA Flutter en release
    sh("flutter build ipa --release")

    # Uploader vers TestFlight
    upload_to_testflight(
      ipa: '../build/ios/ipa/kita.ipa',
      skip_waiting_for_build_processing: true,
      api_key_path: ENV['APP_STORE_CONNECT_API_KEY_PATH'] || 'fastlane/app-store-connect-api-key.json',
    )
    UI.success("Upload iOS beta terminé!")
  end
end

desc "Bump version in pubspec.yaml"
lane :bump_version do |options|
  # Options: type: "major" | "minor" | "patch"
  bump_type = options[:type] || "patch"

  pubspec_path = "../pubspec.yaml"
  content = File.read(pubspec_path)

  # Extraire version actuelle (format: major.minor.patch+build)
  if content =~ /^version:\s+(\d+)\.(\d+)\.(\d+)(?:-[^+]+)?\+(\d+)/
    major, minor, patch, build = $1.to_i, $2.to_i, $3.to_i, $4.to_i
  else
    UI.user_error!("Impossible de parser la version dans pubspec.yaml")
  end

  case bump_type
  when "major"
    major += 1; minor = 0; patch = 0
  when "minor"
    minor += 1; patch = 0
  when "patch"
    patch += 1
  end
  build += 1

  new_version = "#{major}.#{minor}.#{patch}"
  new_content = content.gsub(
    /^version:\s+.+$/,
    "version: #{new_version}+#{build}"
  )
  File.write(pubspec_path, new_content)
  UI.success("Version mise à jour: #{new_version}+#{build}")
end
```

### Identifiants existants

- **Bundle ID / Application ID:** `com.kita.kita` (confirmé dans `android/app/build.gradle.kts` et `ios/Runner/Info.plist`)
- **versionCode:** géré par `flutter.versionCode` dans build.gradle.kts (lu depuis pubspec.yaml)
- **versionName:** géré par `flutter.versionName` dans build.gradle.kts (lu depuis pubspec.yaml)
- **Build Android actuel:** Signé avec debug keys (TODO dans build.gradle.kts ligne 38) — la lane Fastlane devra builder avec release signing configuré via CI secrets

### Correction Info.plist — Accents manquants

L'Info.plist existant contient des descriptions sans accents (déjà détecté dans le code actuel). Textes à corriger :

| Clé | Texte actuel (sans accents) | Texte corrigé |
|-----|---------------------------|---------------|
| `NSCameraUsageDescription` | "...decrire votre environnement..." | "Kita utilise la caméra pour décrire votre environnement et détecter les obstacles." |
| `NSMicrophoneUsageDescription` | "...ecouter vos commandes..." | "Kita utilise le microphone pour écouter vos commandes vocales et vous assister en temps réel." |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | "...detecter votre environnement..." | "Kita utilise votre position pour détecter votre environnement et vous alerter des obstacles à proximité." |
| `NSLocationWhenInUseUsageDescription` | "...adapter les alertes..." | "Kita utilise votre position pour adapter les alertes à votre environnement immédiat." |
| `NSMotionUsageDescription` | "...adapter l assistance..." | "Kita utilise le mouvement pour adapter l'assistance selon votre activité (marche, course, immobile)." |

**Important :** Les justifications doivent mentionner explicitement le bénéfice d'accessibilité. Apple exige des justifications "meaningful" — "Kita est une application d'assistance pour les personnes malvoyantes" peut être ajouté pour plus de clarté et augmenter les chances d'approbation.

### Data Safety Google Play — Réponses attendues

Pour une application local-first avec chiffrement :

| Question Play Console | Réponse Kita | Justification |
|----------------------|-------------|---------------|
| Collecte-t-elle des données ? | **Non** (local-first) | Toutes les données restent sur l'appareil. Les requêtes IA incluent uniquement le contenu de la requête (pas de PII comme nom, localisation précise, etc.) |
| Partage-t-elle des données ? | **Partiellement** | Les requêtes envoyées aux providers IA (Anthropic, OpenAI) contiennent le contexte de la requête mais pas de données d'identification |
| Les données sont-elles chiffrées en transit ? | **Oui** | HTTPS pour toutes les requêtes API externes |
| Les données sont-elles chiffrées au repos ? | **Oui** | SQLCipher AES-256 pour la base de données locale |
| L'utilisateur peut-il demander la suppression ? | **Oui** | Feature "forget everything" (Epic 4, Story 4.3) |
| Politique de confidentialité ? | **Oui** | URL à renseigner dans la Play Console |

**Note importante :** Le champ `context` de `AIRequest` est metadata interne — jamais envoyé aux providers IA selon les règles de qualité du projet. [Source: CLAUDE.md#Règles de qualité Phase 2]

### Versioning strategy

Flutter utilise `pubspec.yaml` comme source de vérité pour les versions :
```yaml
version: 1.0.0-beta.1+1
#        ───────────── ─
#        versionName   versionCode
#        (App Store/Play Store display)
```

Le pattern de release via tags git : `v1.0.0-beta.1` → `v1.0.0` → `v1.1.0` etc.

La lane `bump_version` automatise la mise à jour de `pubspec.yaml`. En CI/CD, le build number peut être automatiquement incrémenté via le numéro de run GitHub Actions (`GITHUB_RUN_NUMBER`).

**Version initiale beta :** `1.0.0-beta.1+1` — le suffixe `-beta.1` est affiché aux testeurs, le `+1` est le build number interne.

### CONTRIBUTING.md — Structure recommandée

```markdown
# Contributing to Kita

## Prérequis
- Flutter 3.41.2 / Dart 3.11.0
- Android SDK (API 31+, target 35)
- Xcode 15+ (pour iOS, macOS uniquement)
- Ruby + Bundler (pour Fastlane)

## Setup
1. `git clone https://github.com/[org]/kita && cd kita`
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter test`

## Workflow
- Branches: `epic/e{N}-{nom}` depuis `develop`
- PRs: squash-merge vers `develop`
- Chaque story = 1 PR avec Dev Agent Record

## Qualité obligatoire
- `dart analyze --fatal-infos` doit être clean
- `flutter test --coverage` doit passer avec couverture > 80%
- `Semantics` wrapper sur chaque widget interactif (Accessibility Tax)

## Accessibilité (non négociable)
- WCAG 2.1 AA+ sur tous les écrans
- Touch targets >= 48x48px
- Contraste texte >= 4.5:1
- Tests Semantics obligatoires dans chaque widget test
```

### Pitfalls & Gotchas

1. **Fastlane `match` non recommandé pour ce MVP** — Les erreurs "No provisioning profile provided" avec fastlane match + Flutter sont fréquentes en 2025. Pour la beta, utiliser la signature manuelle (certificats téléchargés depuis Apple Developer Portal) ou `App Store Connect API key` avec `upload_to_testflight` directement. Ne pas implémenter `fastlane/Matchfile` dans cette story — le laisser commenté ou vide.

2. **Service Account Google Play** — Le fichier JSON `google-play-service-account.json` NE DOIT PAS être commité dans le repo (données sensibles). Le Fastfile doit lire le chemin depuis la variable d'environnement `PLAY_STORE_JSON_KEY_PATH`. Ajouter `fastlane/google-play-service-account.json` au `.gitignore`.

3. **App Store Connect API Key** — Même principe : `fastlane/app-store-connect-api-key.json` dans `.gitignore`, chemin via variable d'env `APP_STORE_CONNECT_API_KEY_PATH`.

4. **pubspec.yaml version pre-release** — Flutter supporte les pre-release versions (`1.0.0-beta.1+1`). Le versionName transmis au store sera `1.0.0-beta.1`, le versionCode sera `1`. Vérifier que `flutter build appbundle --release` ne produit pas d'erreur avec ce format.

5. **Textes Info.plist — Apple revoit les justifications** — Apple App Review peut rejeter une app si les justifications NSUsageDescription sont génériques. Les textes doivent expliquer **pourquoi** l'app a besoin de la permission, pas juste "l'app utilise X". Inclure toujours la mention du bénéfice utilisateur.

6. **Fastfile Ruby syntax** — Le Fastfile est du Ruby. Les `sh()` calls exécutent des commandes shell. Le chemin vers le AAB est relatif au répertoire `fastlane/`, donc `../build/...` est correct. Vérifier le chemin exact de l'IPA avec `flutter build ipa --release --verbose`.

7. **Pas de Gemfile.lock dans le repo de base** — Si Ruby/Bundler n'est pas installé localement, créer un Gemfile.lock minimal ou le générer via GitHub Actions avec `bundle install`. Pour ce MVP, créer un Gemfile.lock avec contenu généré par `bundle lock` si possible, sinon le laisser avec version pinned manuellement.

8. **RGPD Art. 9 — données de handicap** — Le profil d'accessibilité de l'utilisateur (aveugle, malvoyant, sourd) est classé comme donnée sensible selon l'Article 9 du RGPD. La politique de confidentialité doit le mentionner explicitement et préciser que ces données ne quittent jamais l'appareil.

9. **Accessibility Nutrition Labels Apple (2025)** — Apple a introduit les "Accessibility Nutrition Labels" dans App Store Connect. Kita devrait les remplir en déclarant le support de VoiceOver, Dynamic Type, et réduction de mouvement. Ce n'est pas encore obligatoire en 2025 mais recommandé pour le positionnement accessibilité.

10. **Android ID deprecated (avril 2025)** — Depuis avril 2025, l'Android ID n'est plus considéré comme un identifiant persistant. Kita n'utilise pas d'Android ID (local-first), donc pas d'impact, mais le mentionner dans la data safety section si pertinent.

11. **Chemin IPA Flutter** — `flutter build ipa --release` génère l'IPA dans `build/ios/ipa/`. Le nom exact dépend du `CFBundleDisplayName` dans Info.plist. Pour Kita c'est `Kita.ipa` ou `kita.ipa` — vérifier avec `ls build/ios/ipa/` après le build.

12. **CI/CD interaction** — Cette story crée les fichiers Fastlane mais ne les intègre PAS au pipeline GitHub Actions (c'est Story 11.1 qui gère le CI). Les lanes Fastlane sont pour usage local ou manuel depuis CI. Ne pas modifier `.github/workflows/ci.yml` dans cette story.

### Références architecture

- `fastlane/Fastfile` — [Source: architecture.md#File Organization Patterns, ligne 1172]
- `fastlane/Appfile` et `fastlane/Matchfile` — [Source: architecture.md#Structure, ligne 996-999]
- `fastlane/Fastfile` + CD Play Store + TestFlight — [Source: architecture.md#Development Workflow Integration, ligne 1208-1212]
- Application ID Android : `com.kita.kita` — [Source: android/app/build.gradle.kts, ligne 9]
- Bundle ID iOS : dérivé de `$(PRODUCT_BUNDLE_IDENTIFIER)` — [Source: ios/Runner/Info.plist, ligne 14]
- RGPD Art. 9, chiffrement AES-256 — [Source: architecture.md#Sécurité, ligne 70-71]

### Fichiers existants à lire avant de coder

| Fichier | Raison |
|---------|--------|
| `ios/Runner/Info.plist` | Corriger les accents dans les justifications permissions |
| `android/app/build.gradle.kts` | Vérifier versionCode/versionName Flutter |
| `pubspec.yaml` | Mettre à jour la version |
| `.gitignore` | Ajouter les exclusions Fastlane |
| `.github/workflows/ci.yml` | Comprendre le contexte CI existant (NE PAS MODIFIER) |

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Date

2026-02-25

### Debug Log References

- `dart analyze --fatal-infos lib/` → No issues found.
- `flutter test` → 1436 tests passed (including 5 new versioning tests).
- `ios/Runner/Info.plist` XML validated via Python `xml.etree.ElementTree`.

### Completion Notes List

1. **Fastlane setup (AC1)**: Created `Gemfile`, `Gemfile.lock` (pinned stub), `fastlane/Appfile`, `fastlane/Fastfile` (lanes: `beta_android`, `beta_ios`, `bump_version`), `fastlane/README.md`. All lanes follow the story spec exactly.

2. **Info.plist accents (AC2)**: All 5 NSUsageDescription keys corrected with proper French accents and accessibility-focused justifications (mentioning blind/low-vision users — persona Marie). XML validated.

3. **Privacy policy RGPD (AC3)**: Created `docs/privacy-policy.md` with all required sections: local-first, Art. 9 données de santé, AES-256, droit à l'oubli, Keychain/Keystore, contact RGPD. Created `docs/privacy-policy-url.txt` placeholder.

4. **Data Safety Google Play (AC4)**: Created `docs/google-play-data-safety.md` covering all Play Console form questions with justifications.

5. **Versioning (AC5)**: Updated `pubspec.yaml` version from `0.1.0+1` to `1.0.0-beta.1+1` (authorized for E11). Fastfile `bump_version` lane reads/writes pubspec.yaml with semver pattern. Added `.gitignore` entries for Fastlane sensitive files (`google-play-service-account.json`, `app-store-connect-api-key.json`, `report.xml`, `screenshots/`, `metadata/`).

6. **CONTRIBUTING.md (AC6)**: Created comprehensive contributor guide with prerequisites (Flutter 3.41+), setup steps, branch workflow, quality standards (lint, tests, Accessibility Tax), accessibility WCAG 2.1 AA+, deployment instructions.

7. **Versioning test (Task 7.5)**: Created `test/versioning_test.dart` with 5 tests verifying semver pattern, correct beta version, major >= 1, positive build number. All pass.

### Workarounds / Decisions

- `Gemfile.lock` created as a minimal stub (pinned fastlane 2.227.0) rather than running `bundle install` since Ruby bundler is not available in the dev environment. CI will regenerate it.
- `xmllint` not available; XML validation done via Python `xml.etree.ElementTree` — equivalent check.
- `integration_test` SDK package was not in `pubspec.yaml` (requested from leader for Story 11.2). `flutter test` picked it up as a transitive dep via `flutter_driver` — tests in `test/` directory all pass.

### File List

**Créés :**
- `Gemfile` — Configuration Ruby/Fastlane
- `Gemfile.lock` — Lockfile Ruby (stub with fastlane 2.227.0 pinned)
- `fastlane/Appfile` — Identifiants stores (com.kita.kita)
- `fastlane/Fastfile` — Lanes beta_android, beta_ios, bump_version
- `fastlane/README.md` — Documentation des lanes et prérequis
- `docs/privacy-policy.md` — Politique de confidentialité RGPD complète en français
- `docs/privacy-policy-url.txt` — URL placeholder (https://kita.app/privacy-policy)
- `docs/google-play-data-safety.md` — Réponses Data Safety Google Play Console
- `CONTRIBUTING.md` — Guide contributeurs avec prérequis, workflow, qualité, accessibilité
- `test/versioning_test.dart` — 5 tests semver (pattern, version beta, major>=1, build>0)

**Modifiés :**
- `ios/Runner/Info.plist` — 5 NSUsageDescription avec accents corrects + justifications accessibilité
- `pubspec.yaml` — Version mise à jour de `0.1.0+1` à `1.0.0-beta.1+1`
- `.gitignore` — Ajout exclusions Fastlane (report.xml, screenshots/, metadata/, JSON secrets)
- `_bmad-output/implementation-artifacts/11-3-deploiement-stores-conformite.md` — Dev Agent Record + status review
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Status → review
