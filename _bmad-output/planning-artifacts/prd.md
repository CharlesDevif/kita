---
stepsCompleted: [step-01-init, step-02-discovery, step-02b-vision, step-02c-executive-summary, step-03-success, step-04-journeys, step-05-domain, step-06-innovation, step-07-project-type, step-08-scoping, step-09-functional, step-10-nonfunctional, step-11-polish, step-12-complete]
workflow_completed: true
completion_date: '2026-02-19'
classification:
  projectType: mobile_app
  domain: general
  domainNotes: "Plateforme IA grand public avec considerations accessibilite et vie privee elevees"
  complexity: high
  complexityReasons: "Donnees sensibles (handicap), vie privee (local-first, RGPD), securite des personnes, IA hybride multi-provider, sandbox plugins"
  projectContext: greenfield
vision:
  summary: "OpenClaw mobile — agent IA autonome open source sur telephone, exploitant les capteurs comme super-pouvoir, accessibilite comme mission"
  differentiator: "Plateforme unifiee + plugins modulaires + multi-provider IA + memoire locale chiffree + voice-first — aucune solution existante ne combine tout ca"
  coreInsight: "OpenClaw a prouve le concept sur desktop, personne ne l'a fait proprement sur mobile avec les capteurs du telephone"
  deepNeed: "Autonomie et liberte — reduire la dependance envers l'entourage, simplifier le quotidien de tous via l'IA"
inputDocuments:
  - product-brief-kita-2026-02-19.md
  - brainstorming-session-2026-02-19.md
  - kita-architecture-party-mode-2026-02-19.md
workflowType: 'prd'
lastEdited: '2026-02-19'
editHistory:
  - date: '2026-02-19'
    changes: "8 corrections post-validation — 3 FRs precisees (PER-005, PER-007, COM-006), 1 FR abstrait (PLG-001), 3 NFRs reformulees (REL-005, INT-001, INT-002), 1 NFR abstrait (REL-001)"
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 2
  projectDocs: 0
  projectContext: 0
---

# Product Requirements Document - Kita

**Author:** Charles
**Date:** 2026-02-19

## Executive Summary

Kita est un agent IA mobile open source qui exploite les capteurs du telephone (camera, microphone, GPS, accelerometre) pour assister les utilisateurs dans leur quotidien. Inspire par OpenClaw (agent IA desktop autonome), Kita transpose ce concept sur mobile avec une architecture modulaire par plugins et une mission d'accessibilite.

La plateforme cible deux segments : les personnes en situation de handicap (aveugles, sourds, muets, autistes) via des packs de plugins pre-configures, et les utilisateurs grand public via un ecosysteme extensible. Le MVP se concentre sur le profil aveugle (persona Marie) avec deux plugins : description photo vocale (cloud IA) et detection d'obstacles en temps reel (IA locale).

L'interface est vocale et textuelle, propre a Kita — pas de dependance a une plateforme de messagerie externe. Kita reste actif en permanence en mode passif (ecoute ambiante, capteurs en veille intelligente) et s'active a la demande de l'utilisateur.

### What Makes This Special

1. **Plateforme unifiee** — Remplace 5-10 apps isolees par un seul ecosysteme ou les plugins communiquent entre eux et partagent une memoire commune
2. **Multi-provider IA sans lock-in** — Claude, OpenAI, Gemini, modeles locaux. L'utilisateur choisit, l'AI Router optimise
3. **IA hybride locale/cloud** — Reponses critiques < 50ms en local (obstacles, alertes), analyse complexe en cloud. Les requetes critiques ne retournent JAMAIS d'erreur
4. **Memoire locale chiffree** — Isar (AES-256), 4 domaines de memoire (working, episodic, semantic, relational). Kita connait l'utilisateur et s'ameliore. Droit a l'oubli granulaire, transparence totale
5. **Open source + plugins communautaires** — MIT license, SDK developpeur, marketplace. Inspire des AgentSkills d'OpenClaw
6. **Accessibilite comme mission** — Packs par profil, onboarding adaptatif en < 3 minutes, detection automatique VoiceOver/TalkBack, design universel

## Project Classification

- **Type :** Application mobile cross-platform (Flutter + modules natifs Swift/Kotlin)
- **Domaine :** General (plateforme IA grand public) avec considerations d'accessibilite et de vie privee elevees
- **Complexite :** Haute — donnees sensibles (handicap, preferences), vie privee critique (local-first, RGPD), securite des personnes (alertes de danger), IA hybride multi-provider, sandbox de plugins
- **Contexte :** Greenfield — nouveau produit, pas de code existant
- **Plateformes cibles :** Android 12+ et iOS 16+

## Success Criteria

### User Success

- Marie complete l'onboarding et obtient sa premiere description photo en < 3 minutes
- L'utilisateur utilise Kita quotidiennement sans revenir a ses anciennes apps
- Feedback qualitatif positif : "Kita m'a rendu plus autonome"
- Le Premier Moment Magique genere un effet "wow" mesurable (partage, recommandation)

### Business Success

- **A 3 mois :** MVP fonctionnel en beta fermee, feedback qualitatif collecte, concept valide aupres d'utilisateurs reels
- **A 6 mois :** Repo GitHub public, premiers contributeurs externes, premiers plugins communautaires
- **A 12 mois :** Communaute active (contributeurs + utilisateurs), exploration du modele Kita Cloud / Enterprise

### Technical Success

- Description photo vocale < 5 secondes bout en bout
- Fallback critique ne retourne JAMAIS d'erreur (alerte brute en dernier recours)
- 0 crash sur les flows critiques (onboarding, describe, alert)
- Donnees chiffrees AES-256 et illisibles sans cle
- "Forget everything" efface 100% des donnees recuperables
- Couverture de tests > 80%
- Compatible Android 12+ et iOS 16+

### Measurable Outcomes

| Metrique | Cible MVP | Methode |
|----------|-----------|---------|
| DAU/MAU | > 60% | Analytics in-app |
| Retention J7 | > 50% | Analytics in-app |
| Retention J30 | > 30% | Analytics in-app |
| Temps description photo | < 5s | Monitoring technique |
| Crashs flows critiques | 0 | Crash reporting |
| Couverture tests | > 80% | CI/CD |
| Stars GitHub | Croissance | GitHub API |
| Contributeurs actifs | > 0 PRs externes | GitHub API |

## Product Scope

| Phase | Perimetre | Objectif |
|-------|-----------|----------|
| **MVP** | Core engine (AI Router, fallback chain, IA locale) + Plugin Describe + Plugin Alert + onboarding vocal-first + pack aveugle | Valider le concept : description photo < 5s pour Marie |
| **Growth** | Navigation temps reel, SDK/CLI, packs sourds/autistes, marketplace, Kita Cloud | Elargir les profils et ouvrir l'ecosysteme developpeur |
| **Vision** | Multi-appareils, Kita Enterprise, milliers de plugins communautaires | L'OpenClaw mobile a part entiere |

Detail complet du decoupage et des features par phase : voir [Project Scoping & Phased Development](#project-scoping--phased-development).

## User Journeys

### Journey 1 : Marie — Premiere utilisation (Success Path)

**Opening Scene :** Marie, 34 ans, professeure de musique, rentre chez elle apres le travail. Son association lui a recommande Kita pour remplacer ses 5 apps d'accessibilite. Elle telecharge l'app depuis l'App Store.

**Rising Action :** Kita detecte que VoiceOver est actif sur son iPhone. Avant meme le premier ecran, une voix chaleureuse dit : "Bonjour, je suis Kita. Je suis la pour t'aider." Marie n'a rien a lire, rien a chercher. Kita lui demande vocalement quel profil lui correspond. Elle dit "aveugle". Kita installe automatiquement le pack aveugle. Kita explique chaque permission avant de la demander : "Pour decrire ce qui t'entoure, j'ai besoin de ta camera." Marie accepte. Kita lui propose d'essayer sa cle API ou le mode decouverte gratuit. Elle choisit le mode decouverte.

**Climax :** Kita dit : "On essaie ? Dis-moi 'decris' et pointe ton telephone vers quelque chose." Marie pointe vers sa table basse. En 4 secondes, Kita repond : "Je vois une table basse en bois clair avec une tasse blanche, un livre ouvert et une telecommande noire." Marie sourit. Pour la premiere fois, une app lui decrit son propre salon sans appeler personne.

**Resolution :** Le lendemain matin, Kita est toujours la. Il lui donne un briefing matinal vocal : meteo, agenda, notifications. En sortant, elle dit "guide-moi" et Kita active la camera en mode passif. Il l'alerte d'un trottoir en travaux 10 metres devant elle. Marie n'a plus lance Be My Eyes depuis l'installation de Kita.

---

### Journey 2 : Marie — Perte de connexion (Edge Case)

**Opening Scene :** Marie marche en ville avec Kita actif en mode passif. Elle pointe son telephone vers un panneau et dit "lis ca". La requete part vers le cloud mais le reseau 4G est indisponible.

**Rising Action :** L'AI Router detecte l'echec reseau. Le RequestClassifier classe la requete comme "standard" (pas critique). Le fallback chain s'active : cloud puissant (timeout 3s) → cloud rapide (timeout 3s) → IA locale.

**Climax :** L'IA locale (ML Kit OCR) prend le relais. La qualite est inferieure au cloud mais le texte principal est lu en 2 secondes. Kita annonce : "Je suis hors ligne. Voici ce que j'arrive a lire : 'Pharmacie du Centre — Ouvert 9h-19h'."

**Resolution :** Marie continue sa route. Kita reste en mode local : les alertes d'obstacles fonctionnent normalement (elles sont toujours locales). Quand le reseau revient, Kita bascule silencieusement vers le cloud. Si un DANGER est detecte (voiture, trou) pendant la coupure, l'alerte locale fonctionne en < 50ms — les requetes critiques ne passent JAMAIS par le cloud.

---

### Journey 3 : Sophie — Aidante (installe Kita pour sa mere)

**Opening Scene :** Sophie, 42 ans, decouvre Kita via un influenceur Instagram qui en parle. Sa mere Francoise, 68 ans, perd progressivement la vue suite a une DMLA. Sophie telecharge Kita sur le telephone de sa mere.

**Rising Action :** A l'onboarding, Sophie selectionne "j'installe pour quelqu'un d'autre". Kita lui demande le profil de Francoise : "malvoyante". Le pack adapte est installe. Kita demande si Sophie veut etre contact d'urgence — elle accepte et entre son numero. Kita adapte la taille des textes et le contraste pour la basse vision de Francoise.

**Climax :** Sophie tend le telephone a sa mere. Kita dit : "Bonjour Francoise, je suis Kita. Sophie m'a installe pour vous aider. Dites 'decris' pour que je vous montre ce que je sais faire." Francoise essaie. Kita decrit le salon. Francoise dit : "C'est comme avoir quelqu'un a cote de moi." Sophie est soulagee — elle ne sera plus le seul recours de sa mere.

**Resolution :** Sophie recoit une notification quand Francoise declenche le protocole SOS (fausse alerte — elle testait). Sophie peut voir que Kita fonctionne bien sans avoir a appeler sa mere chaque jour. L'autonomie de Francoise soulage toute la famille.

---

### Journey 4 : Alex — Developpeur de plugin

**Opening Scene :** Alex, 27 ans, developpeur Flutter freelance, decouvre Kita sur GitHub. Le repo a 2000 stars et une architecture propre. Il voit que le SDK plugin est documente et qu'il y a un CLI. Il a une idee : un plugin qui scanne les menus de restaurant et les lit a voix haute avec les prix.

**Rising Action :** Alex lance `kita create menu-reader`. Le CLI genere un scaffolding avec le manifest YAML, l'interface KitaPlugin, et un test de base. Il definit ses permissions (camera, speaker) et ses capabilities IA (VISION_READ, textGeneration). Il implemente handleRequest() : capture photo → envoi au cloud IA → extraction menu → lecture vocale.

**Climax :** `kita test` lance les tests locaux dans le sandbox. Le plugin fonctionne. `kita validate` verifie le manifest, les permissions, et la securite. Tout est vert. Alex soumit une PR sur le repo communautaire.

**Resolution :** Apres code review par la communaute, le plugin est merge comme "communautaire verifie". Marie l'installe. Au restaurant, elle dit "lis le menu" et Kita lui lit les plats avec les prix. Alex recoit ses premieres etoiles sur GitHub. Il commence a travailler sur un plugin de scan de tickets de caisse.

---

### Journey Requirements Summary

| Journey | Capabilities revelees |
|---------|----------------------|
| Marie succes | Onboarding vocal-first, detection accessibilite, packs auto, Plugin Describe, mode passif, briefing matinal, camera adaptative |
| Marie edge case | AI Router fallback chain, mode hors-ligne, IA locale OCR, bascule cloud/local transparente, alertes critiques toujours locales |
| Sophie aidante | Mode "installe pour un autre", contact d'urgence, notifications SOS, profil basse vision, onboarding delegue |
| Alex developpeur | SDK plugin (pub.dev), CLI (create/test/validate), manifest YAML, sandbox, code review communautaire, publication |

## Domain-Specific Requirements

### Compliance & Regulatory

**RGPD (donnees sensibles) :**
- Les donnees de handicap sont des "donnees sensibles" au sens RGPD (Article 9) — consentement explicite obligatoire avant toute collecte
- Droit a l'oubli : deja prevu via MemoryVault.forget() — doit etre complet et verifiable
- Portabilite : l'utilisateur doit pouvoir exporter ses donnees
- Transparence : deja prevu via MemoryVault.whatDoYouKnow() — l'utilisateur peut demander "Kita, qu'est-ce que tu sais sur moi ?"
- Pas de transfert de donnees vers les providers IA sans anonymisation ou consentement explicite (les photos envoyees a Claude/OpenAI pour description ne doivent pas contenir de metadonnees identifiantes)

### Technical Constraints

**Accessibilite** (cibles mesurables : voir [NFR-ACC](#accessibilite-1)) **:**
- WCAG 2.1 niveau AA minimum pour toute l'interface
- 100% compatible VoiceOver (iOS) et TalkBack (Android)
- Navigation complete des flows critiques en vocal uniquement
- Tests d'accessibilite automatises bloquants dans la CI/CD

**Vie privee** (cibles mesurables : voir [NFR-SEC](#securite) et [FR-SEC](#securite--vie-privee)) **:**
- Architecture local-first : aucune donnee ne quitte le telephone sans consentement explicite
- Chiffrement AES-256 au repos (Isar), cles API dans Keychain/Keystore
- Requetes cloud IA : strict minimum, pas de profil utilisateur, strip EXIF
- Pas de tracking ni analytics identifiants sans consentement

**Securite des personnes :**
- Alertes critiques en < 50ms via IA locale uniquement — JAMAIS de dependance cloud
- Fallback chain testee avec 0% d'echec sur requetes critiques
- Protocole SOS (post-MVP) : fonctionnel meme sans internet (alerte sonore locale + SMS)

**Store Compliance** (detail : voir [Mobile App Specific Requirements](#mobile-app-specific-requirements)) **:**
- Apple App Store : guidelines accessibilite, justification permissions, politique de confidentialite RGPD
- Google Play : declaration permissions sensibles, politique donnees de sante/handicap, data safety section

## Innovation & Novel Patterns

### Detected Innovation Areas

1. **OpenClaw mobile — concept inexistant** — Le concept d'agent IA autonome open source existe sur desktop (OpenClaw) mais n'a jamais ete transpose sur mobile avec les capteurs du telephone comme interface sensorielle. Kita est le premier a occuper cette niche.

2. **Combinaison inedite de 5 piliers** — Aucun produit existant ne combine : capteurs telephone comme "sens" de l'agent + multi-provider IA sans lock-in + plugins modulaires communautaires + memoire locale chiffree persistante + accessibilite comme mission. Chaque pilier existe separement, la combinaison est nouvelle.

3. **IA hybride locale/cloud pour la securite des personnes** — Les apps d'accessibilite existantes (Be My Eyes, Seeing AI, Ava) dependent a 100% du cloud. Kita introduit un tier local (ML Kit/CoreML) qui garantit que les alertes critiques (obstacles, danger) fonctionnent en < 50ms sans connexion. Innovation architecturale a impact vital.

### Market Context & Competitive Landscape

- **OpenClaw** (desktop) : prouve le concept agent IA open source, 100+ AgentSkills, multi-provider — mais desktop uniquement, pas de capteurs physiques
- **Be My Eyes** : description visuelle IA — mais mono-usage, mono-provider (GPT-4), pas de plugins, pas de memoire
- **Seeing AI** : OCR + detection — mais iOS uniquement, pas extensible, pas de communaute
- **Aucun concurrent direct** ne combine mobile + capteurs + plugins + multi-provider + accessibilite + open source

### Validation Approach

- **MVP valide le pilier 1** (capteurs + IA) avec le Plugin Describe : si photo → description vocale < 5s fonctionne, le concept est prouve
- **Beta fermee avec utilisateur aveugle reel** valide l'impact accessibilite
- **Ouverture GitHub** valide l'interet communaute (stars, forks, PRs)
- **Metriques claires** : DAU/MAU > 60% = le produit est indispensable

Risques lies a l'innovation : voir [Risk Mitigation Strategy](#risk-mitigation-strategy) dans Project Scoping.

## Mobile App Specific Requirements

### Project-Type Overview

Kita est une application mobile cross-platform construite avec Flutter et des modules natifs Swift (iOS) / Kotlin (Android) pour les operations critiques en performance. L'app fonctionne comme un agent IA permanent avec acces aux capteurs du telephone, necessitant une gestion fine de la batterie, des permissions, et du cycle de vie de l'application en arriere-plan.

### Platform Requirements

| Aspect | Specification |
|--------|--------------|
| Framework | Flutter 3.x + modules natifs Swift/Kotlin |
| Android minimum | Android 12 (API 31) |
| iOS minimum | iOS 16 |
| Architecture | Feature-first + Clean Architecture |
| State management | Riverpod |
| Storage | Isar (chiffre AES-256) |
| Langues | Francais (MVP), extensible multi-langue |

### Device Permissions

| Permission | Usage | Profil | MVP |
|-----------|-------|--------|-----|
| Camera | Description visuelle, detection obstacles | Aveugle | Oui |
| Microphone | STT, analyse ambiante, wake word | Tous | Oui |
| Localisation (GPS) | Navigation, contexte geographique | Tous | Oui |
| Accelerometre | Detection mouvement, FPS adaptatif | Aveugle | Oui |
| Notifications push | Alertes SOS vers aidants | Tous | Non (v0.2) |
| NFC | Tags domestiques, scan produits | Aveugle | Non (v0.2) |
| Bluetooth | Trackers d'objets | Tous | Non (v1.0) |

**Permission Storytelling :** Chaque permission est expliquee dans son contexte avant d'etre demandee ("Pour decrire ce qui t'entoure, j'ai besoin de ta camera"). Ordre adapte au profil (aveugle → camera d'abord).

### Offline Mode

**Strategie :** Local-first avec enrichissement cloud

| Mode | Disponibilite | Capacites |
|------|--------------|-----------|
| Online complet | Cloud + local | Description IA avancee, conversation, analyse complexe |
| Degrade (hors-ligne) | Local uniquement | OCR basique (ML Kit), detection obstacles, alertes, STT/TTS |
| Critique | Local uniquement | Alertes obstacles < 50ms, alerte sonore brute |

La bascule online/offline est transparente pour l'utilisateur. Kita annonce "Je suis hors ligne" uniquement quand la qualite de reponse est impactee.

### Push Notifications Strategy

**MVP :** Pas de push notifications. Les alertes obstacles sont locales (vocales et haptiques sur le telephone de l'utilisateur).

**Post-MVP (v0.2+) :** Extensible par plugins
- Protocole SOS avec notification push vers le contact d'urgence (aidant)
- Firebase Cloud Messaging (Android) / APNs (iOS), fallback SMS
- Chaque plugin peut definir ses propres notifications dans son manifest
- Le PluginSandbox controle les quotas de notifications par plugin
- L'utilisateur peut configurer les notifications par plugin

### Store Compliance

**Apple App Store :**
- Conformite aux guidelines d'accessibilite Apple
- Justification des permissions camera/micro pour review
- Politique de confidentialite conforme RGPD
- Pas de payment processing in-app au MVP (mode decouverte gratuit + BYOK)

**Google Play :**
- Declaration des permissions sensibles (camera, micro, localisation)
- Politique de donnees de sante et handicap
- Target API level conforme aux exigences annuelles Google
- Data safety section complete (local-first, chiffrement)

### Implementation Considerations

**Background execution :**
- Mode passif permanent = service en arriere-plan
- iOS : Background Audio + Location updates pour maintenir l'app active
- Android : Foreground Service avec notification permanente
- Gestion batterie : FPS adaptatif, capteurs actives uniquement si necessaire

**Performance critique :**
- Alertes obstacles : < 50ms (IA locale, pas de round-trip cloud)
- STT local : < 200ms de latence
- TTS local : demarrage < 100ms
- Demarrage app : < 3 secondes cold start

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**Approche :** Double MVP — Problem-solving + Platform

1. **Problem-solving** — Resoudre parfaitement la description visuelle pour Marie (aveugle). Si ce cas d'usage fonctionne et impressionne, le produit est valide.
2. **Platform** — Prouver que l'architecture (AI Router, Plugin System, PluginSandbox, MemoryVault) fonctionne. Si un developpeur peut comprendre l'interface KitaPlugin et imaginer son propre plugin, la plateforme est validee.

**Resource Requirements :** 1 developpeur Flutter senior (Charles) + communaute open source progressive. Pas de backend a maintenir (local-first + API keys utilisateur).

### MVP Feature Set (Phase 1)

**Journeys supportes :**
- Marie succes (onboarding → description → usage quotidien)
- Marie edge case (fallback hors-ligne)

**Must-Have :**
- AI Router avec 1-2 providers cloud (Claude + OpenAI) + IA locale
- Fallback chain (cloud → local → alerte brute)
- RequestClassifier (critical/urgent/standard/background)
- STT local + TTS local
- Camera service (capture unique)
- Memoire chiffree Isar + profil utilisateur + MemoryVault
- Plugin Describe (photo → description vocale < 5s)
- Plugin Alert (detection obstacles < 50ms)
- Interface KitaPlugin + PluginManifest + PluginSandbox
- Onboarding vocal-first < 3 minutes avec detection accessibilite
- Pack aveugle pre-installe
- Mode passif permanent + activation a la demande
- Droit a l'oubli (forget everything)

**Explicitement hors MVP :**
- Push notifications / SOS vers aidants
- Navigation temps reel FPS adaptatif
- SDK developpeur / CLI
- Marketplace de plugins
- Kita Cloud / Enterprise
- Packs sourds, autistes
- Multi-appareils

### Post-MVP Features

**Phase 2 — "Kita bouge" (3-6 mois) :**
- Navigation temps reel avec camera FPS adaptatif
- Cache Manager par similarite
- Push notifications + protocole SOS vers aidants
- Mode "installe pour quelqu'un d'autre" (journey Sophie)
- Plugins supplementaires (briefing matinal, lecteur documents)
- SDK developpeur + CLI (kita create/test/validate/publish)

**Phase 3 — "Kita pour tous" (6-12 mois) :**
- Packs sourds (transcription multi-locuteurs "Discord IRL")
- Packs autistes (scripts sociaux, bulle sensorielle)
- Marketplace de plugins communautaires
- Kita Cloud (proxy API simplifie 5€/mois)
- Profils vocaux et reconnaissance de locuteurs
- Multi-langue

**Phase 4 — "L'ecosysteme" (12-24 mois) :**
- Multi-appareils (lunettes connectees, montre, domotique)
- Kita Enterprise (hopitaux, ecoles, EHPAD)
- Milliers de plugins communautaires
- L'OpenClaw mobile a part entiere

### Risk Mitigation Strategy

**Risques techniques :**

| Risque | Probabilite | Impact | Mitigation |
|--------|------------|--------|------------|
| IA locale imprecise sur mid-range | Moyenne | Haute | Tester sur 3-4 appareils mid-range des le sprint 1, seuil confiance > 80%, fallback alerte brute |
| Latence cloud > 5s | Moyenne | Moyenne | Timeout agressif (3s), fallback local, cache futur |
| Battery drain mode passif | Haute | Haute | FPS adaptatif, capteurs off si immobile, monitoring batterie |
| Isar perfs sur gros volumes | Faible | Moyenne | Index tags O(1), nettoyage episodic 30j, benchmark early |
| Multi-provider routing complexe | Moyenne | Moyenne | MVP avec 1-2 providers, architecture extensible |
| Memoire locale persistante saturee | Faible | Moyenne | Index par tags O(1), nettoyage episodic 30j, monitoring |

**Risques produit & securite :**

| Risque | Probabilite | Impact | Mitigation |
|--------|------------|--------|------------|
| Fausse alerte obstacle | Moyenne | Haute | Seuil de confiance > 80%, feedback utilisateur pour affiner |
| Alerte manquee (danger reel) | Faible | Critique | Double detection (IA locale + heuristiques), alertes critiques toujours actives |
| Fuite donnees sensibles vers cloud | Faible | Critique | Strip EXIF, pas de contexte utilisateur, consentement explicite |
| Plugin malveillant | Moyenne | Haute | PluginSandbox, permissions manifest, 3 niveaux de confiance |
| Batterie epuisee en situation critique | Moyenne | Haute | Mode eco adaptatif, alerte batterie faible proactive |

**Risques marche & ressources :**

| Risque | Mitigation |
|--------|------------|
| Pas d'adoption | Beta fermee avec association d'aveugles, feedback direct |
| Pas de communaute dev | Architecture claire, documentation exemplaire, 2 plugins officiels comme reference |
| Concurrence (Be My Eyes ajoute des plugins) | Avance open source + multi-provider + memoire locale = moat |
| Solo dev = bottleneck | Architecture modulaire, open source des le debut, contributions bienvenues |
| Scope creep | PRD strict, MVP minimal, "non" par defaut pour les features hors scope |
| Burnout | 4 sprints de 2 semaines, scope realiste, pas de deadline artificielle |

## Functional Requirements

Les exigences fonctionnelles sont organisees par domaine de capacite. Chaque FR est identifiee de facon unique et reliee aux journeys utilisateur et a l'architecture definie.

### AI & Intelligence

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-AI-001 | L'AI Router doit router les requetes vers le provider optimal (Claude, OpenAI, Gemini, local) selon le RequestClassifier | Must | Tous |
| FR-AI-002 | Le RequestClassifier doit classer chaque requete en 4 niveaux : critical (< 50ms local), urgent (< 500ms), standard (< 5s), background (async) | Must | Marie succes, Marie edge |
| FR-AI-003 | La fallback chain doit cascader : cloud puissant (timeout 3s) → cloud rapide (timeout 3s) → IA locale → alerte brute | Must | Marie edge |
| FR-AI-004 | L'IA locale (ML Kit / CoreML) doit traiter les requetes critiques en < 50ms sans connexion internet | Must | Marie edge |
| FR-AI-005 | Les requetes classees "critical" ne doivent JAMAIS retourner d'erreur — alerte brute sonore en dernier recours | Must | Marie edge |
| FR-AI-006 | L'AI Router doit supporter l'ajout de nouveaux providers via une interface abstraite sans modification du code existant | Should | Alex dev |

### Perception & Capteurs

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-PER-001 | Le Camera Service doit capturer une photo unique a la commande vocale "decris" | Must | Marie succes |
| FR-PER-002 | Le Camera Service doit supporter le mode passif (flux video continu) pour la detection d'obstacles | Must | Marie succes |
| FR-PER-003 | L'AudioMultiplexer doit multiplexer le microphone entre STT (commandes vocales) et analyse ambiante (detection sons) | Must | Tous |
| FR-PER-004 | Le STT local doit transcrire la parole avec une latence < 200ms | Must | Tous |
| FR-PER-005 | Le service GPS doit fournir les coordonnees, l'adresse inversee et les POIs proches aux plugins qui le demandent | Must | Marie succes |
| FR-PER-006 | L'accelerometre doit detecter l'etat de mouvement (immobile / marche / course) pour adapter le FPS camera | Should | Marie succes |
| FR-PER-007 | Le mode passif permanent doit maintenir les capteurs minimaux actifs (micro ambient, accelerometre) et activer les capteurs supplementaires (camera, GPS) sur commande vocale, mouvement detecte ou evenement plugin | Must | Tous |

### Communication & Sortie

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-COM-001 | Le TTS local doit demarrer la synthese vocale en < 100ms | Must | Tous |
| FR-COM-002 | Le SpeechOutputService doit gerer une file de priorite (critique > urgent > standard) sans interrompre les alertes critiques | Must | Marie edge |
| FR-COM-003 | L'interface vocale doit reconnaitre les commandes cles : "decris", "lis ca", "stop", "aide" | Must | Marie succes |
| FR-COM-004 | L'interface textuelle doit etre disponible en alternative complete a l'interface vocale | Must | Tous |
| FR-COM-005 | Le HapticService doit fournir un retour haptique differencie pour les alertes (3 patterns minimum : info, warning, danger) | Must | Marie succes |
| FR-COM-006 | Kita doit annoncer vocalement les changements d'etat suivants : perte de connexion, batterie < 20%, provider IA indisponible, activation du mode degrade | Should | Marie edge |

### Memoire & Donnees

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-MEM-001 | Toutes les donnees utilisateur doivent etre stockees dans Isar avec chiffrement AES-256 | Must | Tous |
| FR-MEM-002 | La memoire doit etre organisee en 4 domaines : working (session), episodic (evenements), semantic (connaissances), relational (personnes) | Must | Tous |
| FR-MEM-003 | MemoryVault doit exiger un consentement explicite avant tout stockage de donnees sensibles (profil handicap, preferences) | Must | Marie succes, Sophie |
| FR-MEM-004 | MemoryVault.forget() doit effacer 100% des donnees recuperables — verifiable par audit | Must | Tous |
| FR-MEM-005 | MemoryVault.whatDoYouKnow() doit permettre a l'utilisateur de consulter toutes les donnees stockees a son sujet | Must | Tous |
| FR-MEM-006 | Le profil utilisateur doit persister entre les sessions (preferences, profil handicap, configuration providers) | Must | Tous |
| FR-MEM-007 | Le nettoyage automatique de la memoire episodique doit supprimer les entrees > 30 jours sauf celles marquees comme importantes | Should | Tous |

### Plugin System

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-PLG-001 | Chaque plugin doit implementer l'interface abstraite KitaPlugin avec des methodes de traitement de requete et de liberation de ressources | Must | Alex dev |
| FR-PLG-002 | Chaque plugin doit declarer un manifest YAML definissant : permissions, capabilities IA, metadata, profils compatibles | Must | Alex dev |
| FR-PLG-003 | Le PluginSandbox doit isoler chaque plugin et enforcer les permissions declarees dans le manifest | Must | Tous |
| FR-PLG-004 | Le systeme doit supporter 3 niveaux de confiance : officiel (core), communautaire verifie, non verifie | Must | Alex dev |
| FR-PLG-005 | Le Plugin Describe doit capturer une photo, l'envoyer a un provider cloud IA, et vocaliser la description en < 5 secondes bout en bout | Must | Marie succes |
| FR-PLG-006 | Le Plugin Alert doit detecter les obstacles via IA locale (ML Kit / CoreML) et alerter (voix + haptique) en < 50ms | Must | Marie succes |
| FR-PLG-007 | Les plugins doivent pouvoir etre charges et decharges dynamiquement sans redemarrage de l'application | Should | Tous |

### Onboarding & Configuration

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-ONB-001 | L'onboarding doit etre completable en < 3 minutes en mode vocal-first | Must | Marie succes |
| FR-ONB-002 | L'onboarding doit detecter automatiquement VoiceOver (iOS) / TalkBack (Android) et adapter l'experience immediatement | Must | Marie succes |
| FR-ONB-003 | L'utilisateur doit pouvoir selectionner son profil (aveugle, malvoyant, sourd, autiste, general) et recevoir le pack correspondant | Must | Marie succes, Sophie |
| FR-ONB-004 | Le pack profil doit s'installer automatiquement avec les plugins et la configuration adaptes | Must | Marie succes |
| FR-ONB-005 | Chaque permission doit etre expliquee dans son contexte d'usage avant d'etre demandee ("Pour decrire ce qui t'entoure, j'ai besoin de ta camera") | Must | Marie succes |
| FR-ONB-006 | Le mode decouverte gratuit doit permettre d'utiliser Kita sans cle API (credits limites) | Must | Marie succes |
| FR-ONB-007 | Le mode BYOK (Bring Your Own Key) doit permettre a l'utilisateur de configurer ses propres cles API providers | Must | Tous |
| FR-ONB-008 | Le mode "installe pour quelqu'un d'autre" doit permettre a un aidant de configurer Kita pour un tiers | Should | Sophie |

### Securite & Vie Privee

| ID | Exigence | Priorite | Journey |
|----|----------|----------|---------|
| FR-SEC-001 | Aucune donnee utilisateur ne doit quitter le telephone sans consentement explicite | Must | Tous |
| FR-SEC-002 | Les requetes cloud IA ne doivent contenir que le strict necessaire — pas de profil utilisateur ni de contexte memoire sauf demande explicite du plugin | Must | Tous |
| FR-SEC-003 | Les metadonnees identifiantes (EXIF, geolocalisation) doivent etre supprimees des photos avant envoi au cloud | Must | Marie succes |
| FR-SEC-004 | L'application ne doit integrer aucun tracking ni analytics identifiant sans consentement | Must | Tous |
| FR-SEC-005 | Le mode 100% hors-ligne doit etre fonctionnel (degrade mais utilisable pour les fonctions critiques) | Must | Marie edge |

### Recapitulatif

| Domaine | Must | Should | Total |
|---------|------|--------|-------|
| AI & Intelligence | 5 | 1 | 6 |
| Perception & Capteurs | 5 | 2 | 7 |
| Communication & Sortie | 4 | 2 | 6 |
| Memoire & Donnees | 5 | 2 | 7 |
| Plugin System | 5 | 2 | 7 |
| Onboarding & Configuration | 6 | 2 | 8 |
| Securite & Vie Privee | 5 | 0 | 5 |
| **Total** | **35** | **11** | **46** |

## Non-Functional Requirements

Les NFR definissent comment le systeme doit performer — pas ce qu'il fait. Seules les categories pertinentes a Kita sont documentees.

### Performance

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-PERF-001 | Temps de reponse alertes obstacles (IA locale) | < 50ms | Benchmark embarque, tests automatises |
| NFR-PERF-002 | Description photo bout en bout (capture → voix) | < 5 secondes | Monitoring in-app |
| NFR-PERF-003 | Demarrage TTS | < 100ms | Tests de latence |
| NFR-PERF-004 | Latence STT local | < 200ms | Tests de latence |
| NFR-PERF-005 | Cold start de l'application | < 3 secondes | Tests de demarrage sur appareils cibles |
| NFR-PERF-006 | Consommation batterie en mode passif | < 5% par heure | Tests sur appareils mid-range, monitoring batterie |
| NFR-PERF-007 | Memoire RAM en mode passif | < 200 MB | Profiling sur appareils Android 12 mid-range |

### Securite

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-SEC-001 | Chiffrement donnees au repos | AES-256 (Isar) | Audit code, tests de verification chiffrement |
| NFR-SEC-002 | Aucune donnee sensible dans les logs de l'app | 0 fuite | Revue de code, tests automatises de detection PII |
| NFR-SEC-003 | Cles API stockees de facon securisee | Keychain (iOS) / Keystore (Android) | Audit securite |
| NFR-SEC-004 | Strip des metadonnees EXIF avant envoi cloud | 100% des photos | Tests automatises |
| NFR-SEC-005 | Conformite RGPD Article 9 (donnees sensibles) | Consentement explicite verifie | Audit flux de consentement |
| NFR-SEC-006 | Effacement complet sur "forget everything" | 0 donnee residuelle recuperable | Tests d'effacement + verification forensique |

### Accessibilite

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-ACC-001 | Conformite WCAG | 2.1 niveau AA minimum | Tests automatises (axe, flutter_test accessibility) |
| NFR-ACC-002 | Compatibilite lecteurs d'ecran | 100% VoiceOver + TalkBack | Tests manuels sur iOS + Android |
| NFR-ACC-003 | Contraste texte | >= 4.5:1 | Tests automatises |
| NFR-ACC-004 | Contraste elements UI | >= 3:1 | Tests automatises |
| NFR-ACC-005 | Labels accessibles | 100% des elements interactifs | Tests automatises CI/CD |
| NFR-ACC-006 | Navigation complete sans ecran | 100% des flows critiques en vocal uniquement | Tests de scenarios utilisateur |

### Fiabilite

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-REL-001 | Crashs sur flows critiques (onboarding, describe, alert) | 0 | Crash reporting integre |
| NFR-REL-002 | Disponibilite fallback chain | 100% — toujours une reponse | Tests d'integration avec simulation de pannes |
| NFR-REL-003 | Fonctionnement hors-ligne des fonctions critiques | 100% (alertes, STT/TTS) | Tests en mode avion |
| NFR-REL-004 | Stabilite en execution prolongee (mode passif 24h+) | 0 crash, 0 memory leak | Tests de stress prolonges |
| NFR-REL-005 | Recovery apres crash | Temps de reprise du mode passif < 10 secondes | Tests de recovery automatises |

### Integration

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-INT-001 | Compatibilite providers IA (Claude, OpenAI) | Support des 2 dernieres versions majeures de chaque API provider | Tests d'integration, versioning des adaptateurs |
| NFR-INT-002 | Interface plugin stable et retrocompatible | 0 breaking change sans cycle de deprecation d'au moins 1 version majeure | Tests de contrat, semver |
| NFR-INT-003 | Compatibilite ML Kit / CoreML | Versions stables supportees | Tests sur appareils cibles |

### Testabilite

| ID | Exigence | Cible | Methode de mesure |
|----|----------|-------|-------------------|
| NFR-TEST-001 | Couverture de tests | > 80% | CI/CD (coverage reports) |
| NFR-TEST-002 | Tests d'accessibilite automatises dans la CI | Bloquant sur la CI | Configuration CI |
| NFR-TEST-003 | Tests sur appareils reels (mid-range) | Au moins 3 appareils Android + 2 iOS | Matrice de tests |
