# Kita — Guide de setup développeur

Guide d'installation multi-plateforme pour contribuer au projet Kita.

## Versions requises

| Outil | Version minimale | Notes |
|-------|-----------------|-------|
| Flutter | 3.41+ | Inclut Dart 3.11+ |
| Android SDK | API 31+ (target 35) | Pour le build Android |
| Java JDK | 17+ | Requis par Android SDK |
| Xcode | 15+ | macOS uniquement, pour le build iOS |
| Chrome | Dernière stable | Pour le build web |

---

## 1. Prérequis par plateforme

### Linux (Ubuntu/Debian)

```bash
sudo apt-get update && sudo apt-get install -y \
  curl git unzip xz-utils zip \
  libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev
```

**Java :**
```bash
# Via apt
sudo apt-get install -y openjdk-17-jdk

# Ou via Homebrew
brew install openjdk
```

### macOS

```bash
# Xcode command line tools (requis)
xcode-select --install

# Xcode complet (requis pour iOS)
# Installer depuis le Mac App Store, puis :
sudo xcodebuild -license accept

# CocoaPods (requis pour iOS)
brew install cocoapods

# Java
brew install openjdk
```

### Windows

1. **Git** : Installer [Git for Windows](https://git-scm.com/download/win)
2. **Visual Studio 2022** : Installer avec le workload "Desktop development with C++" (requis pour le build Windows desktop)
3. **Java** : Installer [JDK 17+](https://adoptium.net/) (Adoptium recommandé)

---

## 2. Android SDK

Commun aux 3 plateformes.

**Option A — Via Android Studio (recommandé) :**
1. Installer [Android Studio](https://developer.android.com/studio)
2. Ouvrir SDK Manager (Settings > Languages & Frameworks > Android SDK)
3. Installer :
   - SDK Platform : `Android 14 (API 35)` ou plus récent
   - SDK Tools : `Android SDK Build-Tools 35.0.0`, `Android SDK Command-line Tools`, `Android SDK Platform-Tools`

**Option B — Command-line tools uniquement :**
1. Télécharger les [command-line tools](https://developer.android.com/studio#command-line-tools-only)
2. Installer les composants via `sdkmanager`

**Variables d'environnement :**

Linux/macOS (`~/.zshrc` ou `~/.bashrc`) :
```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

Windows (variables système) :
```
ANDROID_HOME = C:\Users\<user>\AppData\Local\Android\Sdk
PATH += %ANDROID_HOME%\platform-tools
```

---

## 3. Installation Flutter

### Linux

```bash
mkdir -p ~/development && cd ~/development
curl -fsSL -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.2-stable.tar.xz
tar xf flutter.tar.xz && rm flutter.tar.xz
```

Ajouter au PATH (`~/.zshrc` ou `~/.bashrc`) :
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

### macOS

```bash
mkdir -p ~/development && cd ~/development
curl -fsSL -o flutter.zip https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.2-stable.zip
unzip flutter.zip && rm flutter.zip
```

> Pour Intel Mac, remplacer `arm64` par `x64` dans l'URL.

Ajouter au PATH (`~/.zshrc`) :
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

### Windows

1. Télécharger le [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) (fichier `.zip`)
2. Extraire dans `C:\development\flutter`
3. Ajouter `C:\development\flutter\bin` au PATH système (Paramètres > Variables d'environnement)

---

## 4. Finaliser l'installation

Commun aux 3 plateformes.

```bash
# Recharger le shell
source ~/.zshrc    # Linux/macOS

# Désactiver les analytics (optionnel)
flutter --disable-analytics
dart --disable-analytics

# Accepter les licences Android
flutter doctor --android-licenses

# Vérifier que tout est OK
flutter doctor
```

**Résultat attendu :**
```
[✓] Flutter (Channel stable, 3.41.2, ...)
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] Linux toolchain (Linux) / Xcode (macOS) / Visual Studio (Windows)
[✓] Connected device
[✓] Network resources
```

---

## 5. Setup du projet

```bash
git clone <repo-url> kita
cd kita
flutter pub get
```

### Vérification post-install

```bash
# Le code generation doit fonctionner
dart run build_runner build --delete-conflicting-outputs

# Les tests doivent passer
flutter test

# L'analyse statique doit être clean
dart analyze

# CRITIQUE : sqlite3_flutter_libs ne doit PAS apparaitre
flutter pub deps | grep sqlite3_flutter_libs
# (aucun résultat = OK)
```

### Lancer l'app

```bash
# Android (émulateur ou device connecté)
flutter run

# iOS (macOS uniquement, simulateur ou device)
flutter run -d iphone

# Linux desktop
flutter run -d linux

# macOS desktop
flutter run -d macos

# Windows desktop
flutter run -d windows

# Chrome
flutter run -d chrome
```

---

## Pièges connus

| Piège | Solution |
|-------|---------|
| `sqlite3_flutter_libs` dans les dépendances | Conflit natif avec `sqlcipher_flutter_libs`. Vérifier avec `flutter pub deps`. Voir CLAUDE.md. |
| `drift_flutter` importé | Interdit — importe transitivement `sqlite3_flutter_libs`. Utiliser `NativeDatabase` manuellement. |
| `sqlcipher_flutter_libs` 0.7.0+ | C'est un stub EOL vide. Utiliser `^0.6.8`. |
| AGP 9 dans `android/build.gradle` | Peut causer des incompatibilités. Rester sur AGP 8.x. |
| `*.g.dart` commités | Ces fichiers sont générés. Ne jamais les commiter. Vérifier `.gitignore`. |
| iOS : SQLCipher ne charge pas | Ajouter `-framework SQLCipher` en premier dans "Other Linker Flags" (Xcode). |
| Windows : OpenSSL manquant pour SQLCipher | `choco install openssl` avant le build. |
| Linux : libssl-dev manquant pour SQLCipher | `sudo apt install libssl-dev` avant le build. |

---

## Ressources

- [CLAUDE.md](../CLAUDE.md) — Conventions projet, architecture, instructions agents
- [Architecture](../_bmad-output/planning-artifacts/architecture.md) — Decisions architecturales
- [PRD](../_bmad-output/planning-artifacts/prd.md) — Product Requirements Document
- [Epics & Stories](../_bmad-output/planning-artifacts/epics.md) — Backlog complet
- [Flutter Install](https://docs.flutter.dev/get-started/install) — Documentation officielle Flutter
