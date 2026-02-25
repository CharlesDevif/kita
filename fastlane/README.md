# Kita — Fastlane

Fastlane automatise le déploiement de Kita sur le Google Play Store et l'App Store (TestFlight).

## Prérequis

- Ruby 3.1+
- Bundler : `gem install bundler`
- Flutter 3.41.2+ (dans le PATH)
- Pour Android : compte Google Play avec accès API (service account JSON)
- Pour iOS : Apple Developer account + App Store Connect API key

## Installation

```bash
bundle install
```

## Lanes disponibles

### `beta_android`

Build le AAB Flutter en release et l'upload vers la piste **internal testing** du Play Store.

```bash
bundle exec fastlane android beta_android
```

**Variables d'environnement requises :**
- `PLAY_STORE_JSON_KEY_PATH` : chemin vers le fichier JSON du compte de service Google Play

**Prérequis :**
- Créer un compte de service Google Play dans la Play Console
- Télécharger le JSON et le stocker dans un secret CI (`PLAY_STORE_JSON_KEY`) ou localement dans `fastlane/google-play-service-account.json` (jamais commité)

### `beta_ios`

Build l'IPA Flutter en release et l'upload vers **TestFlight**.

```bash
bundle exec fastlane ios beta_ios
```

**Variables d'environnement requises :**
- `APP_STORE_CONNECT_API_KEY_PATH` : chemin vers le fichier JSON de l'App Store Connect API key

**Prérequis :**
- Créer une API key dans App Store Connect → Utilisateurs → Clés
- Configurer les certificats de signature iOS (P12 + profil de provisioning)
- Stocker dans `fastlane/app-store-connect-api-key.json` (jamais commité)

### `bump_version`

Incrémente la version dans `pubspec.yaml` et le build number.

```bash
# Incrémenter le patch (défaut)
bundle exec fastlane bump_version

# Incrémenter le minor
bundle exec fastlane bump_version type:minor

# Incrémenter le major
bundle exec fastlane bump_version type:major
```

Après le bump, créer le tag git :
```bash
git add pubspec.yaml
git commit -m "chore: bump version to X.Y.Z"
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Pattern de versioning

```
version: {major}.{minor}.{patch}+{build}
         ─────────────────────  ───────
         versionName             versionCode
         (affiché sur les stores) (entier incrémental)
```

Les workflows GitHub Actions utilisent le tag git pour déclencher les builds de release (voir `.github/workflows/build-android.yml` et `build-ios.yml`).

## Fichiers secrets (jamais commités)

- `fastlane/google-play-service-account.json` — service account Google Play
- `fastlane/app-store-connect-api-key.json` — API key App Store Connect

Ces fichiers sont dans `.gitignore`. Les fournir via variables d'environnement CI.
