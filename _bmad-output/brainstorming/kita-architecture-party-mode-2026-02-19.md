---
type: party-mode-session
date: 2026-02-19
participants: [Winston (Architect), John (PM), Amelia (Developer), Sally (UX Designer), Victor (Innovation Strategist), Barry (Quick Flow Solo Dev), Murat (Test Architect), Maya (Design Thinking Coach), Carson (Brainstorming Coach)]
topics: [AI Router, Plugin System, I/O Layer, Storage/Memory, Onboarding UX, Flutter Structure, Open Source Strategy]
---

# Kita — Architecture Technique MVP (Party Mode Session)

**Date :** 2026-02-19
**Participants :** Winston, John, Amelia, Sally, Victor, Barry, Murat, Maya

---

## 1. AI Router — Multi-Provider Hybride

### Architecture 3 Tiers

```
┌─────────────────────────────────────────────────┐
│              AI ROUTER (Orchestrateur)           │
├──────────┬──────────────┬───────────────────────┤
│ TIER 1   │ TIER 2       │ TIER 3               │
│ LOCAL    │ CLOUD RAPIDE │ CLOUD PUISSANT        │
│ <50ms    │ 200-500ms    │ 500ms-2s              │
│          │              │                       │
│ • ML Kit │ • Claude     │ • Claude Opus         │
│ • CoreML │   Haiku      │ • GPT-4o              │
│ • STT    │ • Gemini     │ • Description         │
│ • Alertes│   Flash      │   complexe            │
└──────────┴──────────────┴───────────────────────┘
```

### Sous-systèmes

1. **RequestClassifier** — Classe chaque requête (critical/urgent/standard/background) via heuristiques locales, sans appel cloud
2. **AISelector** — Choisit le provider optimal selon : capacité, disponibilité, connectivité, préférences utilisateur
3. **Fallback Chain** — Aucune requête critique ne retourne jamais d'erreur. Dernier recours = alerte sonore brute
4. **Cache Manager** (v0.2) — Cache par similarité, TTL adaptatif selon le type de requête

### Interface Provider

```dart
abstract class AIProvider {
  String get id;
  Future<AIResponse> complete(AIRequest request);
  Future<AIResponse> vision(ImageData image, String prompt);
  bool get isAvailable;
  int get latencyTier;
}
```

### Logique de routage

```dart
class AIRouter {
  Future<AIResponse> route(AIRequest request) async {
    final priority = classifier.classify(request);
    switch (priority) {
      case RequestPriority.critical:
        return _handleCritical(request);  // Local UNIQUEMENT, fallback alerte brute
      case RequestPriority.urgent:
        return _handleUrgent(request);    // Cloud rapide (3s timeout) → fallback local
      default:
        return _handleStandard(request);  // Cloud puissant (10s timeout) → fallback local
    }
  }
}
```

### Avantage stratégique

Provider-agnostic = pas de vendor lock-in, meilleur modèle pour chaque tâche, argument marketing puissant, l'utilisateur choisit (vie privée vs qualité).

---

## 2. Plugin System — Architecture Modulaire

### Plugin Manifest (plugin.kita.yaml)

```yaml
id: "com.kita.describe"
name: "Describe"
version: "1.0.0"
permissions: [camera, microphone, speaker]
sensors:
  required: [camera]
  optional: [gps]
ai:
  capabilities: [vision, textGeneration]
  preferred_tier: 3
  fallback_tier: 1
  critical_mode: true
ui:
  type: "overlay"
  voice_activated: true
  trigger_phrases: ["décris", "qu'est-ce que c'est", "montre-moi"]
profiles:
  recommended_for: [blind]
  useful_for: [all]
```

### Interface Plugin

```dart
abstract class KitaPlugin {
  PluginManifest get manifest;
  Future<void> onInstall();
  Future<void> onActivate();
  Future<void> onDeactivate();
  Future<void> onUninstall();
  Future<PluginResponse> handleRequest(PluginRequest request);
  Widget? buildUI(BuildContext context);
  List<VoiceCommand> get voiceCommands;
}
```

### Principes clés

- Le plugin ne touche JAMAIS directement au hardware ni à l'IA — il passe par request.sensors et request.ai
- Le Sandbox vérifie les permissions, applique des quotas, isole les erreurs
- Le PluginRegistry gère l'installation, les suggestions contextuelles, les packs par profil
- Capabilities standardisées (VISION_DESCRIBE, VISION_READ, AUDIO_TRANSCRIBE...) pour le matching intelligent

### Niveaux de confiance plugins

- **Officiels ✅** — Développés par l'équipe Kita, audit complet
- **Communautaires vérifiés 🔍** — Code reviewé, PR mergée
- **Tiers non vérifiés ⚠️** — Warning clair, sandbox renforcé

---

## 3. I/O Layer — Système Nerveux

### Architecture

```
INPUT (Perception)     OUTPUT (Action)        PASSIVE (Surveillance)
• Caméra               • TTS (parole)         • Accéléromètre
• Micro/STT            • Haptic (vibrations)  • GPS continu
• Boutons              • Écran/HUD            • Ambient Sound
• Gestes               • Alertes sonores      • Luminosité
```

### Interface commune

```dart
abstract class IOService {
  String get id;
  IOType get type;
  bool get isAvailable;
  ServiceState get state;
  Future<void> start();
  Future<void> pause();
  Future<void> stop();
  BatteryImpact get batteryImpact;
  Stream<IOEvent>? get eventStream;
}
```

### CameraService — 3 modes

1. **Capture unique** — Photo → analyse (MVP)
2. **Flux temps réel** — Navigation, FPS adaptatif selon le mouvement (v0.2)
3. **Capture déclenchée** — Événement externe (sonnette, mouvement)

### FPS adaptatif

```dart
if (ctx.isStationary) return 0;       // Immobile → caméra off
if (ctx.isWalkingSlow) return 2;       // Marche lente → 2 fps
if (ctx.isWalkingNormal) return 5;     // Marche normale → 5 fps
if (ctx.isCrossingRoad) return 10;     // Traverse une route → 10 fps
```

### Audio Multiplexer

- Bascule automatique entre STT (commande vocale) et analyse ambiante (sons environnement)
- Wake word → mode STT, fin de parole → retour ambient
- EXCEPTION : alerte critique perce TOUJOURS, même pendant la dictée

### SpeechOutputService

- File d'attente avec priorités
- speakUrgent() coupe tout et parle immédiatement
- Communication adaptative : phrases courtes en danger, détaillées au calme
- Compression d'urgence : "Voiture qui approche sur ta gauche" → "Voiture, gauche !"

### HapticService

- Patterns de vibration codifiés pour navigation et alertes
- Direction gauche/droite, arrivée, danger, notification

---

## 4. Storage / Mémoire — 4 Domaines

### Architecture

```
WORKING (RAM)      EPISODIC (30j)     SEMANTIC (permanent)  RELATIONAL (permanent)
Conversation       Ce matin Marie     Marie aime le café    Lucas = ami de Karim
en cours,          a pris un taxi     noir, est allergique   voix grave, fan de foot
contexte actuel    chez le médecin    au gluten
```

### Technologie

- **Isar** comme DB principale (chiffrement AES-256 natif, 100K+ lectures/seconde)
- **RAM** pour la Working Memory (non persistée)

### Data Model

- **UserProfile** — Nom, profil accessibilité, préférences IA, niveau de vie privée
- **UserPreference** — Clé-valeur catégorisé (food, transport, clothing...) avec score de confiance
- **Episode** — Événements horodatés, taggés automatiquement, avec résumé IA
- **Person** — Graphe social avec empreinte vocale/faciale, relation, intérêts, notes

### Tag Indexer

- Auto-tagging local sans appel cloud (règles + NLP embarqué)
- Tags : type, moment de la journée, jour, plugin, thèmes extraits
- Recherche par combinaison de tags en O(1) par tag

### Privacy — 5 principes non négociables

1. **Local-first** — Les données ne quittent JAMAIS le téléphone
2. **Chiffrement au repos** — Isar chiffré + double chiffrement pour données médicales/relationnelles
3. **Droit à l'oubli granulaire** — Par personne, épisode, domaine, ou tout
4. **Transparence totale** — "Kita, qu'est-ce que tu sais sur moi ?"
5. **Consentement explicite par domaine** — Chaque type de mémoire activable/désactivable

### MemoryVault

```dart
class MemoryVault {
  Future<void> store(MemoryDomain domain, dynamic data);   // Vérifie consentement
  Future<void> forget(ForgetRequest request);               // Droit à l'oubli
  Future<MemoryReport> whatDoYouKnow();                     // Transparence
}
```

---

## 5. Onboarding UX — 3 Minutes, Vocal-First

### Flow en 5 étapes

```
0. Détection accessibilité système (invisible)
   → TalkBack/VoiceOver actif ? Sous-titres ? Contraste élevé ?
   → Adapte le mode d'onboarding AVANT le premier écran

1. Premier contact vocal (10s)
   → Kita parle immédiatement, pas d'écran à lire
   → Adapté au profil détecté (vocal pour aveugles, textuel pour sourds)

2. Choix du profil (30s)
   → 6 options simples, multi-sélection possible
   → Option "j'installe pour quelqu'un d'autre" + contact référent

3. Permissions guidées (30s)
   → Contextualisées et expliquées ("pour décrire, j'ai besoin de ta caméra")
   → Ordre adapté au profil (aveugle → caméra d'abord)

4. Configuration IA (15s)
   → Mode découverte (essai gratuit 7j/100 requêtes) ou clé API perso

5. Premier moment magique ✨ (30s)
   → Marie : "décris" → description d'un objet réel
   → Karim : parle → transcription instantanée
   → Thomas : question → réponse vocale intelligente
```

### Principes UX

- On ne demande pas "êtes-vous aveugle ?" — on détecte et on s'adapte
- 100% utilisable à la voix dès la première seconde
- Packs de plugins installés automatiquement selon le profil
- Le premier moment magique DOIT impressionner — c'est le hook

---

## 6. Structure du Projet Flutter

### Organisation feature-first + clean architecture

```
lib/
├── main.dart
├── app.dart
├── core/          # DI, config, errors, utils
├── ai/            # AI Router, providers, classifier, fallback
├── io/            # Camera, audio, haptic, location, motion
├── memory/        # Isar store, collections, tag indexer, vault
├── plugins/       # Plugin interface, registry, sandbox, built-in/describe
├── onboarding/    # Flow complet, détection accessibilité
└── home/          # Écran principal, chat, plugin viewport
```

### Dépendances clés

- **State management :** flutter_riverpod
- **Storage :** isar (chiffré)
- **AI :** anthropic_sdk_dart, dart_openai, google_generative_ai
- **Camera :** camera
- **Audio :** speech_to_text, flutter_tts
- **Sensors :** geolocator, sensors_plus
- **Permissions :** permission_handler
- **Sécurité :** encrypt, local_auth

### Plan de sprints

```
Sprint 1 (sem 1-2) : Squelette + IA
→ Riverpod setup, Claude provider, AI Router simple, écran chat basique

Sprint 2 (sem 3-4) : Caméra + Plugin Describe
→ Capture photo, STT/TTS, interface plugin, plugin Describe complet

Sprint 3 (sem 5-6) : Mémoire + Onboarding
→ Isar chiffré, profil utilisateur, flow onboarding complet

Sprint 4 (sem 7-8) : Polish + Tests
→ Tests d'intégration, permissions guidées, mode découverte, beta ready
```

---

## 7. Stratégie Open Source

### Modèle économique

```
GRATUIT (open source MIT) :
├── App Kita complète
├── Core engine
├── Plugins communautaires
├── SDK développeur
└── Auto-hébergement avec sa propre clé API

PAYANT (services) :
├── Kita Cloud — proxy API simplifié (5€/mois)
├── Kita Pro — plugins premium certifiés
├── Kita Enterprise — institutions (hôpitaux, écoles, EHPAD)
└── Plugin Marketplace — commission 20% sur plugins payants
```

### SDK Développeur

```
kita_plugin_sdk (package pub.dev)
├── KitaPlugin, PluginManifest, PluginRequest/Response
├── SensorAccess, AIAccess, MemoryAccess
└── UIComponents (widgets accessibles pré-faits)

kita_plugin_cli
├── kita create my-plugin    → scaffolding
├── kita test                → tests locaux
├── kita validate            → vérifie manifest + sécurité
└── kita publish             → soumission pour review
```

### Plugins communautaires potentiels

Réseaux sociaux (Facebook, WhatsApp, Instagram, Discord, YouTube, Email...) via webview enrichie par l'IA — chaque réseau = un plugin maintenu par la communauté.

---

## 8. Tests Critiques Non Négociables

```dart
// 1. Le fallback critique ne fail JAMAIS
test('critical request always returns response even if all AI fails');

// 2. Le chiffrement fonctionne réellement
test('stored data is encrypted and unreadable without key');

// 3. Forget efface vraiment tout
test('forget everything leaves zero recoverable data');

// 4. Le sandbox bloque les accès non autorisés
test('plugin cannot access sensor not in manifest');
```

Si un seul échoue, on ne shippe pas.

---

## 9. Definition of Done — MVP v0.1

### Fonctionnel
- Onboarding complet en < 3 minutes
- Profil aveugle → pack plugins installé
- Plugin Describe : photo → description vocale < 5s
- STT + TTS fonctionnels
- Mode découverte IA opérationnel
- Fallback critique → alerte brute

### Technique
- Architecture 5 couches respectée
- AI Router avec fallback chain
- Plugin interface abstraite en place
- Mémoire chiffrée Isar
- Forget everything fonctionnel

### UX
- Onboarding accessible (VoiceOver/TalkBack)
- 100% utilisable à la voix
- Premier moment magique en fin d'onboarding

### Qualité
- 80%+ couverture de tests
- 0 crash sur les flows critiques
- Testé avec un utilisateur aveugle réel
- Compatible Android 12+ et iOS 16+
