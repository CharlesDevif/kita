# Kita -- Guide complet d'installation et de build

Guide pas-a-pas pour installer, configurer et lancer Kita depuis zero.
Concu pour les debutants -- aucune experience Flutter requise.

> **Kita** est un compagnon IA mobile d'assistance au handicap visuel, auditif et cognitif.
> L'application fonctionne en local sur l'appareil grace a Gemma 3n (Google) -- aucune connexion internet requise pour les fonctionnalites de base.

---

## Table des matieres

1. [Prerequis systeme](#1-prerequis-systeme)
2. [Installation de Flutter](#2-installation-de-flutter)
3. [Clone et dependances](#3-clone-et-dependances)
4. [Configuration Android](#4-configuration-android)
5. [Installation de l'IA locale (Gemma)](#5-installation-de-lia-locale-gemma)
6. [Configuration des cles API (optionnel)](#6-configuration-des-cles-api-optionnel)
7. [Build et installation](#7-build-et-installation)
8. [Premier lancement](#8-premier-lancement)
9. [Developpement](#9-developpement)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequis systeme

### Materiel minimum

| Ressource | Minimum | Recommande |
|-----------|---------|------------|
| RAM | 8 Go | 16 Go (compilation + emulateur + Gemma) |
| Espace disque | 15 Go | 25 Go (SDK + modele Gemma + emulateur) |
| CPU | 64-bit x86_64 ou ARM64 | Multi-core recent |

### Systemes d'exploitation supportes

| OS | Versions testees | Notes |
|----|------------------|-------|
| **Linux** | Ubuntu 22.04+, Debian 12+ | Plateforme de dev principale |
| **macOS** | 13 (Ventura)+ | Requis pour le build iOS |
| **Windows** | 10 (64-bit)+ | Build Android uniquement |

### Logiciels requis

| Outil | Version | Usage |
|-------|---------|-------|
| **Git** | 2.x+ | Clone du projet |
| **Java JDK** | 17+ | Requis par le build Android (Gradle) |
| **Flutter SDK** | 3.41+ | Framework de l'application |
| **Android SDK** | API 31+ (target 35) | Build Android |

### Appareil Android cible

| Critere | Minimum |
|---------|---------|
| Version Android | 12+ (API 31) |
| RAM | 4 Go (6 Go+ recommande pour Gemma) |
| Stockage libre | 4 Go (modele Gemma ~3.5 Go + app) |
| GPU | Adreno 640+ / Mali-G77+ (pour l'acceleration GPU de Gemma) |

> **Tip :** La plupart des telephones sortis apres 2021 supportent Gemma. Les appareils avec moins de 4 Go de RAM utiliseront le fallback ML Kit (plus leger, moins capable).

---

## 2. Installation de Flutter

### 2.1 Prerequis par plateforme

#### Linux (Ubuntu/Debian)

```bash
sudo apt-get update && sudo apt-get install -y \
  curl git unzip xz-utils zip \
  libglu1-mesa clang cmake ninja-build pkg-config \
  libgtk-3-dev libstdc++-12-dev
```

**Java JDK 17 :**

```bash
# Option A -- via apt (recommande)
sudo apt-get install -y openjdk-17-jdk

# Option B -- via Homebrew
brew install openjdk
```

Configurer JAVA_HOME (ajouter a `~/.zshrc` ou `~/.bashrc`) :

```bash
# Si installe via apt :
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

# Si installe via Homebrew :
export JAVA_HOME="/home/linuxbrew/.linuxbrew/opt/openjdk"
```

#### macOS

```bash
# Xcode command line tools (requis)
xcode-select --install

# Xcode complet (requis pour le build iOS)
# Installer depuis le Mac App Store, puis :
sudo xcodebuild -license accept

# CocoaPods (requis pour iOS)
brew install cocoapods

# Java JDK 17
brew install openjdk@17
```

#### Windows

1. Installer [Git for Windows](https://git-scm.com/download/win)
2. Installer [JDK 17+](https://adoptium.net/) (Adoptium recommande)
3. Installer [Visual Studio 2022](https://visualstudio.microsoft.com/) avec le workload "Desktop development with C++"

### 2.2 Installer Flutter

#### Linux

```bash
mkdir -p ~/development && cd ~/development
curl -fsSL -o flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.2-stable.tar.xz
tar xf flutter.tar.xz && rm flutter.tar.xz
```

Ajouter au PATH (`~/.zshrc` ou `~/.bashrc`) :

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

#### macOS

```bash
mkdir -p ~/development && cd ~/development

# Apple Silicon (M1/M2/M3/M4)
curl -fsSL -o flutter.zip \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.2-stable.zip

# Intel Mac : remplacer arm64 par x64 dans l'URL

unzip flutter.zip && rm flutter.zip
```

Ajouter au PATH (`~/.zshrc`) :

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

#### Windows

1. Telecharger le [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) (fichier `.zip`)
2. Extraire dans `C:\development\flutter`
3. Ajouter `C:\development\flutter\bin` au PATH systeme
   - Parametres > Systeme > Variables d'environnement > Path > Nouveau

### 2.3 Finaliser l'installation

```bash
# Recharger le shell
source ~/.zshrc          # Linux/macOS (zsh)
# ou : source ~/.bashrc  # Linux (bash)

# Verifier l'installation
flutter --version
```

Resultat attendu :

```
Flutter 3.41.2 • channel stable
Dart 3.11.0
```

**Configurer le JDK pour Flutter :**

```bash
flutter config --jdk-dir=$JAVA_HOME
```

**Desactiver les analytics (optionnel) :**

```bash
flutter --disable-analytics
dart --disable-analytics
```

**Verifier que tout est OK :**

```bash
flutter doctor
```

Resultat attendu :

```
[ok] Flutter (Channel stable, 3.41.2, ...)
[ok] Android toolchain - develop for Android devices
[ok] Chrome - develop for the web
[ok] Linux toolchain / Xcode (macOS) / Visual Studio (Windows)
[ok] Connected device
[ok] Network resources
```

> **Warning :** Si `flutter doctor` indique des problemes, resolvez-les avant de continuer. Les erreurs les plus courantes sont liees au JDK ou aux licences Android -- voir la section [Troubleshooting](#10-troubleshooting).

---

## 3. Clone et dependances

### 3.1 Cloner le projet

```bash
git clone https://github.com/anthropics/kita.git
cd kita
```

### 3.2 Installer les dependances

```bash
flutter pub get
```

### 3.3 Verification rapide

```bash
# Les tests doivent passer
flutter test

# L'analyse statique doit etre clean
dart analyze

# IMPORTANT : sqlite3_flutter_libs ne doit PAS etre present
flutter pub deps | grep sqlite3_flutter_libs
# (aucun resultat = OK)
```

> **Warning :** Si `sqlite3_flutter_libs` apparait dans les dependances, il y a un conflit avec `sqlcipher_flutter_libs` (base de donnees chiffree). Voir [Troubleshooting](#10-troubleshooting).

---

## 4. Configuration Android

### 4.1 Android SDK

**Option A -- Android Studio (recommande pour les debutants) :**

1. Installer [Android Studio](https://developer.android.com/studio)
2. Au premier lancement, suivre l'assistant d'installation
3. Ouvrir Settings > Languages & Frameworks > Android SDK
4. Installer :
   - **SDK Platforms** : `Android 14 (API 35)` (ou plus recent)
   - **SDK Tools** :
     - `Android SDK Build-Tools 35.0.0`
     - `Android SDK Command-line Tools`
     - `Android SDK Platform-Tools`
     - `NDK (Side by side)` (pour les libs natives comme SQLCipher)

**Option B -- Ligne de commande uniquement :**

```bash
# Telecharger les command-line tools depuis :
# https://developer.android.com/studio#command-line-tools-only

# Creer le repertoire SDK
mkdir -p ~/Android/Sdk/cmdline-tools

# Decompresser et renommer
unzip commandlinetools-linux-*.zip
mv cmdline-tools ~/Android/Sdk/cmdline-tools/latest

# Installer les composants
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;27.0.12077973"
```

### 4.2 Variables d'environnement

Ajouter a `~/.zshrc` ou `~/.bashrc` :

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

Windows (variables systeme) :

```
ANDROID_HOME = C:\Users\<user>\AppData\Local\Android\Sdk
PATH += %ANDROID_HOME%\platform-tools
```

### 4.3 Accepter les licences

```bash
flutter doctor --android-licenses
```

Repondre `y` a chaque question.

### 4.4 Appareil physique (recommande pour Gemma)

L'emulateur **ne supporte pas** l'acceleration GPU necessaire pour Gemma. Pour tester l'IA locale, utilisez un appareil physique.

**Activer le mode developpeur sur votre telephone :**

1. Ouvrir **Parametres > A propos du telephone**
2. Appuyer 7 fois sur **Numero de build** jusqu'au message "Vous etes maintenant developpeur"
3. Retourner dans **Parametres > Systeme > Options pour les developpeurs**
4. Activer **Debogage USB**

**Connecter via USB :**

```bash
# Verifier que l'appareil est detecte
adb devices
```

Resultat attendu :

```
List of devices attached
XXXXXXXX    device
```

> **Tip :** Si l'appareil affiche "unauthorized", deconnectez le cable USB, puis reconnectez. Acceptez l'invite "Autoriser le debogage USB ?" sur le telephone.

### 4.5 Emulateur (pour les tests sans Gemma)

Si vous n'avez pas d'appareil physique, un emulateur fonctionne pour tout sauf l'inference Gemma :

```bash
# Creer un emulateur via la ligne de commande
avdmanager create avd -n kita_test -k "system-images;android-35;google_apis;x86_64"

# Ou via Android Studio : Tools > Device Manager > Create Device
```

---

## 5. Installation de l'IA locale (Gemma)

Kita utilise **Gemma 3n E2B** de Google pour l'IA sur l'appareil. C'est un modele multimodal (texte + vision) qui tourne directement sur le telephone, sans internet.

### 5.1 A propos du modele

| Propriete | Valeur |
|-----------|--------|
| Modele | Gemma 3n E2B (instruction-tuned, INT4) |
| Fichier | `gemma-3n-E2B-it-int4.litertlm` |
| Taille | ~3.5 Go |
| Format | LiteRT-LM (`.litertlm`) |
| Capacites | Texte (35 langues) + Vision (description d'images) |
| RAM requise | 4 Go minimum sur l'appareil |
| Backend | GPU (prefere) avec fallback CPU |

### 5.2 Telecharger le modele

Le modele est disponible sur HuggingFace. Vous devez accepter la licence Gemma.

1. **Creer un compte HuggingFace** (gratuit) sur [huggingface.co](https://huggingface.co/join)
2. Aller sur la page du modele : [google/gemma-3n-E2B-it-litert-lm](https://huggingface.co/google/gemma-3n-E2B-it-litert-lm)
3. **Accepter la licence** Gemma (bouton en haut de la page)
4. Telecharger le fichier `gemma-3n-E2B-it-int4.litertlm` (~3.5 Go)

**Alternative -- via la CLI HuggingFace :**

```bash
# Installer la CLI
pip install huggingface-hub

# Se connecter
huggingface-cli login
# (coller votre token HuggingFace)

# Telecharger le modele
huggingface-cli download google/gemma-3n-E2B-it-litert-lm \
  gemma-3n-E2B-it-int4.litertlm \
  --local-dir ./model-download
```

### 5.3 Placer le modele dans le projet

Le modele doit etre dans le dossier `assets/models/` du projet :

```bash
# Creer le dossier si necessaire
mkdir -p assets/models/

# Copier le modele telecharge
cp ~/Downloads/gemma-3n-E2B-it-int4.litertlm assets/models/
# ou depuis la CLI HuggingFace :
cp model-download/gemma-3n-E2B-it-int4.litertlm assets/models/
```

**Verifier la presence du modele :**

```bash
ls -lh assets/models/
# Doit afficher : gemma-3n-E2B-it-int4.litertlm  (~3.5G)
```

> **Warning :** Le fichier `.litertlm` fait ~3.5 Go. Il est dans le `.gitignore` et ne sera **jamais** commite dans le depot git. Chaque developpeur doit le telecharger manuellement.

### 5.4 Configuration dans pubspec.yaml

Le fichier `pubspec.yaml` declare deja le dossier assets :

```yaml
flutter:
  assets:
    - assets/models/
```

Aucune modification necessaire -- le modele sera automatiquement inclu dans le build.

### 5.5 Appareils compatibles

Le modele Gemma 3n E2B fonctionne sur les appareils Android 12+ avec :

- **4 Go+ de RAM** (6 Go+ recommande)
- **GPU compatible OpenCL** (Qualcomm Adreno 640+, ARM Mali-G77+, Samsung Xclipse)
- **3.5 Go+ de stockage libre** pour le modele

Appareils testes :
- Samsung Galaxy S21+ et plus recent
- Google Pixel 6 et plus recent
- OnePlus 9 et plus recent

### 5.6 Si votre appareil n'est pas assez puissant

Pas de panique ! Kita a un systeme de fallback automatique :

1. **Gemma 3n** (si disponible) -- IA complete texte + vision
2. **ML Kit** (toujours disponible) -- OCR, detection d'objets, labels (plus leger, pas de generation de texte)
3. **Cloud providers** (si configures) -- Claude ou OpenAI en fallback reseau

Sur un appareil moins puissant, Kita utilisera ML Kit pour les fonctionnalites de base (lecture de texte, detection d'obstacles) et les providers cloud si disponibles pour la generation de texte.

### 5.7 Modele de detection d'obstacles (YOLOv8n)

Le plugin Alert (detection d'obstacles temps reel) utilise un modele YOLOv8n au format TFLite. Ce modele n'est **pas** fourni dans le repo (licence AGPL-3.0, incompatible avec la licence MIT du projet) — il faut le generer localement :

```bash
# Dans un environnement Python (venv recommande)
pip install ultralytics

# IMPORTANT : utiliser format=saved_model (chemin onnx2tf), qui produit un
# modele NHWC [1, 640, 640, 3] attendu par Kita.
# NE PAS utiliser format=tflite : le nouveau convertisseur LiteRT-Torch
# produit un layout NCHW [1, 3, 640, 640] incompatible.
yolo export model=yolov8n.pt format=saved_model imgsz=640

# Installer le modele float32 dans les assets
cp yolov8n_saved_model/yolov8n_float32.tflite <projet>/assets/models/yolo_v8_nano.tflite
```

**Verifier le modele :**

```bash
ls -lh assets/models/yolo_v8_nano.tflite
# Doit afficher : ~13 Mo
```

Specifications attendues par `obstacle_detector.dart` :

| Propriete | Valeur |
|-----------|--------|
| Entree | `[1, 640, 640, 3]` float32 (NHWC), RGB normalise [0, 1] |
| Sortie | `[1, 84, 8400]` float32 (4 bbox + 80 classes COCO) |
| Taille | ~13 Mo (float32) |

> **Note :** sans ce modele, l'app fonctionne quand meme — le plugin Alert signale simplement que la detection est indisponible (degradation gracieuse).

---

## 6. Configuration des cles API (optionnel)

> **L'app fonctionne SANS cles API.** Le mode local (Gemma + ML Kit) couvre les fonctionnalites principales. Les cles API ajoutent un fallback cloud pour des reponses plus riches.

### 6.1 Cle Claude (Anthropic)

1. Creer un compte sur [console.anthropic.com](https://console.anthropic.com)
2. Aller dans **Settings > API Keys**
3. Creer une nouvelle cle (commence par `sk-ant-...`)
4. Copier la cle

### 6.2 Cle OpenAI

1. Creer un compte sur [platform.openai.com](https://platform.openai.com)
2. Aller dans **API Keys**
3. Creer une nouvelle cle (commence par `sk-...`)
4. Copier la cle

### 6.3 Configurer les cles dans l'app

Les cles API sont configurees **dans l'application** via l'ecran de parametres, pas dans le code source. Elles sont stockees de maniere securisee dans le Keychain (iOS) / Keystore (Android) via `flutter_secure_storage`.

**Premiere option -- via l'interface de l'app :**
Lors de l'onboarding ou dans les parametres, l'app propose de saisir les cles API.

**Deuxieme option -- via `--dart-define` pour le build :**

```bash
flutter run \
  --dart-define=CLAUDE_API_KEY=sk-ant-votre-cle-ici \
  --dart-define=OPENAI_API_KEY=sk-votre-cle-ici
```

> **Warning :** Ne jamais commiter de cles API dans le code source. Les fichiers `.env` et `secrets/` sont dans le `.gitignore`.

---

## 7. Build et installation

### 7.1 Build debug (developpement)

```bash
# Build + installation directe sur l'appareil connecte
flutter run

# Ou build de l'APK debug sans installer
flutter build apk --debug
```

L'APK debug sera dans `build/app/outputs/flutter-apk/app-debug.apk`.

### 7.2 Build release (production)

```bash
# Build APK release
flutter build apk --release

# Avec les cles API (optionnel)
flutter build apk --release \
  --dart-define=CLAUDE_API_KEY=sk-ant-votre-cle-ici \
  --dart-define=OPENAI_API_KEY=sk-votre-cle-ici

# Avec un environnement specifique
flutter build apk --release --dart-define=ENV=prod
```

L'APK release sera dans `build/app/outputs/flutter-apk/app-release.apk`.

> **Note :** Le build release inclut le modele Gemma dans l'APK, ce qui donne un APK d'environ **3.5 Go+**. C'est attendu. Pour une distribution via le Play Store, utilisez un App Bundle (voir ci-dessous).

### 7.3 App Bundle (pour le Play Store)

```bash
flutter build appbundle --release
```

Le fichier `.aab` sera dans `build/app/outputs/bundle/release/app-release.aab`.

### 7.4 Installer sur l'appareil

```bash
# Via Flutter (plus simple)
flutter install

# Via ADB (si Flutter ne detecte pas l'appareil)
adb install build/app/outputs/flutter-apk/app-release.apk

# Forcer la reinstallation
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 8. Premier lancement

### 8.1 Ce qui se passe au demarrage

1. **Chargement du modele Gemma** (~10-15 secondes au premier lancement)
   - Le modele est copie depuis les assets vers le stockage interne
   - Les poids sont charges en memoire GPU
   - Un "warmup" (inference a vide) compile les kernels GPU
2. **Les lancements suivants** sont plus rapides (~3-5 secondes)

### 8.2 L'onboarding conversationnel

Au premier lancement, Kita accueille l'utilisateur par la voix :

1. **Permission micro** -- Kita demande l'acces au microphone pour l'interaction vocale
2. **Salutation** -- "Bonjour, je suis Kita, ton compagnon visuel..."
3. **Permission camera** -- Kita explique pourquoi la camera est necessaire
4. **Moment magique** -- L'utilisateur dit "decris" et Kita decrit ce que la camera voit

> **Tip :** Si le TTS (synthese vocale) ne fonctionne pas, verifiez que votre appareil a un moteur de synthese vocale installe (Google TTS est pre-installe sur la plupart des appareils).

### 8.3 Tester que tout fonctionne

Apres l'onboarding, testez ces commandes vocales :

| Commande | Resultat attendu |
|----------|-----------------|
| "Decris" | Kita decrit ce que voit la camera |
| "Lis" | Kita lit le texte visible via OCR |
| "Aide" | Kita explique les commandes disponibles |

Si tout fonctionne, le setup est complet !

---

## 9. Developpement

### 9.1 Commandes quotidiennes

```bash
# Lancer l'app en mode debug avec hot reload
flutter run

# Hot reload (dans le terminal ou Ctrl+S dans l'IDE)
r

# Hot restart (reinitialise l'etat)
R

# Quitter
q
```

### 9.2 Tests

```bash
# Lancer tous les tests
flutter test

# Lancer un fichier de test specifique
flutter test test/features/ai/data/ai_router_impl_test.dart

# Lancer avec couverture
flutter test --coverage
```

### 9.3 Analyse statique

```bash
# Analyse du code
dart analyze

# Analyse stricte (bloque sur les infos aussi)
dart analyze --fatal-infos
```

### 9.4 Code generation

Apres avoir modifie des fichiers avec annotations Freezed, Drift ou Riverpod :

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 9.5 Structure du projet

```
lib/
  core/           # DI, config, errors, theme, utils
  features/
    ai/           # AI Router, providers (Gemma, Claude, OpenAI), fallback
    io/           # Camera, STT, TTS, haptic, location, motion
    memory/       # Base de donnees chiffree (Drift + SQLCipher)
    plugins/      # Systeme de plugins sandboxes
    onboarding/   # Flow d'onboarding conversationnel
    shell/        # Interface principale (KitaShell, KitaOrb)
    orchestration/# Routage des requetes, supervision des agents
    settings/     # Preferences utilisateur
  shared/         # Widgets partages, ProfileAdapter
```

Pour plus de details, voir le fichier [CLAUDE.md](../CLAUDE.md) et le [README](../README.md).

### 9.6 IDE recommande

**VS Code** avec les extensions :
- Flutter (officielle)
- Dart (officielle)
- Flutter Riverpod Snippets

**Android Studio / IntelliJ IDEA** avec les plugins :
- Flutter
- Dart

---

## 10. Troubleshooting

### "Gemma model not found" ou "Gemma initialization failed"

**Cause :** Le fichier modele n'est pas dans `assets/models/`.

**Solution :**
```bash
# Verifier que le fichier existe
ls -lh assets/models/gemma-3n-E2B-it-int4.litertlm

# S'il manque, le telecharger (voir section 5)
```

Verifier aussi que `pubspec.yaml` declare le dossier assets :
```yaml
flutter:
  assets:
    - assets/models/
```

### "Out of memory" sur l'appareil

**Cause :** L'appareil n'a pas assez de RAM pour charger Gemma.

**Solutions :**
1. Fermer les autres apps avant de lancer Kita
2. Redemarrer l'appareil
3. Si le probleme persiste, l'appareil n'est pas compatible avec Gemma
   - Kita basculera automatiquement sur ML Kit (plus leger)
   - Configurez les cles API Claude/OpenAI pour un fallback cloud

### Build Android echoue -- erreurs Java / Gradle

**"Could not determine Java version" :**
```bash
# Verifier la version Java
java -version
# Doit etre 17+

# Configurer Flutter pour utiliser le bon JDK
flutter config --jdk-dir=$JAVA_HOME
```

**"CallbackToFutureAdapter not found" :**
C'est un probleme connu avec `camera_android_camerax`. Le projet inclut deja le fix dans `build.gradle.kts` :
```kotlin
dependencies {
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
}
```

**Erreur Gradle "Minimum supported Gradle version" :**
```bash
# Mettre a jour le wrapper Gradle
cd android
./gradlew wrapper --gradle-version=8.12
cd ..
```

### "Camera permission denied"

**Solution :**
1. Verifier que les permissions sont dans `AndroidManifest.xml` (deja configure dans le projet)
2. Sur l'appareil : Parametres > Apps > Kita > Permissions > Autoriser la camera
3. Desinstaller et reinstaller l'app si la permission est bloquee

### Le TTS (synthese vocale) ne parle pas

**Cause possible :** Pas de moteur TTS installe ou mauvaise langue.

**Solutions :**
1. Verifier dans Parametres > Accessibilite > Synthese vocale que Google TTS est installe
2. Telecharger le pack de voix "Francais" si manquant
3. Sur Samsung : les moteurs TTS Samsung peuvent avoir des bugs -- installer Google TTS comme alternative

> **Note :** Kita gere automatiquement les timeouts TTS Samsung. Si le TTS reste bloque, l'app passera automatiquement au suivant apres 10 secondes.

### `sqlite3_flutter_libs` dans les dependances

**Cause :** Un package transitive a importe `sqlite3_flutter_libs`, qui entre en conflit avec `sqlcipher_flutter_libs` (symboles natifs dupliques).

**Solution :**
```bash
# Verifier
flutter pub deps | grep sqlite3_flutter_libs

# Si present, identifier la source
flutter pub deps -s list | grep -B5 sqlite3_flutter_libs
```

Ne jamais utiliser `drift_flutter` (il importe `sqlite3_flutter_libs` transitivement). Le projet utilise `NativeDatabase` manuellement.

### Build lent ou bloque

```bash
# Nettoyer le cache de build
flutter clean
flutter pub get

# Rebuild complet
flutter build apk --debug
```

### L'emulateur ne detecte pas l'app correctement

L'emulateur fonctionne pour le developpement general mais **ne supporte pas l'inference Gemma** (pas d'acceleration GPU). Pour tester l'IA locale, utilisez un appareil physique.

### Erreurs ProGuard en build release

Le projet inclut deja les regles ProGuard necessaires dans `android/app/proguard-rules.pro` :

```
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
```

Si de nouvelles erreurs apparaissent, ajouter les regles manquantes dans ce fichier.

---

## Ressources

- [CLAUDE.md](../CLAUDE.md) -- Conventions projet, architecture, instructions
- [README.md](../README.md) -- Presentation du projet
- [CONTRIBUTING.md](../CONTRIBUTING.md) -- Guide de contribution
- [Architecture](../_bmad-output/planning-artifacts/architecture.md) -- Decisions architecturales
- [Flutter Install (officiel)](https://docs.flutter.dev/get-started/install)
- [flutter_gemma (pub.dev)](https://pub.dev/packages/flutter_gemma)
- [Gemma 3n E2B (HuggingFace)](https://huggingface.co/google/gemma-3n-E2B-it-litert-lm)
