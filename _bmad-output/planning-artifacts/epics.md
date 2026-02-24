---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - prd.md
  - architecture.md
  - ux-design-specification.md
agentDevelopment: true
agentDevelopmentNotes: "Stories structurées pour développement multi-agents IA en parallèle — frontières claires, dépendances minimales, scopes parallélisables, conventions de branches/merge/gates définies, accessibility tax transversale, golden fixtures partagées"
---

# Kita - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Kita, decomposing the requirements from the PRD, UX Design and Architecture into implementable stories. Les stories sont structurées pour permettre le développement par une équipe d'agents IA travaillant en parallèle.

## Requirements Inventory

### Functional Requirements

**AI & Intelligence (6 FRs) :**

- FR-AI-001 : L'AI Router doit router les requêtes vers le provider optimal (Claude, OpenAI, Gemini, local) selon le RequestClassifier [Must]
- FR-AI-002 : Le RequestClassifier doit classer chaque requête en 4 niveaux : critical (< 50ms local), urgent (< 500ms), standard (< 5s), background (async) [Must]
- FR-AI-003 : La fallback chain doit cascader : cloud puissant (timeout 3s) → cloud rapide (timeout 3s) → IA locale → alerte brute [Must]
- FR-AI-004 : L'IA locale (ML Kit / CoreML) doit traiter les requêtes critiques en < 50ms sans connexion internet [Must]
- FR-AI-005 : Les requêtes classées "critical" ne doivent JAMAIS retourner d'erreur — alerte brute sonore en dernier recours [Must]
- FR-AI-006 : L'AI Router doit supporter l'ajout de nouveaux providers via une interface abstraite sans modification du code existant [Should]

**Perception & Capteurs (7 FRs) :**

- FR-PER-001 : Le Camera Service doit capturer une photo unique à la commande vocale "décris" [Must]
- FR-PER-002 : Le Camera Service doit supporter le mode passif (flux vidéo continu) pour la détection d'obstacles [Must]
- FR-PER-003 : L'AudioMultiplexer doit multiplexer le microphone entre STT (commandes vocales) et analyse ambiante (détection sons) [Must]
- FR-PER-004 : Le STT local doit transcrire la parole avec une latence < 200ms [Must]
- FR-PER-005 : Le service GPS doit fournir les coordonnées, l'adresse inversée et les POIs proches aux plugins qui le demandent [Must]
- FR-PER-006 : L'accéléromètre doit détecter l'état de mouvement (immobile / marche / course) pour adapter le FPS caméra [Should]
- FR-PER-007 : Le mode passif permanent doit maintenir les capteurs minimaux actifs (micro ambient, accéléromètre) et activer les capteurs supplémentaires (caméra, GPS) sur commande vocale, mouvement détecté ou événement plugin [Must]

**Communication & Sortie (6 FRs) :**

- FR-COM-001 : Le TTS local doit démarrer la synthèse vocale en < 100ms [Must]
- FR-COM-002 : Le SpeechOutputService doit gérer une file de priorité (critique > urgent > standard) sans interrompre les alertes critiques [Must]
- FR-COM-003 : L'interface vocale doit reconnaître les commandes clés : "décris", "lis ça", "stop", "aide" [Must]
- FR-COM-004 : L'interface textuelle doit être disponible en alternative complète à l'interface vocale [Must]
- FR-COM-005 : Le HapticService doit fournir un retour haptique différencié pour les alertes (3 patterns minimum : info, warning, danger) [Must]
- FR-COM-006 : Kita doit annoncer vocalement les changements d'état suivants : perte de connexion, batterie < 20%, provider IA indisponible, activation du mode dégradé [Should]

**Mémoire & Données (7 FRs) :**

- FR-MEM-001 : Toutes les données utilisateur doivent être stockées dans Drift+SQLCipher avec chiffrement AES-256 [Must]
- FR-MEM-002 : La mémoire doit être organisée en 4 domaines : working (session), episodic (événements), semantic (connaissances), relational (personnes) [Must]
- FR-MEM-003 : MemoryVault doit exiger un consentement explicite avant tout stockage de données sensibles (profil handicap, préférences) [Must]
- FR-MEM-004 : MemoryVault.forget() doit effacer 100% des données récupérables — vérifiable par audit [Must]
- FR-MEM-005 : MemoryVault.whatDoYouKnow() doit permettre à l'utilisateur de consulter toutes les données stockées à son sujet [Must]
- FR-MEM-006 : Le profil utilisateur doit persister entre les sessions (préférences, profil handicap, configuration providers) [Must]
- FR-MEM-007 : Le nettoyage automatique de la mémoire épisodique doit supprimer les entrées > 30 jours sauf celles marquées comme importantes [Should]

**Plugin System (7 FRs) :**

- FR-PLG-001 : Chaque plugin doit implémenter l'interface abstraite KitaPlugin avec des méthodes de traitement de requête et de libération de ressources [Must]
- FR-PLG-002 : Chaque plugin doit déclarer un manifest YAML définissant : permissions, capabilities IA, metadata, profils compatibles [Must]
- FR-PLG-003 : Le PluginSandbox doit isoler chaque plugin et enforcer les permissions déclarées dans le manifest [Must]
- FR-PLG-004 : Le système doit supporter 3 niveaux de confiance : officiel (core), communautaire vérifié, non vérifié [Must]
- FR-PLG-005 : Le Plugin Describe doit capturer une photo, l'envoyer à un provider cloud IA, et vocaliser la description en < 5 secondes bout en bout [Must]
- FR-PLG-006 : Le Plugin Alert doit détecter les obstacles via IA locale (ML Kit / CoreML) et alerter (voix + haptique) en < 50ms [Must]
- FR-PLG-007 : Les plugins doivent pouvoir être chargés et déchargés dynamiquement sans redémarrage de l'application [Should]

**Onboarding & Configuration (8 FRs) :**

- FR-ONB-001 : L'onboarding doit être complétable en < 3 minutes en mode vocal-first [Must]
- FR-ONB-002 : L'onboarding doit détecter automatiquement VoiceOver (iOS) / TalkBack (Android) et adapter l'expérience immédiatement [Must]
- FR-ONB-003 : L'utilisateur doit pouvoir sélectionner son profil (aveugle, malvoyant, sourd, autiste, général) et recevoir le pack correspondant [Must]
- FR-ONB-004 : Le pack profil doit s'installer automatiquement avec les plugins et la configuration adaptés [Must]
- FR-ONB-005 : Chaque permission doit être expliquée dans son contexte d'usage avant d'être demandée [Must]
- FR-ONB-006 : Le mode découverte gratuit doit permettre d'utiliser Kita sans clé API (crédits limités) [Must]
- FR-ONB-007 : Le mode BYOK (Bring Your Own Key) doit permettre à l'utilisateur de configurer ses propres clés API providers [Must]
- FR-ONB-008 : Le mode "installé pour quelqu'un d'autre" doit permettre à un aidant de configurer Kita pour un tiers [Should]

**Sécurité & Vie Privée (5 FRs) :**

- FR-SEC-001 : Aucune donnée utilisateur ne doit quitter le téléphone sans consentement explicite [Must]
- FR-SEC-002 : Les requêtes cloud IA ne doivent contenir que le strict nécessaire — pas de profil utilisateur ni de contexte mémoire sauf demande explicite du plugin [Must]
- FR-SEC-003 : Les métadonnées identifiantes (EXIF, géolocalisation) doivent être supprimées des photos avant envoi au cloud [Must]
- FR-SEC-004 : L'application ne doit intégrer aucun tracking ni analytics identifiant sans consentement [Must]
- FR-SEC-005 : Le mode 100% hors-ligne doit être fonctionnel (dégradé mais utilisable pour les fonctions critiques) [Must]

### NonFunctional Requirements

**Performance (7 NFRs) :**

- NFR-PERF-001 : Temps de réponse alertes obstacles (IA locale) < 50ms
- NFR-PERF-002 : Description photo bout en bout (capture → voix) < 5 secondes
- NFR-PERF-003 : Démarrage TTS < 100ms
- NFR-PERF-004 : Latence STT local < 200ms
- NFR-PERF-005 : Cold start de l'application < 3 secondes
- NFR-PERF-006 : Consommation batterie en mode passif < 5% par heure
- NFR-PERF-007 : Mémoire RAM en mode passif < 200 MB

**Sécurité (6 NFRs) :**

- NFR-SEC-001 : Chiffrement données au repos AES-256 (Drift+SQLCipher)
- NFR-SEC-002 : Aucune donnée sensible dans les logs de l'app (0 fuite PII)
- NFR-SEC-003 : Clés API stockées dans Keychain (iOS) / Keystore (Android)
- NFR-SEC-004 : Strip des métadonnées EXIF avant envoi cloud (100% des photos)
- NFR-SEC-005 : Conformité RGPD Article 9 (données sensibles) — consentement explicite vérifié
- NFR-SEC-006 : Effacement complet sur "forget everything" — 0 donnée résiduelle récupérable

**Accessibilité (6 NFRs) :**

- NFR-ACC-001 : Conformité WCAG 2.1 niveau AA minimum
- NFR-ACC-002 : Compatibilité lecteurs d'écran 100% VoiceOver + TalkBack
- NFR-ACC-003 : Contraste texte >= 4.5:1
- NFR-ACC-004 : Contraste éléments UI >= 3:1
- NFR-ACC-005 : Labels accessibles sur 100% des éléments interactifs
- NFR-ACC-006 : Navigation complète sans écran (100% des flows critiques en vocal uniquement)

**Fiabilité (5 NFRs) :**

- NFR-REL-001 : Crashs sur flows critiques (onboarding, describe, alert) = 0
- NFR-REL-002 : Disponibilité fallback chain 100% — toujours une réponse
- NFR-REL-003 : Fonctionnement hors-ligne des fonctions critiques 100% (alertes, STT/TTS)
- NFR-REL-004 : Stabilité en exécution prolongée (mode passif 24h+) 0 crash, 0 memory leak
- NFR-REL-005 : Recovery après crash — temps de reprise du mode passif < 10 secondes

**Intégration (3 NFRs) :**

- NFR-INT-001 : Compatibilité providers IA (Claude, OpenAI) — support des 2 dernières versions majeures
- NFR-INT-002 : Interface plugin stable et rétrocompatible — 0 breaking change sans cycle de déprécation
- NFR-INT-003 : Compatibilité ML Kit / CoreML — versions stables supportées

**Testabilité (3 NFRs) :**

- NFR-TEST-001 : Couverture de tests > 80%
- NFR-TEST-002 : Tests d'accessibilité automatisés bloquants dans la CI
- NFR-TEST-003 : Tests sur appareils réels (au moins 3 Android + 2 iOS mid-range)

### Additional Requirements

**Architecture — Starter Template :**

- ARCH-001 : Le projet doit être initialisé avec `flutter create --org com.kita --platforms android,ios kita` — pas de template existant
- ARCH-002 : Structure feature-first + Clean Architecture (domain ← data ← presentation) dès l'initialisation
- ARCH-003 : Setup Riverpod 3.0 comme state management global dès le départ
- ARCH-004 : Setup Mix framework comme styling solution dès le départ
- ARCH-005 : Setup go_router avec les 6 routes définies (/, /onboarding, /settings, /settings/plugins, /settings/memory, /settings/forget)

**Architecture — Base de données :**

- ARCH-006 : Drift + SQLCipher comme remplacement d'Isar (abandonnée) — schéma initial avec 7 tables (episodes, preferences, persons, user_profiles, plugin_data, request_cache, consent_log)
- ARCH-007 : DAOs typesafe pour chaque table, retournant des objets domain (pas des row objects)
- ARCH-008 : Stratégie de migration Drift (from1To2, etc.)

**Architecture — Patterns d'implémentation :**

- ARCH-009 : sealed class KitaFailure + Result<T> pattern pour la gestion d'erreurs — jamais de throw non typé
- ARCH-010 : ProfileAdapter obligatoire pour tout output multi-modal — jamais d'output direct
- ARCH-011 : AsyncValue<T> (Riverpod) pour tous les états async
- ARCH-012 : Logger format [Source] Message — jamais de PII dans les logs (NFR-SEC-002)
- ARCH-013 : Semantics wrapper obligatoire sur chaque widget interactif — lint rule custom

**Architecture — Platform Channels :**

- ARCH-014 : com.kita/haptic — HapticAdapter (iOS UIImpactFeedback / Android VibrationEffect)
- ARCH-015 : com.kita/camera — CameraService modes (capture, stream, triggered)
- ARCH-016 : com.kita/secure_storage — Keychain/Keystore
- ARCH-017 : com.kita/background — Background service management (Android Foreground Service / iOS Background Audio + Location)
- ARCH-018 : com.kita/accessibility — VoiceOver/TalkBack detection

**Architecture — CI/CD :**

- ARCH-019 : GitHub Actions — lint (dart analyze), tests unitaires, tests a11y, couverture > 80%, builds Android/iOS
- ARCH-020 : Fastlane pour déploiement stores
- ARCH-021 : analysis_options.yaml avec lint rules strictes + Semantics enforcement
- ARCH-022 : Flavors dev / staging / prod

**Architecture — Sécurité :**

- ARCH-023 : flutter_secure_storage pour les clés API (Keychain/Keystore)
- ARCH-024 : ExifStripper avant envoi cloud
- ARCH-025 : Sentry (opt-in) pour crash reporting — zero PII

**UX Design — Composants custom :**

- UX-001 : KitaShell — Scaffold principal avec 3 zones (header + orbe/viewport + input), transition passif ↔ actif
- UX-002 : KitaOrb — Widget animé signature (6 états : passive, listening, processing, responding, error, offline), CustomPainter + AnimationController 60fps, prefers-reduced-motion
- UX-003 : KitaInput — Zone input unifiée voix + texte, 4 états (idle, listening, typing, disabled), touch target 56x56px
- UX-004 : KitaAlert — Alerte critique plein viewport (immediate/preventive), multi-modal (voix + vibration + visuel), liveRegion
- UX-005 : KitaPermissionCard — Permission Storytelling, 4 états (asking, granted, denied, re-asking), max 1 reproposition
- UX-006 : KitaStatusIndicator — État connexion/batterie/mode dans le header, couleurs sémantiques
- UX-007 : PluginViewport — Zone sandbox pour contenu plugin, scrollable, focus trap, live region
- UX-008 : KitaFeedbackBubble — Bulle de réponse (text, image, rich), avatar Kita, alt-text IA
- UX-009 : TranscriptionBubble — Bulle de transcription par locuteur (post-MVP)

**UX Design — Design System :**

- UX-010 : Palette couleurs (teal #0D9488 primary, violet #8B5CF6 accent, gris charbon #1A1A2E background) + mode clair
- UX-011 : Typographie (Space Grotesk titres, Nunito corps, JetBrains Mono tech), taille min 14px, ajustable 0.8x-2.0x
- UX-012 : Spacing grille 8px, touch targets min 48x48px (56x56px actions critiques)
- UX-013 : Motion design — transitions d'état lisibles, durées cohérentes (micro 150ms, transitions 300ms, états 500ms), prefers-reduced-motion
- UX-014 : Multi-modal feedback patterns (prise en charge, traitement, succès, erreur, warning, changement d'état)
- UX-015 : Command patterns cohérents (voix / texte / geste — chaque action faisable en voix DOIT être faisable en texte)

**UX Design — Journeys :**

- UX-016 : Journey onboarding Marie (flow vocal-first < 3 min, detection VoiceOver, Permission Storytelling, Premier Moment Magique)
- UX-017 : Journey "décris" (commande → feedback < 500ms → réponse < 5s → enchainement naturel)
- UX-018 : Journey alerte obstacle (détection passive → classification → alerte multi-modale → retour passif)
- UX-019 : Journey Sophie configure pour Marie (mode aidant, permissions groupées, test obligatoire)
- UX-020 : Journey fallback hors-ligne (annonce unique, mode dégradé, retour connexion)

**Développement multi-agents IA :**

- AGENT-001 : Chaque epic doit avoir des frontières claires et un scope indépendant permettant à un agent IA dédié de travailler dessus
- AGENT-002 : Les dépendances inter-epics doivent être minimales et explicites (interfaces/contrats définis en amont)
- AGENT-003 : Les stories au sein d'un epic doivent être séquentielles (Story N bloque Story N+1 dans le même epic) mais les epics peuvent avancer en parallèle après l'epic fondation

### FR Coverage Map

| FR | Epic | Description brève |
|---|---|---|
| FR-AI-001 | E2 | AI Router routing optimal |
| FR-AI-002 | E2 | RequestClassifier 4 niveaux |
| FR-AI-003 | E2 | Fallback chain cascade |
| FR-AI-004 | E2 | IA locale < 50ms |
| FR-AI-005 | E2 | Never-fail requêtes critiques |
| FR-AI-006 | E2 | Interface provider extensible |
| FR-PER-001 | E3 | Camera capture photo |
| FR-PER-002 | E3 | Camera mode passif stream |
| FR-PER-003 | E3 | AudioMultiplexer micro |
| FR-PER-004 | E3 | STT local < 200ms |
| FR-PER-005 | E3 | GPS + reverse geocoding |
| FR-PER-006 | E3 | Accéléromètre mouvement |
| FR-PER-007 | E10 | Mode passif permanent |
| FR-COM-001 | E3 | TTS < 100ms |
| FR-COM-002 | E3 | SpeechOutput file priorité |
| FR-COM-003 | E3 | Commandes vocales clés |
| FR-COM-004 | E8 | Interface textuelle alternative |
| FR-COM-005 | E3 | HapticService 3 patterns |
| FR-COM-006 | E8 | Annonces vocales changements d'état |
| FR-MEM-001 | E4 | Drift+SQLCipher AES-256 |
| FR-MEM-002 | E4 | 4 domaines mémoire |
| FR-MEM-003 | E4 | Consentement explicite |
| FR-MEM-004 | E4 | Forget 100% vérifiable |
| FR-MEM-005 | E4 | whatDoYouKnow transparence |
| FR-MEM-006 | E4 | Profil persistant |
| FR-MEM-007 | E4 | Nettoyage auto 30j |
| FR-PLG-001 | E5 | Interface KitaPlugin |
| FR-PLG-002 | E5 | Manifest YAML |
| FR-PLG-003 | E5 | PluginSandbox isolation |
| FR-PLG-004 | E5 | 3 niveaux confiance |
| FR-PLG-005 | E6 | Plugin Describe < 5s |
| FR-PLG-006 | E7 | Plugin Alert < 50ms |
| FR-PLG-007 | E5 | Chargement dynamique |
| FR-ONB-001 | E9 | Onboarding < 3 min |
| FR-ONB-002 | E9 | Détection VoiceOver/TalkBack |
| FR-ONB-003 | E9 | Sélection profil + pack |
| FR-ONB-004 | E9 | Pack auto-installé |
| FR-ONB-005 | E9 | Permission Storytelling |
| FR-ONB-006 | E9 | Mode découverte gratuit |
| FR-ONB-007 | E9 | Mode BYOK |
| FR-ONB-008 | E9 | Mode aidant Sophie |
| FR-SEC-001 | E4 | Zéro donnée hors téléphone sans consentement |
| FR-SEC-002 | E4 | Requêtes cloud strict minimum |
| FR-SEC-003 | E4 | Strip EXIF |
| FR-SEC-004 | E4 | Zéro tracking sans consentement |
| FR-SEC-005 | E4 | Mode 100% hors-ligne |

**Couverture : 46/46 FRs (100%)**

## Epic List

### Epic 1 : Fondation Kita — Le squelette vivant
Kita existe comme projet runnable avec toutes les interfaces architecturales définies — les contrats qui permettent à tous les autres epics de travailler en parallèle.
**FRs couvertes :** Aucune directement (infrastructure)
**Exigences :** ARCH-001→013, ARCH-021, partial ARCH-019

### Epic 2 : Kita comprend — Intelligence IA
Kita peut recevoir n'importe quelle requête, la classifier, la router vers le provider IA optimal, et garantir une réponse même en cas d'échec total (never-fail).
**FRs couvertes :** FR-AI-001, FR-AI-002, FR-AI-003, FR-AI-004, FR-AI-005, FR-AI-006

### Epic 3 : Kita perçoit et communique — Capteurs & I/O
Kita peut voir (caméra), entendre (STT), parler (TTS), toucher (haptique), se localiser (GPS) et détecter le mouvement.
**FRs couvertes :** FR-PER-001→006, FR-COM-001→005
**Exigences :** ARCH-014→018, ARCH-024

### Epic 4 : Kita se souvient — Mémoire & Vie Privée
Kita stocke les données localement avec chiffrement, respecte le RGPD Article 9, permet le droit à l'oubli vérifiable et la transparence totale.
**FRs couvertes :** FR-MEM-001→007, FR-SEC-001→005
**Exigences :** ARCH-023

### Epic 5 : Kita est extensible — Système de Plugins
La plateforme plugin fonctionne : interface KitaPlugin, manifest YAML, sandbox avec 3 niveaux de confiance, chargement dynamique.
**FRs couvertes :** FR-PLG-001, FR-PLG-002, FR-PLG-003, FR-PLG-004, FR-PLG-007

### Epic 6 : Marie voit — Plugin Describe
Marie dit "décris" et reçoit une description vocale précise en < 5 secondes. Le Premier Moment Magique.
**FRs couvertes :** FR-PLG-005
**Exigences :** UX-017
**Dépendances :** E2, E3, E5

### Epic 7 : Marie est protégée — Plugin Alert
Kita détecte les obstacles via IA locale et alerte Marie en < 50ms. 100% local, zéro dépendance cloud.
**FRs couvertes :** FR-PLG-006
**Exigences :** UX-018
**Dépendances :** E3, E5

### Epic 8 : Kita prend vie — Shell Living Aura
L'interface Living Aura : orbe animée teal/violet, shell avec viewport plugin, input vocal/texte, ProfileAdapter multi-modal, design system complet.
**FRs couvertes :** FR-COM-004, FR-COM-006
**Exigences :** UX-001→015, ARCH-010, ARCH-013
**Dépendances :** E1 uniquement (mocks pour le reste)

### Epic 9 : Kita accueille — Onboarding Marie
Marie complète l'onboarding en < 3 minutes. Sophie peut configurer pour un tiers.
**FRs couvertes :** FR-ONB-001→008
**Exigences :** UX-016, UX-019
**Dépendances :** E5, E6, E7, E8

### Epic 10 : Kita veille — Mode Passif & Background
Kita reste active en arrière-plan avec gestion intelligente de la batterie et capteurs adaptatifs.
**FRs couvertes :** FR-PER-007
**Exigences :** ARCH-017, ARCH-025
**Dépendances :** E3, E7

### Epic 11 : Prêt pour le monde — Qualité & Déploiement
Pipeline CI/CD complet, couverture tests > 80%, tests a11y bloquants, Fastlane stores. Kita est prête pour la beta.
**FRs couvertes :** (transversales)
**Exigences :** NFR-TEST-001→003, ARCH-019, ARCH-020, UX-020
**Dépendances :** Tous les epics

### Diagramme de parallélisme multi-agents

```
Phase 1:  E1 (Fondation)                          → 1 agent
              │
Phase 2:  ├── E2 (IA)           ─────────┐
          ├── E3 (Capteurs/I/O)  ─────────┤
          ├── E4 (Mémoire)       ─────────┤        → 5 agents en parallèle
          ├── E5 (Plugins)       ─────────┤
          └── E8 (Shell UI)      ─────────┘
                                          │
Phase 3:      E6 (Describe) + E7 (Alert)           → 2 agents en parallèle
                        │
Phase 4:      E9 (Onboarding) + E10 (Background)  → 2 agents en parallèle
                        │
Phase 5:      E11 (Qualité & Déploiement)          → 1 agent
```

### Conventions de développement multi-agents

**Stratégie de branches :**
- `main` = stable, protégée
- `develop` = intégration continue
- `epic/e{N}-{nom}` = branche par agent, branchée depuis `develop`
- Chaque story = une PR squash-merge vers `develop`
- Les PRs sont mergées dans l'ordre des stories (N.1 avant N.2)
- Chaque agent rebase depuis `develop` au début de chaque nouvelle story

**Propriété des fichiers :**
- Chaque feature possède ses fichiers dans `features/{feature}/`
- Les fichiers `core/` sont propriété exclusive de E1 (Fondation)
- `pubspec.yaml`, `database.dart`, `analysis_options.yaml` = modifiés uniquement par E1
- Les fichiers générés (`*.g.dart`, `*.freezed.dart`) ne sont PAS commités

**Phase Gates :**

| Transition | Critères de passage |
|---|---|
| Phase 1→2 | E1 mergé, 8 stories vertes, `flutter test` pass, `dart analyze` clean, `build_runner` OK, toutes interfaces compilent |
| Phase 2→3 | E2-E5+E8 mergés, Story 2.8 (Integration Gate) passe, couverture > 70% par feature |
| Phase 3→4 | E6+E7 mergés, Story 7.3 (Integration Gate) passe, flows Describe + Alert E2E OK |
| Phase 4→5 | E9+E10 mergés, Story 10.4 (Integration Gate) passe, onboarding E2E OK, passif stable 1h |
| Phase 5→Release | E11 complet, couverture > 80%, tests a11y bloquants, builds signés, Fastlane déploie |

**Accessibility Tax (obligatoire pour toute story avec UI) :**
- Chaque widget interactif → `Semantics` wrapper avec label descriptif
- Contrastes texte >= 4.5:1, éléments UI >= 3:1
- Touch targets >= 48x48px (56x56px actions critiques)
- Semantics test matcher dans les tests unitaires

---

## Epic 1 : Fondation Kita — Le squelette vivant

Kita existe comme projet runnable avec toutes les interfaces architecturales définies — les contrats qui permettent à tous les autres epics de travailler en parallèle.

### Story 1.1 : Initialisation du projet Flutter et structure feature-first

As a **développeur**,
I want **un projet Flutter initialisé avec la structure feature-first + Clean Architecture**,
So that **tous les agents peuvent commencer à travailler dans des répertoires isolés et bien définis**.

**Acceptance Criteria:**

**Given** aucun code source n'existe
**When** le projet est initialisé avec `flutter create --org com.kita --platforms android,ios kita`
**Then** le projet compile et s'exécute sur un émulateur Android et un simulateur iOS
**And** la structure de répertoires feature-first est créée (`lib/core/`, `lib/features/ai/`, `lib/features/io/`, `lib/features/memory/`, `lib/features/plugins/`, `lib/features/onboarding/`, `lib/features/shell/`, `lib/features/settings/`, `lib/shared/`, `lib/platform/`)
**And** chaque feature contient les sous-répertoires `domain/`, `data/`, `presentation/`
**And** `test/` miroir la structure de `lib/`
**And** `analysis_options.yaml` est configuré avec les lint rules strictes (flutter_lints + Semantics enforcement)
**And** `pubspec.yaml` contient toutes les dépendances du projet : `flutter_riverpod`, `riverpod_annotation`, `go_router`, `mix`, `drift`, `sqlcipher_flutter_libs`, `flutter_secure_storage`, `speech_to_text`, `flutter_tts`, `camera`, `geolocator`, `geocoding`, `sensors_plus`, `http`, `yaml`, `tflite_flutter`, `image`, `path_provider`, `freezed_annotation`, `json_annotation`, `permission_handler`, `google_mlkit_object_detection`
**And** les dev_dependencies incluent : `build_runner`, `riverpod_generator`, `drift_dev`, `freezed`, `json_serializable`, `sentry_flutter`
**And** `.gitignore` exclut les fichiers générés (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`)

### Story 1.2 : Core patterns — Gestion d'erreurs et logging

As a **développeur**,
I want **les patterns de gestion d'erreurs (KitaFailure, Result<T>) et le logger unifiés**,
So that **tous les agents utilisent les mêmes patterns d'erreur et de logging dès le départ**.

**Acceptance Criteria:**

**Given** le projet Flutter est initialisé (Story 1.1)
**When** les core patterns sont implémentés
**Then** `core/errors/kita_failure.dart` contient la sealed class `KitaFailure` avec les sous-types : `NetworkFailure`, `AIProviderFailure`, `PluginFailure`, `StorageFailure`, `PermissionFailure`
**And** chaque `KitaFailure` expose `userMessage` et `logMessage`
**And** `core/errors/result.dart` contient le type `Result<T>` avec `Success(data)` et `Failure(error)`
**And** `core/utils/logger.dart` implémente le format `[Source] Message` avec les niveaux debug/info/warning/error/critical
**And** le logger ne contient JAMAIS de PII (test unitaire vérifiant le pattern)
**And** `core/config/app_config.dart` contient les constantes (timeouts, limites, TTL)
**And** `core/config/environment.dart` gère les flavors dev/staging/prod
**And** `core/constants/durations.dart` et `core/constants/limits.dart` sont créés

### Story 1.3 : State management Riverpod 3.0 et DI

As a **développeur**,
I want **Riverpod 3.0 configuré comme state management global avec les providers de base**,
So that **chaque feature peut injecter ses dépendances de manière typesafe et cohérente**.

**Acceptance Criteria:**

**Given** les core patterns existent (Story 1.2)
**When** Riverpod 3.0 est configuré
**Then** `main.dart` wraps l'app dans `ProviderScope`
**And** chaque feature déclare ses providers dans `features/{feature}/di/providers.dart` (pas de fichier centralisé — Riverpod 3.0 `@riverpod` gère le registre via code generation)
**And** `core/di/service_locator.dart` initialise les services au boot
**And** les conventions de naming sont suivies : `{feature}Provider`, `{feature}NotifierProvider`, `{feature}ServiceProvider`
**And** un test unitaire vérifie que `ProviderScope` démarre sans erreur
**And** `build_runner` est configuré pour la code generation Riverpod

### Story 1.4 : Design System Mix et tokens multi-modaux

As a **développeur**,
I want **le framework Mix configuré avec tous les design tokens (visuels, vocaux, haptiques)**,
So that **les composants UI sont stylés de manière cohérente avec l'identité Living Aura**.

**Acceptance Criteria:**

**Given** Riverpod est configuré (Story 1.3)
**When** le design system est implémenté
**Then** `core/theme/kita_theme.dart` configure Mix avec l'identité Living Aura
**And** `core/theme/mix_tokens.dart` définit les tokens visuels : couleurs (teal `#0D9488` primary, violet `#8B5CF6` accent, charbon `#1A1A2E` background), typographie (Space Grotesk titres, Nunito corps), spacing grille 8px, border radii
**And** `core/theme/multi_modal_tokens.dart` définit les durées d'animation (micro 150ms, transitions 300ms, états 500ms) et les intensités haptiques
**And** `core/theme/accessibility_tokens.dart` définit les contraintes a11y (contraste min 4.5:1, taille tactile min 48px, taille texte min 14px)
**And** le mode clair et le mode sombre sont définis
**And** les fonts Space Grotesk et Nunito sont incluses dans `assets/`

### Story 1.5 : Navigation go_router et écrans placeholder

As a **développeur**,
I want **go_router configuré avec les 6 routes et des écrans placeholder**,
So that **la navigation de l'app est fonctionnelle et chaque agent peut implémenter son écran indépendamment**.

**Acceptance Criteria:**

**Given** le design system est configuré (Story 1.4)
**When** go_router est configuré
**Then** `app.dart` contient `KitaApp` avec `MaterialApp.router` et la configuration go_router
**And** les 6 routes sont définies : `/` (KitaShell), `/onboarding`, `/settings`, `/settings/plugins`, `/settings/memory`, `/settings/forget`
**And** chaque route affiche un écran placeholder fonctionnel
**And** la navigation entre les routes fonctionne correctement
**And** un test vérifie que chaque route résout correctement

### Story 1.6 : Infrastructure Drift + SQLCipher

As a **développeur**,
I want **Drift + SQLCipher configurés avec la base de données chiffrée vide**,
So that **les epics Mémoire et Plugins peuvent ajouter leurs tables à la DB chiffrée**.

**Acceptance Criteria:**

**Given** le projet est structuré (Story 1.1)
**When** Drift + SQLCipher est configuré
**Then** `core/config/database_config.dart` initialise SQLCipher avec chiffrement AES-256
**And** `core/data/database.dart` contient la classe `KitaDatabase` qui importe les tables Drift de chaque feature
**And** les 7 tables sont pré-déclarées dans des fichiers `.drift` séparés par feature : `features/ai/data/tables/` (request_cache), `features/memory/data/tables/` (episodes, preferences, persons, user_profiles, consent_log), `features/plugins/data/tables/` (plugin_data) — colonnes définies, DAOs implémentés par chaque agent dans son epic
**And** convention : chaque agent crée ses DAOs dans `features/{feature}/data/daos/` sans toucher `database.dart`
**And** `build_runner` est configuré pour la code generation Drift
**And** `dart run build_runner build` s'exécute sans erreur
**And** un test unitaire vérifie que la DB s'ouvre et se ferme correctement avec chiffrement
**And** le fichier DB est illisible sans la clé de chiffrement

### Story 1.7 : Interfaces domain — Contrats pour le travail parallèle

As a **développeur**,
I want **toutes les interfaces domain définies (AI, I/O, Memory, Plugin, Multi-modal)**,
So that **les agents des Epics 2-5 et 8 peuvent implémenter contre ces contrats en parallèle**.

**Acceptance Criteria:**

**Given** les core patterns et Drift existent (Stories 1.2, 1.6)
**When** les interfaces domain sont créées
**Then** `features/ai/domain/` contient : `AIProvider` (abstract class avec id, displayName, tier, isAvailable, complete, vision, validateApiKey), `AIRequest`, `AIResponse`, `AIRouter` interface, `RequestClassifier` interface, `ProviderTier` enum
**And** `features/io/domain/` contient : `CameraService`, `AudioService`, `STTService`, `TTSService`, `HapticService`, `LocationService`, `MotionService` interfaces
**And** `features/memory/domain/` contient : `MemoryVault` interface (forget, whatDoYouKnow, saveEpisode, getPreference), `MemoryDomain` enum (working, episodic, semantic, relational), `ForgetRequest`, `ConsentEntry`
**And** `features/plugins/domain/` contient : `KitaPlugin` (abstract class avec manifest, onActivate, onDeactivate, handleRequest, buildViewport, voiceCommands), `PluginManifest`, `PluginSandbox` interface, `PluginRequest`, `PluginResponse`, `SensorAccess`, `AIAccess`, `MemoryAccess` proxy interfaces, `TrustLevel` enum
**And** `shared/multi_modal/` contient : `ProfileAdapter` interface (feedback avec visual/vocal/haptic callbacks)
**And** `platform/platform_bridge.dart` contient l'interface `PlatformBridge`
**And** aucune interface n'importe de `data/` (règle Clean Architecture)
**And** `test/mocks/` contient les mocks partagés implémentant chaque interface : `mock_ai_provider.dart`, `mock_camera_service.dart`, `mock_tts_service.dart`, `mock_stt_service.dart`, `mock_haptic_service.dart`, `mock_memory_vault.dart`, `mock_plugin_registry.dart`, `mock_profile_adapter.dart`
**And** chaque mock retourne des données cohérentes issues des golden fixtures (`test/fixtures/`)

### Story 1.8 : CI/CD stub et infrastructure open source

As a **développeur**,
I want **le pipeline CI de base et les fichiers open source en place**,
So that **chaque PR est automatiquement lintée et testée dès le premier commit**.

**Acceptance Criteria:**

**Given** le projet est complet avec patterns et interfaces (Stories 1.1-1.7)
**When** l'infrastructure CI est mise en place
**Then** `.github/workflows/ci.yml` exécute : `dart analyze`, `flutter test`, couverture de code
**And** `dart run build_runner build` est exécuté comme step CI obligatoire avant les tests
**And** les tests existants (Stories 1.2, 1.3, 1.5, 1.6) passent dans la CI
**And** `flutter test --tags accessibility` vérifie la présence des Semantics sur les widgets interactifs
**And** `.env.example` contient le template des clés API
**And** `.gitignore` exclut correctement les fichiers sensibles et générés
**And** `test/fixtures/` contient les golden fixtures partagées : `ai_responses/` (vision_success.json, vision_fallback.json), `images/` (test_photo.jpg avec EXIF, test_photo_stripped.jpg), `plugins/` (valid_manifest.yaml, invalid_manifest.yaml), `memory/` (episode_sample.json, user_profile_sample.json)
**And** `LICENSE` contient la licence MIT
**And** les templates GitHub (bug report, feature request, PR template) sont créés dans `.github/`
**And** `assets/sounds/` contient les fichiers son de fallback (alert_danger.wav, alert_warning.wav, confirmation.wav)

---

## Epic 2 : Kita comprend — Intelligence IA

Kita peut recevoir n'importe quelle requête, la classifier, la router vers le provider IA optimal, et garantir une réponse même en cas d'échec total (never-fail).

### Story 2.1 : RequestClassifier — Classification des requêtes

As a **système Kita**,
I want **classifier automatiquement chaque requête en 4 niveaux de priorité**,
So that **les requêtes critiques sont traitées localement en < 50ms et les requêtes standard via le cloud**.

**Acceptance Criteria:**

**Given** l'interface `RequestClassifier` existe (Epic 1)
**When** l'implémentation `RequestClassifierImpl` est créée
**Then** chaque requête est classée en : `critical` (< 50ms, local uniquement), `urgent` (< 500ms), `standard` (< 5s), `background` (async)
**And** les mots-clés "alerte", "danger", "obstacle" sont classés `critical`
**And** les mots-clés "décris", "lis" sont classés `standard`
**And** la classification prend < 1ms
**And** les tests unitaires couvrent les 4 niveaux avec des cas concrets
**And** le classifier retourne un `Result<RequestPriority>`

### Story 2.2 : FallbackChain never-fail

As a **utilisateur de Kita**,
I want **que Kita me réponde toujours, même quand tout échoue**,
So that **je ne suis jamais laissé sans réponse, surtout dans les situations critiques**.

**Acceptance Criteria:**

**Given** un `AIRequest` classifié arrive dans la fallback chain
**When** le provider cloud-powerful échoue (timeout 3s)
**Then** la requête cascade vers cloud-fast (timeout 3s)
**And** si cloud-fast échoue, la requête cascade vers le provider local
**And** si le provider local échoue, une alerte brute (son + vibration hardcodé) est déclenchée
**And** une requête classée `critical` ne passe JAMAIS par le cloud — traitement local direct
**And** chaque niveau de cascade log le fallback avec le niveau `warning`
**And** le dernier niveau (alerte brute) ne peut PAS échouer — `Result.success` garanti
**And** les tests unitaires simulent les échecs en cascade et vérifient que la réponse est toujours `Success`

### Story 2.3 : AIRouter — Orchestration des providers

As a **système Kita**,
I want **un routeur IA qui orchestre les providers selon la classification et la disponibilité**,
So that **chaque requête est traitée par le provider optimal disponible**.

**Acceptance Criteria:**

**Given** le `RequestClassifier` et la `FallbackChain` existent (Stories 2.1, 2.2)
**When** l'`AIRouterImpl` est implémenté
**Then** le routeur sélectionne le provider optimal selon : priorité de la requête, disponibilité du provider, tier du provider (local/cloudFast/cloudPowerful)
**And** les requêtes `critical` sont toujours routées vers le tier local
**And** les requêtes `standard` tentent cloud-powerful en premier
**And** le routeur utilise la `FallbackChain` en cas d'échec
**And** chaque réponse est un `AIResponse` unifié avec `meta` (provider, latency, tier, cached) et `status` (success, fallback, degraded)
**And** le routeur est injectable via Riverpod (`aiRouterServiceProvider`)

### Story 2.4 : Provider Claude (Anthropic API)

As a **utilisateur de Kita**,
I want **que Kita puisse utiliser Claude comme provider IA cloud**,
So that **j'obtiens des descriptions de haute qualité via l'API Anthropic**.

**Acceptance Criteria:**

**Given** l'interface `AIProvider` existe et l'`AIRouter` est implémenté
**When** le `ClaudeProvider` est créé
**Then** il implémente `AIProvider` avec `tier = ProviderTier.cloudPowerful`
**And** `complete()` envoie une requête texte à l'API Claude et retourne un `AIResponse`
**And** `vision()` envoie une image + prompt et retourne une description textuelle
**And** `validateApiKey()` vérifie la validité de la clé API
**And** les erreurs réseau retournent `Result.failure(NetworkFailure)` — jamais de throw
**And** le timeout est configurable (défaut 3s)
**And** aucune donnée PII n'est incluse dans la requête
**And** les tests unitaires mockent l'API et vérifient les cas succès/échec/timeout

### Story 2.5 : Provider OpenAI

As a **utilisateur de Kita**,
I want **que Kita puisse utiliser OpenAI comme provider IA alternatif**,
So that **j'ai le choix entre plusieurs providers et un fallback cloud**.

**Acceptance Criteria:**

**Given** le `ClaudeProvider` fonctionne comme référence (Story 2.4)
**When** le `OpenAIProvider` est créé
**Then** il implémente `AIProvider` avec `tier = ProviderTier.cloudFast`
**And** `complete()` et `vision()` fonctionnent de manière identique au `ClaudeProvider` mais via l'API OpenAI
**And** `validateApiKey()` vérifie la clé OpenAI
**And** le même format `AIResponse` est retourné
**And** les tests unitaires couvrent les mêmes cas que le `ClaudeProvider`

### Story 2.6 : Providers locaux ML Kit et CoreML

As a **utilisateur de Kita**,
I want **que Kita puisse traiter les requêtes localement via ML Kit (Android) et CoreML (iOS)**,
So that **les alertes critiques fonctionnent en < 50ms sans connexion internet**.

**Acceptance Criteria:**

**Given** l'interface `AIProvider` existe
**When** les providers locaux sont implémentés
**Then** `MLKitProvider` (Android) implémente `AIProvider` avec `tier = ProviderTier.local`
**And** `CoreMLProvider` (iOS) implémente `AIProvider` avec `tier = ProviderTier.local`
**And** chaque provider supporte OCR (lecture de texte) et classification d'image basique
**And** `isAvailable` détecte la plateforme courante et retourne `true` uniquement sur la bonne plateforme
**And** la latence de traitement est < 50ms (mesuré par test de performance)
**And** les providers fonctionnent 100% hors-ligne
**And** les tests vérifient la détection de plateforme et le fallback

### Story 2.7 : ResponseCache — Cache des réponses IA

As a **système Kita**,
I want **cacher les réponses IA dans Drift selon la priorité de la requête**,
So that **les requêtes répétées sont servies instantanément et la batterie est économisée**.

**Acceptance Criteria:**

**Given** Drift est configuré et l'`AIRouter` fonctionne
**When** le `ResponseCache` est implémenté
**Then** la table `request_cache` est créée dans Drift avec les colonnes : hash requête, réponse, provider, TTL, created_at
**And** les requêtes `critical` ne sont JAMAIS cachées (toujours frais)
**And** les requêtes `urgent` sont cachées 30s
**And** les requêtes `standard` sont cachées 5 min
**And** les requêtes `background` sont cachées 1h
**And** le cache est consulté AVANT de router vers un provider
**And** les entrées expirées sont nettoyées automatiquement
**And** les tests vérifient le hit/miss cache et l'expiration TTL

### Story 2.8 : Integration Gate Phase 2

As a **équipe de développement**,
I want **valider que les 5 features de Phase 2 s'intègrent correctement avant de lancer Phase 3**,
So that **les plugins Describe et Alert peuvent être développés sur une base solide et validée**.

**Acceptance Criteria:**

**Given** les Epics 2, 3, 4, 5 et 8 sont mergés sur `develop`
**When** les tests d'intégration inter-features sont exécutés
**Then** test smoke : l'app démarre, l'orbe s'affiche, un input texte est traité par l'AIRouter (mock provider), une réponse est vocalisée via TTS
**And** test chaîne IA : `AIRouter` reçoit une requête vision → route vers un provider mock → reçoit une réponse → passe par `ProfileAdapter` → output TTS
**And** test plugin-capteurs : `PluginRegistry` charge un plugin mock → le plugin demande `SensorAccess.capturePhoto()` → reçoit une image mock
**And** test mémoire réelle : `MemoryVault.saveEpisode()` → `whatDoYouKnow()` retourne l'épisode (Drift réel, pas de mock DB)
**And** test ProfileAdapter : chaque profil (aveugle, sourd, standard) route les outputs vers les bonnes modalités
**And** `dart analyze` et `flutter test` passent à 100% sur la branche `develop`
**And** la couverture de chaque feature est > 70%

---

## Epic 3 : Kita perçoit et communique — Capteurs & I/O

Kita peut voir (caméra), entendre (STT), parler (TTS), toucher (haptique), se localiser (GPS) et détecter le mouvement.

### Story 3.1 : CameraService — Capture photo et flux vidéo

As a **utilisateur de Kita**,
I want **que Kita puisse prendre une photo à la demande et streamer la vidéo en continu**,
So that **le Plugin Describe peut capturer une photo et le Plugin Alert peut détecter des obstacles en temps réel**.

**Acceptance Criteria:**

**Given** l'interface `CameraService` existe (Epic 1)
**When** `CameraServiceImpl` est implémenté via le platform channel `com.kita/camera`
**Then** `capturePhoto()` retourne un `Result<ImageData>` avec une photo de la caméra arrière
**And** `startStream()` fournit un flux vidéo continu à 15-30 FPS (configurable)
**And** `stopStream()` arrête le flux et libère les ressources
**And** les erreurs (permission refusée, caméra indisponible) retournent `Result.failure(PermissionFailure)`
**And** le code natif Swift (`CameraChannel.swift`) utilise AVFoundation
**And** le code natif Kotlin (`CameraChannel.kt`) utilise CameraX
**And** les tests unitaires mockent le platform channel

### Story 3.2 : STTService — Reconnaissance vocale locale

As a **utilisateur de Kita**,
I want **que Kita transcrive ma voix en texte en < 200ms**,
So that **je peux donner des commandes vocales naturellement**.

**Acceptance Criteria:**

**Given** l'interface `STTService` existe (Epic 1)
**When** `STTServiceImpl` est implémenté via `speech_to_text`
**Then** `startListening()` commence la transcription et émet un stream de résultats partiels
**And** `stopListening()` arrête la transcription
**And** la latence entre la fin de la parole et le résultat final est < 200ms
**And** la langue par défaut est le français
**And** les erreurs (permission micro refusée) retournent `Result.failure(PermissionFailure)`
**And** les tests unitaires vérifient les cas succès/permission refusée

### Story 3.3 : TTSService — Synthèse vocale avec file de priorité

As a **utilisateur de Kita**,
I want **que Kita me parle avec un démarrage < 100ms et une file de priorité**,
So that **les alertes critiques ne sont jamais interrompues par des messages moins urgents**.

**Acceptance Criteria:**

**Given** l'interface `TTSService` existe (Epic 1)
**When** `TTSServiceImpl` et le `SpeechOutputService` sont implémentés via `flutter_tts`
**Then** `speak(text, priority)` ajoute le message à la file de priorité et démarre la synthèse en < 100ms
**And** la file de priorité respecte : critique > urgent > standard
**And** un message `critical` interrompt IMMÉDIATEMENT un message `standard` en cours
**And** un message `standard` ne peut PAS interrompre un message `critical`
**And** `stop()` arrête la synthèse immédiatement
**And** la langue par défaut est le français avec une voix naturelle
**And** les tests vérifient l'ordre de priorité et l'interruption

### Story 3.4 : HapticService — Retour haptique différencié

As a **utilisateur de Kita**,
I want **recevoir des vibrations différentes selon le type d'alerte (info, warning, danger)**,
So that **je peux distinguer les alertes par le toucher sans regarder l'écran**.

**Acceptance Criteria:**

**Given** l'interface `HapticService` existe (Epic 1)
**When** `HapticServiceImpl` est implémenté via le platform channel `com.kita/haptic`
**Then** `trigger(HapticPattern.info)` produit 1 vibration légère
**And** `trigger(HapticPattern.warning)` produit 2 vibrations moyennes
**And** `trigger(HapticPattern.danger)` produit 3 vibrations fortes
**And** le code natif Swift utilise `UIImpactFeedbackGenerator` (light/medium/heavy)
**And** le code natif Kotlin utilise `VibrationEffect` avec patterns custom
**And** les tests vérifient que les 3 patterns sont envoyés au platform channel avec les bons paramètres

### Story 3.5 : AudioMultiplexer — Multiplexage microphone

As a **système Kita**,
I want **multiplexer le microphone entre la reconnaissance vocale (STT) et l'analyse ambiante**,
So that **Kita peut écouter les commandes vocales tout en analysant l'environnement sonore**.

**Acceptance Criteria:**

**Given** le `STTService` fonctionne (Story 3.2)
**When** l'`AudioMultiplexer` est implémenté
**Then** le multiplexer gère l'accès exclusif ou partagé au microphone
**And** le mode STT (commandes vocales) a la priorité sur l'analyse ambiante
**And** le basculement entre modes est transparent (< 100ms)
**And** les ressources audio sont correctement libérées quand non utilisées
**And** les tests vérifient le basculement et la priorité

### Story 3.6 : LocationService et MotionService

As a **utilisateur de Kita**,
I want **que Kita connaisse ma position et mon état de mouvement**,
So that **les plugins peuvent adapter leur comportement au contexte géographique et à mon activité**.

**Acceptance Criteria:**

**Given** les interfaces `LocationService` et `MotionService` existent (Epic 1)
**When** les implémentations sont créées
**Then** `LocationServiceImpl` fournit les coordonnées GPS, l'adresse inversée et les POIs proches
**And** `MotionServiceImpl` détecte l'état de mouvement via l'accéléromètre : immobile, marche, course
**And** le GPS est activé uniquement sur demande (pas en continu par défaut)
**And** le mouvement est utilisable pour adapter le FPS caméra (immobile → 5 FPS, marche → 15 FPS, course → 30 FPS)
**And** les erreurs de permission retournent `Result.failure(PermissionFailure)`
**And** les tests vérifient la classification de mouvement

### Story 3.7 : ExifStripper et commandes vocales

As a **utilisateur de Kita**,
I want **que mes photos soient nettoyées de métadonnées avant envoi cloud et que Kita reconnaisse mes commandes**,
So that **ma vie privée est protégée et je peux interagir naturellement**.

**Acceptance Criteria:**

**Given** le `CameraService` et le `STTService` fonctionnent
**When** l'`ExifStripper` et le gestionnaire de commandes vocales sont implémentés
**Then** `ExifStripper.strip(imageData)` supprime toutes les métadonnées EXIF (GPS, appareil, date) de l'image
**And** l'image retournée est utilisable mais dépourvue de données identifiantes
**And** un test vérifie que 100% des champs EXIF sont supprimés
**And** le gestionnaire de commandes vocales reconnaît : "décris", "lis ça", "stop", "aide", "merci", "répète"
**And** les commandes sont case-insensitive et tolérantes aux variations ("décrit" = "décris")
**And** une commande non reconnue retourne un `Result.failure` approprié

---

## Epic 4 : Kita se souvient — Mémoire & Vie Privée

Kita stocke les données localement avec chiffrement, respecte le RGPD Article 9, permet le droit à l'oubli vérifiable et la transparence totale.

### Story 4.1 : Tables Drift et DAOs — Schéma mémoire

As a **système Kita**,
I want **les 7 tables Drift créées avec leurs DAOs typesafe**,
So that **toutes les données utilisateur sont stockées de manière structurée et chiffrée**.

**Acceptance Criteria:**

**Given** Drift + SQLCipher est configuré avec les schémas de tables pré-déclarés (Epic 1 Stories 1.6)
**When** les DAOs typesafe pour les 6 tables mémoire sont implémentés
**Then** un DAO typesafe existe pour chaque table mémoire : `EpisodeDao`, `PreferenceDao`, `PersonDao`, `ProfileDao`, `PluginDataDao`, `ConsentDao` (note : `CacheDao` appartient à E2 Story 2.7)
**And** chaque DAO utilise les colonnes définies dans les schémas `.drift` pré-déclarés (id, created_at, etc.)
**And** chaque DAO retourne des objets domain, pas des row objects
**And** `dart run build_runner build` génère le code sans erreur
**And** les tests unitaires vérifient le CRUD de base sur chaque DAO
**And** la migration initiale (v1) est définie

### Story 4.2 : MemoryVault — Stockage avec consentement

As a **utilisateur de Kita**,
I want **que Kita demande mon consentement explicite avant de stocker mes données sensibles**,
So that **je contrôle ce que Kita sait sur moi, conformément au RGPD Article 9**.

**Acceptance Criteria:**

**Given** les tables Drift et DAOs existent (Story 4.1)
**When** `MemoryVaultImpl` est implémenté
**Then** `saveEpisode(data)` stocke un événement horodaté dans le domaine episodic avec tags auto
**And** `savePreference(key, value, category)` stocke une préférence dans le domaine semantic
**And** tout stockage de données sensibles (profil handicap) exige un consentement explicite via `ConsentDao`
**And** le consentement est tracé dans `consent_log` avec date, type de donnée et choix de l'utilisateur
**And** le stockage est refusé si le consentement n'a pas été donné — retourne `Result.failure`
**And** les 4 domaines de mémoire (working, episodic, semantic, relational) sont fonctionnels
**And** les tests vérifient le flux consentement → stockage → vérification

### Story 4.3 : Droit à l'oubli — Forget et transparence

As a **utilisateur de Kita**,
I want **pouvoir effacer toutes mes données et voir tout ce que Kita sait sur moi**,
So that **j'ai le contrôle total sur ma vie privée**.

**Acceptance Criteria:**

**Given** le `MemoryVault` stocke des données (Story 4.2)
**When** les fonctions forget et transparence sont implémentées
**Then** `forget(ForgetRequest.everything)` efface 100% des données de toutes les tables
**And** `forget(ForgetRequest.domain(MemoryDomain.episodic))` efface uniquement le domaine spécifié
**And** `forget(ForgetRequest.plugin(pluginId))` efface uniquement les données d'un plugin
**And** après `forget()`, un audit vérifie qu'aucune donnée résiduelle n'existe — 0 donnée récupérable
**And** `whatDoYouKnow()` retourne une liste structurée de toutes les données stockées par domaine
**And** les tests vérifient l'effacement complet et la vérification d'audit

### Story 4.4 : Profil utilisateur persistant et secure storage

As a **utilisateur de Kita**,
I want **que mon profil (préférences, accessibilité, providers) persiste entre les sessions et que mes clés API soient stockées en sécurité**,
So that **je n'ai pas à reconfigurer Kita à chaque lancement**.

**Acceptance Criteria:**

**Given** les DAOs Profile et Preference existent (Story 4.1)
**When** le profil persistant et le secure storage sont implémentés
**Then** le profil utilisateur (nom, profil accessibilité, langue, voix TTS, vitesse) persiste dans `user_profiles`
**And** les clés API sont stockées dans Keychain (iOS) / Keystore (Android) via `flutter_secure_storage`
**And** les clés API ne sont JAMAIS stockées en clair ni dans les logs
**And** au lancement, le profil est chargé et les providers IA configurés automatiquement
**And** `PreferencesRepository` fournit une interface Riverpod pour lire/écrire les préférences
**And** les tests vérifient la persistance entre sessions simulées

### Story 4.5 : Nettoyage automatique et politique de données

As a **système Kita**,
I want **nettoyer automatiquement les données épisodiques > 30 jours sauf celles marquées comme importantes**,
So that **la base de données ne grossit pas indéfiniment et la vie privée est respectée**.

**Acceptance Criteria:**

**Given** des données épisodiques existent dans le MemoryVault (Story 4.2)
**When** le nettoyage automatique s'exécute
**Then** les épisodes > 30 jours sont supprimés automatiquement
**And** les épisodes marqués `important = true` sont préservés indéfiniment
**And** le nettoyage s'exécute au lancement de l'app et toutes les 24h
**And** aucune donnée utilisateur ne quitte le téléphone sans consentement explicite
**And** les requêtes cloud IA ne contiennent que le strict nécessaire (pas de profil, pas de contexte mémoire sauf demande explicite)
**And** aucun tracking ni analytics identifiant n'est intégré
**And** les tests vérifient le nettoyage sélectif (ancien vs important)

---

## Epic 5 : Kita est extensible — Système de Plugins

La plateforme plugin fonctionne : interface KitaPlugin, manifest YAML, sandbox avec 3 niveaux de confiance, chargement dynamique.

### Story 5.1 : PluginManifest — Parsing et validation YAML

As a **développeur de plugin**,
I want **déclarer les permissions et capabilities de mon plugin dans un manifest YAML**,
So that **Kita sait quels capteurs et services mon plugin utilise et peut enforcer les permissions**.

**Acceptance Criteria:**

**Given** l'interface `PluginManifest` existe (Epic 1)
**When** le `PluginLoader` et le parsing YAML sont implémentés
**Then** `PluginLoader.loadManifest(yamlPath)` parse un fichier `plugin.kita.yaml` et retourne un `PluginManifest`
**And** le manifest contient : id (reverse domain), nom, version, permissions (camera, micro, etc.), capabilities IA (vision, text, etc.), profils compatibles, niveau de confiance
**And** un manifest invalide retourne `Result.failure` avec un message explicatif
**And** les tests unitaires vérifient le parsing de manifests valides et invalides

### Story 5.2 : PluginSandbox — Isolation et enforcement des permissions

As a **système Kita**,
I want **isoler chaque plugin et enforcer les permissions déclarées dans son manifest**,
So that **un plugin malveillant ne peut pas accéder à des capteurs ou données non autorisés**.

**Acceptance Criteria:**

**Given** le `PluginManifest` est parsable (Story 5.1)
**When** le `PluginSandboxImpl` est implémenté
**Then** `SensorAccess` proxy donne accès uniquement aux capteurs déclarés dans le manifest
**And** `AIAccess` proxy route les requêtes IA du plugin via l'AIRouter avec un quota
**And** `MemoryAccess` proxy donne accès uniquement au namespace `plugin_data` du plugin (par plugin_id)
**And** un plugin `non vérifié` n'a PAS accès à `MemoryAccess`
**And** un plugin `communautaire vérifié` a accès à `MemoryAccess` sandboxé
**And** un plugin `officiel` a accès à la mémoire partagée
**And** les tentatives d'accès non autorisé retournent `Result.failure(PermissionFailure)` et sont loggées
**And** le `PluginQuotaManager` enforce les quotas de requêtes IA par plugin
**And** les tests vérifient l'enforcement pour chaque niveau de confiance

### Story 5.3 : PluginRegistry — Enregistrement et lifecycle

As a **système Kita**,
I want **enregistrer, activer et désactiver les plugins dynamiquement**,
So that **les plugins peuvent être chargés et déchargés sans redémarrer l'application**.

**Acceptance Criteria:**

**Given** le `PluginSandbox` fonctionne (Story 5.2)
**When** le `PluginRegistry` est implémenté
**Then** `register(plugin)` enregistre un plugin avec son manifest validé
**And** `activate(pluginId)` appelle `onActivate()` du plugin et le rend disponible
**And** `deactivate(pluginId)` appelle `onDeactivate()`, libère les ressources et retire le plugin
**And** `getPlugin(pluginId)` retourne le plugin actif ou null
**And** `listPlugins()` retourne la liste des plugins avec leur état (registered/active/inactive)
**And** les voice commands des plugins actifs sont agrégées et disponibles
**And** un crash dans un plugin n'affecte PAS les autres plugins ni le shell
**And** le registry est injectable via Riverpod (`pluginRegistryServiceProvider`)
**And** les tests vérifient le lifecycle complet (register → activate → use → deactivate)

---

## Epic 6 : Marie voit — Plugin Describe

Marie dit "décris" et reçoit une description vocale précise en < 5 secondes. Le Premier Moment Magique.

### Story 6.1 : KitaDescribePlugin — Photo vers description vocale

As a **utilisateur aveugle (Marie)**,
I want **dire "décris" et recevoir une description vocale de ce qui m'entoure en < 5 secondes**,
So that **je peux savoir ce qu'il y a devant moi sans aide extérieure**.

**Acceptance Criteria:**

**Given** l'AIRouter, le CameraService et le TTSService fonctionnent (Epics 2, 3) et le PluginRegistry est prêt (Epic 5)
**When** `KitaDescribePlugin` est implémenté
**Then** le plugin est enregistré avec le manifest `plugin.kita.yaml` (permissions: camera, capabilities: vision)
**And** sur commande "décris", le plugin capture une photo via `SensorAccess.capturePhoto()`
**And** l'image est strippée des métadonnées EXIF via `ExifStripper`
**And** l'image est envoyée au provider IA cloud via `AIAccess.vision(image, prompt)`
**And** la description vocale est lue via TTS
**And** le temps total capture → voix est < 5 secondes
**And** les tests vérifient le flow complet avec des mocks

### Story 6.2 : Describe Viewport et enchainement naturel

As a **utilisateur de Kita**,
I want **voir la photo et sa description dans le viewport, et pouvoir enchainer avec "plus de détails"**,
So that **l'interaction est fluide et je peux approfondir si besoin**.

**Acceptance Criteria:**

**Given** `KitaDescribePlugin` capture et décrit (Story 6.1)
**When** le viewport et l'enchainement sont implémentés
**Then** `buildViewport()` affiche la photo en haut et la description en texte en dessous
**And** l'enchainement "plus de détails" envoie la même image avec un prompt enrichi et affiche la réponse détaillée
**And** "répète" relit la dernière description en TTS
**And** "merci" ou silence 5s retourne au mode passif
**And** en cas de fallback hors-ligne, le plugin utilise l'OCR local (ML Kit) et annonce "Mode local, la description est simplifiée"
**And** le viewport est accessible (Semantics label sur l'image, texte lisible par VoiceOver)
**And** les contrastes du viewport respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient l'enchainement et le fallback

---

## Epic 7 : Marie est protégée — Plugin Alert

Kita détecte les obstacles via IA locale et alerte Marie en < 50ms. 100% local, zéro dépendance cloud.

### Story 7.1 : ObstacleDetector — Détection TFLite/YOLO

As a **système Kita**,
I want **détecter les obstacles en temps réel via un modèle TFLite/YOLO embarqué**,
So that **les alertes sont générées en < 50ms sans aucune dépendance réseau**.

**Acceptance Criteria:**

**Given** le `CameraService` fournit un flux vidéo (Epic 3) et le modèle `yolo_v8_nano.tflite` est dans `assets/models/`
**When** `ObstacleDetector` est implémenté
**Then** le détecteur analyse chaque frame du flux caméra via TFLite
**And** les objets détectés incluent : type (voiture, trottoir, poteau, trou, personne), distance estimée, confiance (0-100%)
**And** seuls les objets avec confiance > 80% sont remontés comme obstacles
**And** la latence de détection est < 50ms par frame
**And** le traitement est 100% local — jamais de requête réseau
**And** le détecteur fonctionne sur un Isolate dédié pour ne pas bloquer le thread UI
**And** les tests vérifient la latence et le seuil de confiance

### Story 7.2 : KitaAlertPlugin — Alertes multi-modales

As a **utilisateur aveugle (Marie)**,
I want **être alertée d'un obstacle par la voix et la vibration, avec une urgence différenciée**,
So that **je peux éviter les dangers en toute sécurité**.

**Acceptance Criteria:**

**Given** l'`ObstacleDetector` détecte des obstacles (Story 7.1) et le PluginRegistry est prêt (Epic 5)
**When** `KitaAlertPlugin` est implémenté
**Then** le plugin s'enregistre avec le manifest (permissions: camera, trust: officiel)
**And** une détection d'urgence `immediate` (obstacle < 3m) déclenche : vibration danger x3 + voix "Attention ! [type] à [distance] mètres"
**And** une détection `preventive` (obstacle 3-10m) déclenche : vibration warning x1 + voix "[type] à [distance] mètres"
**And** le `buildViewport()` affiche une alerte plein viewport avec fond rouge/orange, icône grande, message gros texte
**And** l'alerte disparaît après 5s ou "OK" vocal
**And** Marie peut demander "C'est quoi ?" pour une description détaillée de l'obstacle
**And** le Semantics est configuré avec `liveRegion: true` pour l'annonce automatique par VoiceOver
**And** les contrastes du viewport alerte respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets (bouton "OK") font >= 56x56px
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient les deux niveaux d'urgence et le retour au mode passif

### Story 7.3 : Integration Gate Phase 3

As a **équipe de développement**,
I want **valider que les plugins Describe et Alert fonctionnent de bout en bout avant de lancer Phase 4**,
So that **l'onboarding peut s'appuyer sur des plugins testés et fiables**.

**Acceptance Criteria:**

**Given** les Epics 6 et 7 sont mergés sur `develop` (qui contient déjà la Phase 2)
**When** les tests d'intégration E2E sont exécutés
**Then** test flow Describe : commande "décris" → capture photo → ExifStripper → AIAccess.vision (mock) → TTS → réponse vocale < 5s
**And** test flow Alert : flux caméra → ObstacleDetector (modèle TFLite) → classification urgence → alerte multi-modale (voix + haptique)
**And** test fallback Describe : même flow en mode hors-ligne → OCR local → annonce "Mode local, description simplifiée"
**And** test enchainement : "décris" → réponse → "plus de détails" → réponse enrichie → "merci" → retour passif
**And** les deux plugins se chargent et se déchargent sans crash du shell

---

## Epic 8 : Kita prend vie — Shell Living Aura

L'interface Living Aura : orbe animée teal/violet, shell avec viewport plugin, input vocal/texte, ProfileAdapter multi-modal, design system complet.

### Story 8.1 : KitaOrb — Widget animé signature

As a **utilisateur de Kita**,
I want **voir une orbe animée teal/violet qui représente l'état de Kita en temps réel**,
So that **je sais visuellement si Kita est prête, écoute, traite, ou rencontre un problème**.

**Acceptance Criteria:**

**Given** les design tokens Mix existent (Epic 1)
**When** `KitaOrb` est implémenté
**Then** l'orbe est rendue via `CustomPainter` avec gradient teal/violet et particules
**And** les 6 états sont visuellement distincts : `passive` (ondulation lente), `listening` (pulsation), `processing` (flux accéléré), `responding` (expansion verte), `error` (rouge pulse), `offline` (gris-teal ralenti)
**And** l'orbe a 2 tailles : `large` (mode passif, centre) et `small` (mode actif, en haut)
**And** l'animation tourne à 60fps via `AnimationController`
**And** `prefers-reduced-motion` est respecté — transitions instantanées sans animation
**And** `Semantics(label: "Kita est [état]")` est configuré pour VoiceOver
**And** les contrastes de l'orbe respectent >= 3:1 contre le background
**And** les tests vérifient les 6 états et le label Semantics

### Story 8.2 : KitaShell — Scaffold principal Living Aura

As a **utilisateur de Kita**,
I want **un écran principal avec l'orbe en haut, le contenu plugin au centre, et l'input en bas**,
So that **l'interface est claire, constante et immédiatement compréhensible**.

**Acceptance Criteria:**

**Given** `KitaOrb` existe (Story 8.1)
**When** `KitaShell` est implémenté
**Then** le layout comporte 3 zones : header (status + orbe), viewport central (contenu plugin), input (voix/texte) en bas
**And** en mode passif : l'orbe est `large` au centre, le viewport est réduit
**And** en mode actif : l'orbe passe à `small` en haut (300ms), le viewport se déploie (300ms)
**And** la transition passif → actif est animée (orbe shrink + viewport slide-up)
**And** la transition actif → passif s'effectue après 5s de silence ou "merci"
**And** le focus order VoiceOver est : Input → Viewport → Header
**And** `KitaStatusIndicator` affiche l'état connexion/batterie/mode dans le header
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient les transitions d'état et le focus order

### Story 8.3 : KitaInput — Zone d'input unifiée voix/texte

As a **utilisateur de Kita**,
I want **une zone d'input qui combine saisie texte et bouton micro**,
So that **je peux interagir avec Kita par voix ou par texte selon ma préférence**.

**Acceptance Criteria:**

**Given** le `KitaShell` existe (Story 8.2)
**When** `KitaInput` est implémenté
**Then** le widget affiche un champ texte avec un bouton micro (56x56px)
**And** les 4 états fonctionnent : `idle` (placeholder "Parle ou écris à Kita"), `listening` (micro actif, onde visuelle), `typing` (clavier ouvert), `disabled` (pendant traitement)
**And** en mode `listening`, la transcription STT apparaît en temps réel dans le champ
**And** l'envoi se fait par pression Entrée (texte) ou détection de silence (voix)
**And** l'interface textuelle est une alternative COMPLÈTE à l'interface vocale
**And** `Semantics(label: "Parle ou écris à Kita")` est configuré
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient les 4 états et les deux modes d'input

### Story 8.4 : PluginViewport et KitaFeedbackBubble

As a **plugin Kita**,
I want **afficher mon contenu dans une zone sandbox au centre du shell et voir les réponses de Kita**,
So that **mon UI est visible sans casser le shell ni l'accessibilité**.

**Acceptance Criteria:**

**Given** le `KitaShell` existe (Story 8.2)
**When** `PluginViewport` et `KitaFeedbackBubble` sont implémentés
**Then** `PluginViewport` est un container scrollable qui affiche le widget du plugin actif
**And** le viewport est un sandbox visuel : pas d'accès au header/input, pas d'overlay hors zone
**And** si le plugin n'a pas de viewport custom, un texte brut de la réponse est affiché
**And** le viewport est une live region (Semantics) pour VoiceOver
**And** `KitaFeedbackBubble` affiche les réponses avec avatar Kita, contenu et timestamp (variants: text, image, rich)
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient le rendu des deux composants et l'accessibilité

### Story 8.5 : KitaAlert et KitaPermissionCard

As a **utilisateur de Kita**,
I want **voir des alertes critiques plein viewport et des demandes de permission avec storytelling contextuel**,
So that **les situations d'urgence sont immédiatement visibles et je comprends pourquoi chaque permission est demandée**.

**Acceptance Criteria:**

**Given** le `PluginViewport` existe (Story 8.4)
**When** `KitaAlert` et `KitaPermissionCard` sont implémentés
**Then** `KitaAlert` prend tout le viewport pour les alertes critiques (fond rouge/orange, message gros texte)
**And** `KitaAlert` est une live region (Semantics) annoncée automatiquement par VoiceOver
**And** `KitaPermissionCard` affiche les demandes de permission avec storytelling contextuel (4 états : asking, granted, denied, re-asking)
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets font >= 48x48px (56x56px pour actions critiques)
**And** le Semantics test matcher vérifie la présence des labels sur tous les éléments interactifs
**And** les tests vérifient le rendu des deux composants et l'accessibilité

### Story 8.6 : ProfileAdapter — Routage multi-modal

As a **système Kita**,
I want **router chaque output vers les bonnes modalités selon le profil actif de l'utilisateur**,
So that **Marie (aveugle) reçoit de la voix et de l'haptique, et les voyants reçoivent aussi du visuel**.

**Acceptance Criteria:**

**Given** les services TTS et Haptic fonctionnent (Epic 3)
**When** `ProfileAdapter` est pleinement implémenté
**Then** `adapter.feedback(visual, vocal, haptic)` exécute les callbacks adaptés au profil actif
**And** profil `aveugle` : vocal = ON, haptic = fort, visual = minimal (VoiceOver gère)
**And** profil `sourd` : vocal = OFF, haptic = fort, visual = primaire
**And** profil `standard` : vocal = secondaire, haptic = moyen, visual = complet
**And** profil `aidant` : vocal = OFF, haptic = léger, visual = complet + dashboard
**And** le profil actif est lu depuis Riverpod (`userProfileProvider`)
**And** les annonces vocales de changement d'état (perte connexion, batterie < 20%, mode dégradé) passent par le ProfileAdapter
**And** les tests vérifient le routage pour chaque profil

---

## Epic 9 : Kita accueille — Onboarding Marie

Marie complète l'onboarding en < 3 minutes. Sophie peut configurer pour un tiers.

### Story 9.1 : Détection accessibilité et adaptation automatique

As a **utilisateur de Kita**,
I want **que Kita détecte automatiquement VoiceOver/TalkBack et adapte l'expérience immédiatement**,
So that **je n'ai rien à configurer manuellement pour que l'app soit accessible**.

**Acceptance Criteria:**

**Given** le platform channel `com.kita/accessibility` existe (Epic 1)
**When** `ProfileDetectionImpl` est implémenté
**Then** la détection VoiceOver (iOS) et TalkBack (Android) se fait au lancement de l'app, AVANT le premier écran
**And** si VoiceOver/TalkBack est actif, le profil `aveugle` est pré-sélectionné
**And** si `textScaleFactor > 1.3`, le profil `basse vision` est pré-sélectionné
**And** la détection est transparente — l'utilisateur ne voit rien, l'app s'adapte
**And** le code natif Swift (`AccessibilityChannel.swift`) détecte VoiceOver via `UIAccessibility.isVoiceOverRunning`
**And** le code natif Kotlin (`AccessibilityChannel.kt`) détecte TalkBack via `AccessibilityManager`
**And** les tests vérifient la pré-sélection pour chaque détection

### Story 9.2 : Onboarding vocal-first — Flow principal

As a **utilisateur aveugle (Marie)**,
I want **que Kita me guide vocalement à travers l'onboarding en < 3 minutes**,
So that **je peux configurer l'app sans voir l'écran et sans aide extérieure**.

**Acceptance Criteria:**

**Given** la détection accessibilité fonctionne (Story 9.1) et le KitaShell existe (Epic 8)
**When** le flow d'onboarding est implémenté
**Then** si VoiceOver/TalkBack est actif, Kita parle EN PREMIER : "Bonjour, je suis Kita. Je suis là pour t'aider."
**And** Kita demande vocalement le prénom de l'utilisateur
**And** l'utilisateur sélectionne son profil (aveugle, malvoyant, sourd, général) — vocalement ou par touch
**And** le pack profil correspondant est auto-installé (Describe + Alert pour aveugle)
**And** le flow complet est navigable en vocal uniquement (100%)
**And** le flow complet est < 3 minutes (mesuré)
**And** chaque widget interactif a un `Semantics` wrapper avec label descriptif
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets font >= 48x48px (56x56px pour actions critiques)
**And** le Semantics test matcher vérifie la présence des labels
**And** les tests vérifient le flow complet avec simulation VoiceOver

### Story 9.3 : Permission Storytelling

As a **utilisateur de Kita**,
I want **que chaque permission soit expliquée dans son contexte d'usage avant d'être demandée**,
So that **je comprends pourquoi Kita a besoin de ma caméra et de mon micro**.

**Acceptance Criteria:**

**Given** le flow d'onboarding est en cours (Story 9.2) et `KitaPermissionCard` existe (Epic 8)
**When** les demandes de permission sont implémentées
**Then** la caméra est demandée avec : "Pour décrire ce qui t'entoure, j'ai besoin de ta caméra"
**And** le micro est demandé avec : "Pour t'écouter, j'ai besoin du micro"
**And** l'ordre des permissions est adapté au profil (aveugle → caméra d'abord)
**And** chaque permission refusée est reproposée UNE fois avec une explication complémentaire
**And** après 2 refus, Kita accepte et continue sans la permission
**And** les permissions sont demandées via l'API native (pas de permission manuelle)
**And** chaque widget interactif a un `Semantics` wrapper avec label descriptif
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets font >= 48x48px (56x56px pour actions critiques)
**And** le Semantics test matcher vérifie la présence des labels
**And** les tests vérifient les cas : acceptée, refusée une fois puis acceptée, refusée deux fois

### Story 9.4 : Premier Moment Magique et configuration providers

As a **utilisateur de Kita**,
I want **vivre mon Premier Moment Magique ("décris" → description vocale) à la fin de l'onboarding et configurer mes providers IA**,
So that **je suis convaincu que Kita fonctionne et prêt à l'utiliser au quotidien**.

**Acceptance Criteria:**

**Given** les permissions sont accordées et le pack est installé (Stories 9.2, 9.3) et le Plugin Describe fonctionne (Epic 6)
**When** la fin de l'onboarding est implémentée
**Then** Kita dit : "On essaie ? Dis-moi 'décris' et pointe ton téléphone vers quelque chose."
**And** l'utilisateur dit "décris" et reçoit une description vocale < 5s
**And** Kita dit : "Je suis prête. Dis-moi ce dont tu as besoin."
**And** le mode découverte gratuit est proposé par défaut (crédits limités)
**And** le mode BYOK permet d'entrer ses clés API (écran `api_key_setup.dart`)
**And** les clés API sont validées via `AIProvider.validateApiKey()` et stockées dans Keychain/Keystore
**And** l'onboarding se termine et le mode passif s'active
**And** chaque widget interactif a un `Semantics` wrapper avec label descriptif
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets font >= 48x48px (56x56px pour actions critiques)
**And** le Semantics test matcher vérifie la présence des labels
**And** les tests vérifient le flow complet incluant le Premier Moment Magique

### Story 9.5 : Mode aidant — Sophie configure pour Marie

As a **aidant (Sophie)**,
I want **installer et configurer Kita pour un tiers (ma mère Marie)**,
So that **Marie peut utiliser Kita sans avoir à faire l'onboarding elle-même**.

**Acceptance Criteria:**

**Given** le flow d'onboarding standard fonctionne (Stories 9.1-9.4)
**When** le mode aidant est implémenté
**Then** à l'onboarding, le choix "Pour moi" ou "Pour quelqu'un d'autre" est proposé
**And** en mode "pour quelqu'un d'autre", Sophie sélectionne le profil de l'utilisateur cible (aveugle, sourd, etc.)
**And** les permissions sont groupées (pas une par une — Sophie accorde tout en une fois)
**And** un test guidé est proposé : "Dites DÉCRIS pour vérifier que tout fonctionne"
**And** le nom de l'utilisateur cible est configuré (ex: "Marie")
**And** au prochain lancement, Kita accueille Marie par son nom : "Bonjour Marie !" → mode passif direct (pas de re-onboarding)
**And** chaque widget interactif a un `Semantics` wrapper avec label descriptif
**And** les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (éléments UI)
**And** les touch targets font >= 48x48px (56x56px pour actions critiques)
**And** le Semantics test matcher vérifie la présence des labels
**And** les tests vérifient le flow aidant complet

---

## Epic 10 : Kita veille — Mode Passif & Background

Kita reste active en arrière-plan avec gestion intelligente de la batterie et capteurs adaptatifs.

### Story 10.1 : Background Service — Android Foreground Service

As a **utilisateur de Kita sur Android**,
I want **que Kita reste active en arrière-plan sans être tuée par le système**,
So that **les alertes d'obstacles fonctionnent même quand l'app n'est pas au premier plan**.

**Acceptance Criteria:**

**Given** les services I/O fonctionnent (Epic 3) et le platform channel `com.kita/background` existe
**When** le background service Android est implémenté
**Then** `KitaForegroundService.kt` crée un Foreground Service avec notification permanente
**And** le service maintient les capteurs minimaux actifs (micro ambient, accéléromètre)
**And** la caméra et le GPS sont activés uniquement sur commande vocale ou mouvement détecté
**And** le service survit au passage en arrière-plan de l'app
**And** le `BackgroundChannel.kt` communique l'état du service au code Flutter
**And** les tests vérifient que le service reste actif après `onPause()`

### Story 10.2 : Background Service — iOS Background Audio + Location

As a **utilisateur de Kita sur iOS**,
I want **que Kita reste active en arrière-plan malgré les restrictions iOS**,
So that **les alertes fonctionnent en continu**.

**Acceptance Criteria:**

**Given** les services I/O fonctionnent (Epic 3)
**When** le background service iOS est implémenté
**Then** `BackgroundAudioService.swift` utilise Background Audio pour maintenir l'app active
**And** Location Updates en background sont configurés pour les situations de navigation
**And** `Info.plist` contient les justifications pour `UIBackgroundModes` (audio, location)
**And** le `BackgroundChannel.swift` communique l'état au code Flutter
**And** les tests vérifient la persistance du service

### Story 10.3 : Mode passif intelligent et gestion batterie

As a **utilisateur de Kita**,
I want **que le mode passif maintienne les capteurs essentiels actifs tout en préservant ma batterie (< 5%/h)**,
So that **Kita veille sur moi toute la journée sans vider ma batterie**.

**Acceptance Criteria:**

**Given** les background services fonctionnent (Stories 10.1, 10.2) et le Plugin Alert fonctionne (Epic 7)
**When** le mode passif intelligent est implémenté
**Then** les capteurs minimaux (micro ambient, accéléromètre) restent actifs en permanence
**And** la caméra s'active sur mouvement détecté (marche/course) pour la détection d'obstacles
**And** la caméra se désactive si l'utilisateur est immobile > 30s
**And** le FPS caméra s'adapte au mouvement : immobile = OFF, marche = 15 FPS, course = 30 FPS
**And** la consommation batterie en mode passif est < 5% par heure (mesurée sur appareils mid-range)
**And** une alerte vocale est déclenchée quand la batterie passe sous 20%
**And** la RAM en mode passif reste < 200 MB
**And** les tests vérifient l'adaptation du FPS et la libération des ressources

### Story 10.4 : Integration Gate Phase 4

As a **équipe de développement**,
I want **valider le parcours utilisateur complet avant la phase de qualité finale**,
So that **E11 peut se concentrer sur la CI/CD et les tests de conformité sans découvrir de régressions**.

**Acceptance Criteria:**

**Given** les Epics 9 et 10 sont mergés sur `develop` (qui contient déjà les Phases 2 et 3)
**When** les tests d'intégration du parcours complet sont exécutés
**Then** test onboarding E2E : détection VoiceOver → onboarding vocal < 3 min → permissions → pack installé → Premier Moment Magique
**And** test mode aidant : Sophie configure pour Marie → profil aveugle → plugins installés → test guidé → relancement avec accueil personnalisé
**And** test mode passif stable : mode passif actif pendant 1h → 0 crash, 0 memory leak, RAM < 200 MB
**And** test cycle complet Marie : onboarding → "décris" → description → marche → alerte obstacle → "stop" → mode passif
**And** test fallback hors-ligne : coupure réseau → annonce vocale → mode dégradé → retour connexion → annonce retour

---

## Epic 11 : Prêt pour le monde — Qualité & Déploiement

Pipeline CI/CD complet, couverture tests > 80%, tests a11y bloquants, Fastlane stores. Kita est prête pour la beta.

### Story 11.1 : Pipeline CI/CD complet

As a **développeur**,
I want **un pipeline CI/CD qui teste, lintte, vérifie l'accessibilité et build automatiquement**,
So that **chaque PR est validée automatiquement et les releases sont fiables**.

**Acceptance Criteria:**

**Given** le CI stub existe (Epic 1 Story 1.8)
**When** le pipeline CI/CD complet est implémenté
**Then** `.github/workflows/ci.yml` exécute séquentiellement : `dart analyze`, `flutter test --coverage`, vérification couverture > 80%, tests a11y (Semantics matchers)
**And** `.github/workflows/build-android.yml` build l'APK et l'AAB en release
**And** `.github/workflows/build-ios.yml` build l'IPA en release
**And** les tests d'accessibilité sont BLOQUANTS — une PR sans Semantics ne passe pas
**And** les flavors dev/staging/prod sont supportés dans les builds
**And** les tests vérifient que le pipeline s'exécute correctement

### Story 11.2 : Tests d'intégration journeys

As a **équipe qualité**,
I want **des tests d'intégration couvrant les 4 user journeys critiques**,
So that **les parcours utilisateurs clés sont validés de bout en bout**.

**Acceptance Criteria:**

**Given** tous les epics fonctionnels sont complets (E1-E10)
**When** les tests d'intégration sont implémentés
**Then** `integration_test/onboarding_flow_test.dart` vérifie le journey onboarding complet (< 3 min)
**And** `integration_test/describe_journey_test.dart` vérifie "décris" → description vocale < 5s
**And** `integration_test/alert_journey_test.dart` vérifie la détection d'obstacle → alerte < 50ms
**And** `integration_test/forget_journey_test.dart` vérifie "forget everything" → 0 donnée résiduelle
**And** les tests utilisent `integration_test/helpers/test_app.dart` avec des mocks de providers IA
**And** les tests vérifient aussi le fallback hors-ligne

### Story 11.3 : Déploiement stores et conformité

As a **responsable produit (Charles)**,
I want **Fastlane configuré pour déployer sur les stores et la conformité vérifiée**,
So that **Kita est prête pour la beta fermée sur App Store et Play Store**.

**Acceptance Criteria:**

**Given** les builds fonctionnent en CI (Story 11.1)
**When** le déploiement stores est configuré
**Then** `fastlane/Fastfile` contient les lanes : `beta_android` (Play Store internal), `beta_ios` (TestFlight)
**And** les justifications de permissions sont rédigées pour Apple (caméra, micro, localisation)
**And** la politique de confidentialité RGPD est liée
**And** la data safety section Google Play est complète (local-first, chiffrement)
**And** le versioning suit le pattern `v{major}.{minor}.{patch}` via tags git
**And** un `CONTRIBUTING.md` guide les futurs contributeurs open source
