---
stepsCompleted: [1, 2, 3, 4, 5, 6]
workflow_completed: true
inputDocuments:
  - brainstorming-session-2026-02-19.md
  - kita-architecture-party-mode-2026-02-19.md
date: 2026-02-19
author: Charles
---

# Product Brief: Kita

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

Kita est un assistant IA mobile open source, modulaire et extensible, qui utilise les ressources du telephone (camera, microphone, GPS, capteurs de mouvement) pour aider les utilisateurs dans leur quotidien. Inspire par la philosophie d'OpenClaw — un agent IA autonome, multi-provider et extensible — Kita transpose ce concept sur mobile en exploitant les capteurs du telephone comme super-pouvoir et en placant l'accessibilite au coeur de sa mission.

L'application fonctionne via une interface vocale et textuelle propre, avec un systeme de plugins modulaires permettant a la communaute d'etendre ses capacites. Des packs de plugins pre-configures simplifient l'experience pour les personnes en situation de handicap (aveugles, sourds, muets, autistes) tout en restant utile a tous.

Le MVP se concentre sur le profil aveugle avec un plugin de description photo vocale, demontrant la puissance de l'architecture hybride IA locale/cloud.

---

## Core Vision

### Problem Statement

Les personnes en situation de handicap doivent aujourd'hui jongler avec 5 a 10 applications isolees pour couvrir leurs besoins quotidiens (Be My Eyes pour la description visuelle, Seeing AI pour la lecture, Ava pour les sous-titres, Braci pour les alertes sonores...). Aucune de ces applications ne communique entre elles, aucune ne retient les preferences de l'utilisateur, et chacune est verrouillee sur un seul provider IA.

Plus largement, l'IA a le potentiel d'apporter des ressources utiles a enormement de personnes dans leur quotidien, mais il n'existe pas encore de plateforme mobile ouverte et modulaire qui permette d'exploiter pleinement les capteurs du telephone avec l'intelligence artificielle.

### Problem Impact

- **Perte d'autonomie** — Dependance envers l'entourage pour des taches simples
- **Fragmentation** — Multiplier les apps = complexite, bugs, apprentissages multiples
- **Pas de memoire** — Chaque app repart de zero, aucune ne connait l'utilisateur
- **Vendor lock-in** — Chaque app impose son provider IA sans choix
- **Entourage impacte** — Les proches sont sollicites en permanence pour compenser

### Why Existing Solutions Fall Short

- **Be My Eyes** — Excellent pour la description visuelle mais limite a un seul cas d'usage, dependent de GPT-4, pas de memoire utilisateur
- **Seeing AI** — Gratuit et performant en OCR mais iOS uniquement, pas extensible, pas de plugins
- **Ava / Live Transcribe** — Transcription uniquement, pas d'analyse emotionnelle, pas de profils vocaux
- **Goblin Tools / Autimo** — Outils isoles pour autistes, pas integres dans un ecosysteme

Aucune solution ne propose : plateforme unifiee + plugins communautaires + multi-provider IA + memoire locale chiffree + interface vocale/textuelle.

### Proposed Solution

Kita est une plateforme mobile open source qui fonctionne comme un agent IA autonome sur telephone. Inspire par OpenClaw (agent IA desktop open source), Kita exploite les capteurs du telephone (camera, microphone, GPS, accelerometre) comme les "sens" de l'agent, et une architecture multi-provider IA (Claude, OpenAI, Gemini, modeles locaux) comme son "cerveau".

L'architecture modulaire par plugins permet a la communaute de developper et partager des fonctionnalites. Des packs pre-configures par profil d'accessibilite simplifient la prise en main. Une memoire locale chiffree (Isar, AES-256) assure la personnalisation tout en garantissant la vie privee.

### Key Differentiators

1. **Plateforme unifiee vs apps fragmentees** — Un seul ecosysteme au lieu de 10 apps isolees
2. **Plugins modulaires + open source** — Extensibilite infinie par la communaute, inspire des AgentSkills d'OpenClaw
3. **Multi-provider IA sans lock-in** — L'utilisateur choisit son IA (Claude, GPT, Gemini, local), bascule possible a tout moment
4. **IA hybride locale/cloud** — Reactivite en temps reel (<50ms) pour les situations critiques, puissance cloud pour l'analyse complexe
5. **Memoire locale chiffree** — Kita connait l'utilisateur et s'ameliore dans le temps, contrairement aux apps qui repartent de zero
6. **Voice-first avec interface propre** — Pas de dependance a une plateforme de messagerie externe
7. **Accessibilite comme mission, pas comme feature** — Packs par profil, onboarding adaptatif, design universel

---

## Target Users

### Primary Users

#### Persona 1 : Marie — Aveugle (MVP)
- **Profil :** 34 ans, professeure de musique, aveugle de naissance
- **Contexte :** Autonome mais confrontee quotidiennement a des situations ou elle depend de son entourage ou d'apps fragmentees (Be My Eyes, Seeing AI, GPS classique)
- **Frustrations :** Jongler entre 5-6 apps qui ne se parlent pas, aucune ne la connait, doit tout reexpliquer a chaque fois
- **Objectif :** Autonomie totale dans son quotidien — deplacements, courses, courrier, rendez-vous medicaux — sans solliciter ses proches
- **Usage Kita :** Kita reste actif en permanence en mode passif (ecoute ambiante, capteurs en veille intelligente). Marie interagit vocalement a la demande ("decris", "lis ca", "guide-moi"). En deplacement, Kita active la camera en mode adaptatif et alerte proactivement sur les dangers.
- **Moment "wow" :** A l'onboarding, Marie dit "decris" et Kita lui decrit l'objet devant elle en moins de 5 secondes avec une voix naturelle.

#### Persona 2 : Karim — Sourd
- **Profil :** 22 ans, etudiant en informatique, sourd de naissance
- **Contexte :** Communique en LSF avec ses proches, mais galere dans les interactions avec les entendants (cours, commerces, soirees)
- **Frustrations :** Les apps de transcription sont basiques — pas d'identification des locuteurs, pas d'indication du ton ou de l'emotion, pas de memoire
- **Objectif :** Suivre les conversations de groupe en temps reel avec identification des locuteurs et indices emotionnels
- **Usage Kita :** Kita transcrit en permanence les sons ambiants et alerte sur les sons importants (alarme, klaxon). En conversation, mode "Discord IRL" avec affichage par locuteur.
- **Moment "wow" :** Karim active Kita en soiree et voit la conversation s'afficher comme un channel Discord avec le nom de chaque personne et des indicateurs d'emotion.

#### Persona 3 : Lea — Autiste
- **Profil :** 8 ans, passionnee de dinosaures, diagnostiquee TSA
- **Contexte :** Difficultes avec les interactions sociales, surcharges sensorielles frequentes, incomprehension des sous-entendus et du second degre
- **Frustrations :** Se sent perdue dans les situations sociales, ne comprend pas pourquoi les autres rient, crises sensorielles sans outil de regulation
- **Objectif :** Decoder les situations sociales et disposer d'un outil de regulation emotionnelle accessible
- **Usage Kita :** Kita fonctionne comme un compagnon permanent qui traduit les emotions via ses passions (dinosaures), propose des scripts sociaux adaptes, et active la bulle sensorielle en cas de surcharge. Protocole d'escalade SOS si besoin.
- **Moment "wow" :** Lea ne comprend pas pourquoi ses camarades rient. Kita lui explique la blague en la comparant a un comportement de velociraptor.

#### Persona 4 : Thomas — Utilisateur lambda
- **Profil :** 40 ans, cadre, aucun handicap
- **Contexte :** Cherche un assistant IA mobile polyvalent qui exploite les capteurs de son telephone
- **Frustrations :** Les assistants vocaux classiques (Siri, Google Assistant) sont limites et fermes, pas extensibles
- **Objectif :** Un assistant IA ouvert, personnalisable, qui apprend ses habitudes
- **Usage Kita :** Scanner des documents, identifier des plantes, coach sportif, routines automatisees, secretaire de reunion. Installe des plugins selon ses besoins.
- **Moment "wow" :** Thomas pointe sa camera vers un plat au restaurant et Kita identifie les ingredients, verifie ses allergies connues, et suggere un vin.

### Secondary Users

- **Aidants familiaux** — Parents de Lea, famille de Marie. Beneficient directement de l'autonomie gagnee par l'utilisateur principal. Peuvent installer Kita pour un proche (option "j'installe pour quelqu'un d'autre" dans l'onboarding) et recevoir les notifications d'urgence (protocole d'escalade SOS).
- **Institutions** — Hopitaux, ecoles, EHPAD. Deploiement de Kita Enterprise avec packs de plugins adaptes a leur population. Reduction de la charge des aidants professionnels.
- **Developpeurs** — Communaute open source qui cree et maintient des plugins. Beneficient du SDK et du marketplace (commission 20%).

### User Journey

```
DECOUVERTE           ONBOARDING              USAGE QUOTIDIEN         FIDELISATION
Bouche-a-oreille     3 min, vocal-first      Kita toujours actif     Memoire qui
Associations         Detection auto du       Mode passif par         s'enrichit,
Influenceurs         profil accessibilite    defaut, activation      plugins
App Store            Permissions guidees     vocale a la demande     communautaires,
                     Premier Moment          Alertes proactives      profil evolutif
                     Magique                 Plugins contextuels     auto-apprenant
```

**Parcours Marie :**
1. **Decouverte** — Son association recommande Kita comme alternative unifiee a ses 5 apps
2. **Onboarding** — Kita detecte VoiceOver, parle immediatement, installe le pack aveugle
3. **Premier wow** — "Decris" → description vocale instantanee de l'objet devant elle
4. **Quotidien** — Kita toujours actif : briefing matinal, navigation, lecture de courrier, description a la demande
5. **Fidelisation** — Kita connait ses habitudes, anticipe ses besoins, elle n'a plus besoin de ses 5 anciennes apps

---

## Success Metrics

### User Success Metrics

- **Usage quotidien** — % d'utilisateurs actifs qui utilisent Kita chaque jour (DAU/MAU)
  - Cible MVP : 60%+ de DAU/MAU (signe d'un produit indispensable)
- **Retention J7 / J30** — % d'utilisateurs qui reviennent apres 7 et 30 jours
  - Cible MVP : 50% J7, 30% J30
- **Desinstallation d'apps concurrentes** — Indicateur qualitatif : Marie n'a plus besoin de Be My Eyes + Seeing AI + GPS separement
- **Feedback positif** — Temoignages utilisateurs sur ce que Kita leur apporte concretement (autonomie gagnee, reduction de la dependance envers l'entourage)
- **Temps de reponse du Premier Moment Magique** — Description photo vocale < 5 secondes a l'onboarding

### Business Objectives

- **A 3 mois (MVP)** — Valider le concept avec une base d'utilisateurs beta, collecter du feedback qualitatif, demontrer la viabilite technique
- **A 12 mois** — Communaute active, premiers utilisateurs payants Kita Cloud, interet d'institutions (hopitaux, ecoles, EHPAD) pour Kita Enterprise
- **Modele economique** — Pas la priorite au MVP. Le business model (Kita Cloud 5€/mois, Enterprise, Marketplace) sera active une fois la communaute etablie

### Key Performance Indicators

**Communaute & Open Source (priorite haute) :**
- Stars GitHub sur le repo Kita
- Nombre de contributeurs actifs (PRs mergees / mois)
- Nombre de plugins communautaires publies
- Nombre de forks actifs

**Utilisateurs (priorite haute) :**
- DAU / MAU (cible 60%+)
- Retention J7 (cible 50%) et J30 (cible 30%)
- NPS (Net Promoter Score) via feedback in-app
- Nombre d'installations depuis les stores

**Technique (priorite MVP) :**
- Temps de reponse description photo < 5s
- 0 crash sur les flows critiques
- Fallback critique jamais en echec
- Couverture de tests > 80%

---

## MVP Scope

### Core Features

**Infrastructure (Couche 1-3) :**
- AI Router multi-provider (Claude, OpenAI, Gemini) avec fallback chain
- IA locale (ML Kit / CoreML) pour les reponses critiques < 50ms
- RequestClassifier (critical / urgent / standard / background)
- STT local + TTS local (voix naturelle)
- Camera service (capture unique pour le MVP)
- Memoire chiffree Isar (AES-256) avec profil utilisateur
- MemoryVault (consentement, droit a l'oubli, transparence)

**Plugins MVP (Couche 5) :**
- **Plugin Describe** — Photo → description vocale < 5s (cloud IA)
- **Plugin Alert** — Detection d'obstacles en temps reel (IA locale)

**Experience utilisateur :**
- Onboarding complet en < 3 minutes, vocal-first
- Detection automatique du profil d'accessibilite (VoiceOver/TalkBack)
- Pack aveugle pre-installe automatiquement
- Interface vocale + textuelle propre
- Kita toujours actif en mode passif, activation a la demande
- Premier Moment Magique a l'onboarding

**Architecture :**
- Flutter + modules natifs Swift/Kotlin
- Riverpod pour le state management
- Interface plugin abstraite (KitaPlugin, PluginManifest)
- PluginSandbox (permissions, quotas, isolation)
- Compatible Android 12+ et iOS 16+

### Out of Scope for MVP

- Navigation temps reel avec FPS adaptatif (v0.2)
- Multi-appareils (lunettes connectees, montre, domotique)
- Marketplace de plugins
- Kita Cloud payant (proxy API 5€/mois)
- Kita Enterprise (institutions)
- SDK developpeur et CLI (kita create/test/publish)
- Cache Manager par similarite
- Plugins communautaires et tiers
- Profils vocaux / reconnaissance de locuteurs
- Analyse emotionnelle et detection de ton
- Plugins reseaux sociaux (Facebook, WhatsApp...)
- Mode explorateur / quetes touristiques
- Bulle sensorielle et scripts sociaux (plugins Lea)
- Transcription multi-locuteurs "Discord IRL" (plugin Karim)

### MVP Success Criteria

- Onboarding complet en < 3 minutes pour un utilisateur aveugle
- Plugin Describe : photo → description vocale en < 5 secondes
- Fallback critique ne fail JAMAIS (alerte brute en dernier recours)
- 0 crash sur les flows critiques
- Couverture de tests > 80%
- Donnees chiffrees et illisibles sans cle
- "Forget everything" efface 100% des donnees
- Teste avec au moins un utilisateur aveugle reel
- DAU/MAU > 60% sur les beta testeurs

### Future Vision

**v0.2 — "Kita bouge" (3-6 mois) :**
- Navigation temps reel avec camera FPS adaptatif
- Cache Manager intelligent
- Plugins supplementaires (briefing matinal, lecteur de documents)
- SDK developpeur + CLI pour plugins communautaires

**v1.0 — "Kita pour tous" (6-12 mois) :**
- Packs pour sourds (transcription multi-locuteurs), autistes (scripts sociaux)
- Marketplace de plugins
- Kita Cloud (proxy API simplifie)
- Profils vocaux et reconnaissance de locuteurs

**v2.0+ — "L'ecosysteme Kita" (12-24 mois) :**
- Multi-appareils (lunettes connectees, montre, domotique)
- Kita Enterprise (hopitaux, ecoles, EHPAD)
- Milliers de plugins communautaires
- L'equivalent d'OpenClaw sur mobile — une plateforme ouverte ou chaque developpeur peut creer des plugins qui exploitent les capteurs du telephone avec l'IA
