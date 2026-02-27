<p align="center">
  <h1 align="center">Kita</h1>
  <p align="center">
    <strong>Compagnon IA mobile d'assistance au handicap</strong><br>
    <em>AI-powered mobile accessibility companion</em>
  </p>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white" alt="Dart"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
  <a href="https://www.w3.org/WAI/WCAG21/quickref/"><img src="https://img.shields.io/badge/WCAG-2.1_AA+-purple" alt="WCAG 2.1 AA+"></a>
  <img src="https://img.shields.io/badge/Platform-Android_12%2B_%7C_iOS_16%2B-lightgrey" alt="Platform">
</p>

---

## Qu'est-ce que Kita ? / What is Kita?

**Kita** est un agent IA mobile open source qui exploite les capteurs du telephone (camera, microphone, GPS, accelerometre) pour assister les personnes en situation de handicap -- visuel, auditif ou cognitif -- dans leur quotidien.

L'application est **voice-first** (pilotee a la voix), **local-first** (fonctionne hors ligne), et concue pour l'**accessibilite universelle** (WCAG 2.1 AA+). Elle remplace plusieurs applications isolees par un ecosysteme unifie avec une memoire locale chiffree et une architecture de plugins extensible.

**Kita** is an open source mobile AI agent that leverages phone sensors (camera, microphone, GPS, accelerometer) to assist people with disabilities -- visual, auditory, or cognitive -- in their daily lives. The app is voice-first, works offline, and is designed for universal accessibility.

### Le persona MVP / MVP Persona

> Marie, 28 ans, aveugle de naissance, utilisatrice VoiceOver.
> Elle pointe son telephone vers sa table basse et dit "decris".
> En 4 secondes, Kita repond : description complete de la scene.
> Pour la premiere fois, une app lui decrit son propre salon sans appeler personne.

---

## Fonctionnalites / Features

| | Fonctionnalite | Description |
|---|---|---|
| **Voice-first** | Interaction vocale | Pilotage complet a la voix, VoiceOver/TalkBack natif |
| **Scene description** | Plugin "Decris" | Description photo vocale en < 5 secondes via IA cloud ou locale |
| **Obstacle alerts** | Detection d'obstacles | Alertes temps reel via IA locale (< 50ms), ne passe jamais par le cloud |
| **Offline-first** | IA locale avec Gemma | Fonctionne hors connexion grace a ML Kit et Gemma on-device |
| **Cloud AI** | Multi-provider sans lock-in | Claude, OpenAI, Gemini -- l'AI Router choisit le meilleur provider |
| **Smart fallback** | Chaine de fallback | Cloud puissant -> cloud rapide -> IA locale, les requetes critiques ne retournent jamais d'erreur |
| **Onboarding** | Onboarding conversationnel | Detection automatique VoiceOver/TalkBack, profil en < 3 minutes |
| **Plugins** | Architecture extensible | Systeme de plugins sandboxes avec permissions granulaires |
| **Privacy** | Memoire locale chiffree | AES-256 via SQLCipher, droit a l'oubli granulaire, zero PII dans les logs |

---

## Architecture

Kita suit une architecture **Feature-first + Clean Architecture** (`domain/ <- data/ <- presentation/`) avec Riverpod 3.0 pour le state management.

```
lib/
├── core/               # DI, config, errors, theme, utils
│   ├── config/         # App configuration
│   ├── constants/      # Global constants
│   ├── errors/         # Sealed failure types (Result<T>)
│   ├── navigation/     # GoRouter setup
│   ├── theme/          # Mix-based theming
│   └── utils/          # Logger, helpers
│
├── features/
│   ├── ai/             # AI Router, providers, classifier, fallback chain
│   │   ├── domain/     #   AIProvider, AIRouter interfaces
│   │   ├── data/       #   Claude, OpenAI, Gemma, ML Kit providers
│   │   └── presentation/
│   ├── io/             # Camera, STT, TTS, haptic, location, motion
│   ├── memory/         # Drift + SQLCipher store, vault, collections
│   ├── plugins/        # Plugin interface, registry, sandbox, built-in plugins
│   │   └── built_in/   #   Describe plugin
│   ├── onboarding/     # Conversational onboarding flow
│   ├── orchestration/  # System orchestration layer
│   ├── shell/          # KitaShell, KitaOrb, KitaInput (main UI)
│   └── settings/       # Preferences, profile, forget
│
└── shared/             # Shared widgets
```

### AI Router

Le coeur de Kita est son **AI Router** -- un systeme intelligent de routage de requetes IA :

1. Le **RequestClassifier** categorise chaque requete (critique, standard, legere)
2. Le **FallbackChain** assure qu'une reponse est toujours fournie :
   - Cloud puissant (Claude, OpenAI) -> Cloud rapide (Gemini) -> IA locale (Gemma, ML Kit)
3. Les requetes critiques (obstacles, alertes) passent **toujours** par l'IA locale pour des reponses < 50ms

---

## Stack technique / Tech Stack

| Composant | Technologie |
|-----------|-------------|
| Framework | Flutter 3.41+ / Dart 3.11+ |
| State management | Riverpod 3.0 + code generation |
| Base de donnees | Drift + SQLCipher (AES-256) |
| Navigation | GoRouter |
| Styling | Mix (utility-first) |
| IA locale | ML Kit (detection, OCR, labels) + Gemma (LLM on-device) |
| IA cloud | Claude, OpenAI, Gemini |
| ML / Vision | TFLite + YOLO (detection d'obstacles) |
| Stockage securise | flutter_secure_storage (Keychain/Keystore) |
| Speech | speech_to_text + flutter_tts |
| Camera | camera plugin |
| Localisation | Geolocator + Geocoding |
| Serialisation | Freezed + json_serializable |

---

## Demarrage rapide / Getting Started

### Prerequis / Prerequisites

- Flutter 3.41+ / Dart 3.11+ ([installation](https://docs.flutter.dev/get-started/install))
- Android SDK (API 31+, target 35) ou Xcode 15+ (pour iOS)
- Un editeur compatible (VS Code, Android Studio, IntelliJ)

### Installation

```bash
# Cloner le depot
git clone https://github.com/your-org/kita.git
cd kita

# Installer les dependances
flutter pub get

# Generer le code (Drift, Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Lancer sur un appareil connecte ou un emulateur
flutter run
```

### Configuration (optionnel)

Pour utiliser les providers IA cloud, configurez vos cles API dans l'application via l'onboarding ou les parametres. L'application fonctionne aussi **entierement hors ligne** grace aux modeles locaux (ML Kit, Gemma).

| Provider | Variable | Requis ? |
|----------|----------|----------|
| Claude (Anthropic) | Cle API dans l'app | Non -- fallback local disponible |
| OpenAI | Cle API dans l'app | Non -- fallback local disponible |
| IA locale (ML Kit / Gemma) | Aucune configuration | Inclus par defaut |

---

## Tests

```bash
# Lancer tous les tests
flutter test

# Analyse statique
dart analyze --fatal-infos

# Regenerer le code apres modification des modeles
dart run build_runner build --delete-conflicting-outputs
```

Le projet utilise des tests unitaires, des tests de widgets et des tests d'integration. Chaque feature maintient un niveau de couverture > 70%.

---

## Screenshots / Captures d'ecran

> **TODO** -- Captures d'ecran de l'onboarding, de la description de scene, et de l'interface KitaShell a ajouter ici.

---

## Contribuer / Contributing

Les contributions sont les bienvenues ! Consultez le fichier [CONTRIBUTING.md](CONTRIBUTING.md) pour les directives detaillees.

En bref :

1. Forkez le depot
2. Creez une branche feature (`git checkout -b feature/ma-fonctionnalite`)
3. Commitez vos modifications
4. Poussez la branche et ouvrez une Pull Request

Toute contribution doit respecter les standards d'accessibilite du projet (WCAG 2.1 AA+) et inclure des tests.

---

## Feuille de route / Roadmap

| Phase | Statut | Description |
|-------|--------|-------------|
| MVP | En cours | AI Router, Plugin Describe, Plugin Alert, onboarding vocal, pack aveugle |
| Growth | A venir | Navigation temps reel, SDK plugins, packs sourds/autistes, marketplace |
| Vision | A venir | Multi-appareils, Kita Enterprise, plugins communautaires |

---

## Licence / License

Ce projet est distribue sous la licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de details.

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Remerciements / Acknowledgements

- [Flutter](https://flutter.dev) -- framework cross-platform
- [Riverpod](https://riverpod.dev) -- state management reactif
- [Drift](https://drift.simonbinder.eu) -- base de donnees typesafe pour Dart
- [SQLCipher](https://www.zetetic.net/sqlcipher/) -- chiffrement AES-256 de la base de donnees
- [Google ML Kit](https://developers.google.com/ml-kit) -- IA on-device
- [Gemma](https://ai.google.dev/gemma) -- LLM open source on-device
- [Mix](https://www.fluttermix.com) -- styling utility-first pour Flutter

---

<p align="center">
  <strong>Kita</strong> -- Parce que l'autonomie est un droit, pas un privilege.<br>
  <em>Because autonomy is a right, not a privilege.</em>
</p>
