# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
et ce projet adhère au [Versionnage Sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté

- Préparation open source (LICENSE, SECURITY.md, CHANGELOG.md)
- Audit MVP : routage onboarding via pipeline IA, corrections critiques, durcissement shell

### Corrigé

- Routage onboarding à travers le pipeline IA complet
- Durcissement du shell et corrections de bugs critiques

## [0.1.0] — 2026-02-27

Version initiale du MVP Kita — compagnon IA d'assistance au handicap.

### Ajouté

#### Pipeline IA
- AIRouter avec classification intelligente des requêtes (locale vs cloud)
- FallbackChain avec cascade automatique entre providers
- Provider local Gemma pour inférence on-device
- Providers cloud (Claude, OpenAI, Gemini) en fallback
- ML Kit pour détection d'objets, reconnaissance de texte et labeling d'images
- Cache intelligent des réponses IA

#### Shell UI
- KitaOrb — interface orbe vivante avec Living Aura design
- KitaInput — entrée vocale et textuelle unifiée
- Shell responsive avec animations accessibles
- Système de commandes vocales

#### Onboarding
- Flow d'onboarding conversationnel voice-first
- Détection automatique des paramètres d'accessibilité
- Gestion des permissions (caméra, micro, localisation)
- Magic moment de première interaction
- Configuration clé API et mode accompagnant

#### Plugin Describe
- Pipeline caméra → vision IA → synthèse vocale (TTS)
- Description de scènes en langage naturel
- Intégration avec le système de plugins sandboxé

#### Plugin Alert
- Détection d'obstacles en temps réel (YOLO + ML Kit)
- Alertes haptiques et sonores contextuelles

#### Architecture plugins
- Système de plugins sandboxé avec permissions explicites
- Registre de plugins avec manifestes YAML
- Accès IA, mémoire et capteurs contrôlés par sandbox

#### Orchestration
- KitaOrchestrator — façade d'orchestration des agents
- AgentSupervisor — supervision et cycle de vie des agents
- OutputCoordinator — arbitrage multi-modal (TTS, haptique)
- InputRouter — routage intelligent des entrées utilisateur
- AgentBus — communication inter-agents

#### Mémoire
- Base de données locale chiffrée (Drift + SQLCipher AES-256)
- Stockage sécurisé des clés et tokens (flutter_secure_storage)

#### Mode passif
- Service de premier plan pour fonctionnement en arrière-plan
- Gestion intelligente de la batterie
- Transitions automatiques actif/passif

#### Qualité
- 751+ tests unitaires et d'intégration
- 4 Integration Gates validées (Phase 2, 3, 4, 5)
- Pipeline CI/CD
- Couverture > 70% par feature

[Non publié]: https://github.com/kita-app/kita/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kita-app/kita/releases/tag/v0.1.0
