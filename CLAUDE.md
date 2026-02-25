# Kita — CLAUDE.md

## Projet

Kita est un compagnon IA mobile d'assistance au handicap (visuel, auditif, cognitif). Application Flutter cross-platform, local-first, voice-first, conçue pour l'accessibilité WCAG 2.1 AA+.

**Persona MVP :** Marie, 28 ans, aveugle de naissance, utilisatrice VoiceOver.

**Stack technique :**
- Flutter 3.41+ / Dart 3.11+
- Riverpod 3.0 (state management)
- Drift + SQLCipher (DB locale chiffrée AES-256)
- Mix (utility-first styling)
- go_router (navigation)
- ML Kit (Android) / CoreML (iOS) pour IA locale
- TFLite + YOLO (détection obstacles)
- flutter_secure_storage (Keychain/Keystore)

**Cibles :** Android 12+ (API 31, target 35) / iOS 16+

---

## Architecture & Conventions

### Structure

Feature-first + Clean Architecture (`domain/ ← data/ ← presentation/`).

```
lib/
├── core/           # DI, config, errors, theme, utils
├── features/
│   ├── ai/         # AI Router, providers, classifier, fallback
│   ├── io/         # Camera, audio, haptic, location, motion
│   ├── memory/     # Drift store, vault, collections
│   ├── plugins/    # Plugin interface, registry, sandbox, built_in/
│   ├── onboarding/ # Flow complet, detection accessibilité
│   ├── shell/      # KitaShell, KitaOrb, KitaInput
│   └── settings/   # Preferences, profil, forget
├── shared/         # Widgets partagés, multi_modal/
└── platform/       # Code natif bridge (ios/, android/)
```

### Conventions de code

| Règle | Convention |
|-------|-----------|
| Error handling | `sealed class KitaFailure` + `Result<T>` — jamais de `throw` non typé |
| Output | `ProfileAdapter` obligatoire pour tout output multi-modal — jamais d'output direct |
| Accessibilité | `Semantics` wrapper sur chaque widget interactif — lint rule custom |
| Logging | Format `[Source] Message` — zero PII dans les logs |
| State | Providers Riverpod décentralisés par feature, `AsyncValue<T>` pour tous les états async |
| DB | Tables modulaires `.drift` par feature, DAOs typesafe retournant des objets domain |
| Nommage | Dart Style Guide : `UpperCamelCase` classes, `snake_case` fichiers, `lowerCamelCase` variables |
| Providers | `lowerCamelCase` + suffixe `Provider` (ex: `aiRouterProvider`) |
| Plugins | ID reverse domain (`com.kita.describe`), classe `Kita{Name}Plugin`, manifest `plugin.kita.yaml` |
| Fichiers générés | `*.g.dart`, `*.freezed.dart` dans `.gitignore` — ne PAS commiter |

---

## Documents BMAD de référence

| Document | Chemin |
|----------|--------|
| PRD | `_bmad-output/planning-artifacts/prd.md` |
| Architecture | `_bmad-output/planning-artifacts/architecture.md` |
| UX Design | `_bmad-output/planning-artifacts/ux-design-specification.md` |
| Epics & Stories | `_bmad-output/planning-artifacts/epics.md` |
| Sprint Status | `_bmad-output/implementation-artifacts/sprint-status.yaml` |
| Story files | `_bmad-output/implementation-artifacts/` (un fichier par story enrichie) |

---

## Développement multi-agents

### Phases et parallélisme

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

### Branches

- `main` = stable, protégée
- `develop` = intégration continue
- `epic/e{N}-{nom}` = branche par agent, depuis `develop`
- Chaque story = PR squash-merge vers `develop`
- Rebase depuis `develop` au début de chaque nouvelle story

### Propriété des fichiers

**Fichiers protégés (propriété exclusive du leader/E1) :**
- `lib/core/**` — DI, config, errors, theme, utils
- `pubspec.yaml` — Dépendances
- `lib/shared/database.dart` — Setup DB global
- `analysis_options.yaml` — Linting
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Sprint tracking

Les agents des phases 2+ **ne modifient PAS** ces fichiers. Si une modification est nécessaire, envoyer un message au leader via SendMessage.

**Propriété par epic (Phase 2) :**

| Agent | Feature directory | Fichiers possédés |
|-------|-------------------|-------------------|
| E2 (IA) | `lib/features/ai/**` | Classifier, Router, Providers, Cache, Fallback |
| E3 (I/O) | `lib/features/io/**` | Camera, STT, TTS, Haptic, Audio, Location, Motion |
| E4 (Mémoire) | `lib/features/memory/**` | Drift DAOs, Vault, Forget, Profil, Nettoyage |
| E5 (Plugins) | `lib/features/plugins/**` | Manifest, Sandbox, Registry |
| E8 (Shell) | `lib/features/shell/**` + `lib/shared/` | Orb, Shell, Input, Viewport, Alert, ProfileAdapter |

Chaque agent ne touche QUE ses fichiers. Les story files dans `_bmad-output/implementation-artifacts/` sont modifiables par l'agent qui implémente la story correspondante.

### Phase Gates

| Transition | Critères |
|---|---|
| Phase 1→2 | E1 mergé, 8 stories vertes, `flutter test` pass, `dart analyze` clean, `build_runner` OK |
| Phase 2→3 | E2-E5+E8 mergés, Story 2.8 Integration Gate passe, couverture > 70% par feature |
| Phase 3→4 | E6+E7 mergés, Story 7.3 Integration Gate passe, flows Describe + Alert E2E OK |
| Phase 4→5 | E9+E10 mergés, Story 10.4 Integration Gate passe, onboarding E2E OK, passif stable 1h |
| Phase 5→Release | E11 complet, couverture > 80%, tests a11y bloquants, builds signés |

### Développement en équipe (multi-agent)

Le leader orchestre les agents via TeamCreate. Chaque teammate est une session Claude Code indépendante qui lit ce CLAUDE.md automatiquement.

**Workflow du leader :**
1. Créer les story files enrichis via `/bmad-bmm-create-story`
2. Spawner les teammates en worktrees isolés (`isolation: "worktree"`)
3. Chaque teammate implémente ses stories (voir "Workflow d'implémentation" ci-dessous)
4. Le leader lance `/bmad-bmm-code-review` sur chaque story terminée
5. Le leader gère les demandes de modification des fichiers protégés

**Règles pour les teammates :**
- **Tenter `/bmad-bmm-dev-story`** en premier — c'est le workflow complet avec Dev Agent Record
- **Si le skill échoue** → suivre le "Workflow d'implémentation de story" ci-dessous
- **Ne JAMAIS modifier** les fichiers hors de son feature directory (voir "Propriété des fichiers")
- **Besoin de modifier `core/` ou `pubspec.yaml`** → envoyer un SendMessage au leader avec la justification
- **Communiquer les blocages** → SendMessage au leader, ne pas rester bloqué en silence
- **Conflits de merge** → rebase depuis `develop` avant de commencer une nouvelle story

---

## Instructions pour agents

### Pendant Create Story (`/bmad-bmm-create-story`)

1. **Lire la story** depuis `_bmad-output/planning-artifacts/epics.md`
2. **Lire les sections pertinentes** de `_bmad-output/planning-artifacts/architecture.md` (data architecture, patterns, interfaces concernées)
3. **Faire de la recherche web** sur les technologies de la story :
   - Versions exactes actuelles des packages (pub.dev)
   - Pièges connus, breaking changes, issues GitHub ouvertes
   - Snippets de configuration validés
   - Compatibilité avec les autres dépendances du projet
4. **Intégrer cette intelligence** dans le story file :
   - Section **"Technical Intelligence"** : versions vérifiées, API actuelles, exemples de code
   - Section **"Pitfalls & Gotchas"** : pièges découverts, workarounds, incompatibilités
5. **Le story file doit être autonome** — un agent dev doit pouvoir implémenter sans poser de questions et sans faire de recherche supplémentaire
6. **Consulter les "Pièges techniques globaux"** (section ci-dessous) et intégrer ceux qui s'appliquent à la story

### Pendant Dev Story (`/bmad-bmm-dev-story`)

1. **TOUJOURS lire le story file enrichi** dans `_bmad-output/implementation-artifacts/` AVANT de coder
2. **TOUJOURS lire l'architecture.md** pour le domaine concerné (section pertinente)
3. **NE PAS modifier** `core/`, `pubspec.yaml`, `database.dart` sauf si la story est dans E1
4. **NE PAS commiter** les fichiers générés (`*.g.dart`, `*.freezed.dart`)
5. **Accessibility Tax** (obligatoire pour toute story avec UI) :
   - `Semantics` wrapper avec label descriptif sur chaque widget interactif
   - Contrastes texte >= 4.5:1, éléments UI >= 3:1
   - Touch targets >= 48x48px (56x56px actions critiques)
   - Test Semantics matcher dans les tests unitaires
6. **Tests fonctionnels réels obligatoires** — pas juste des mocks sur abstractions :
   - Chaque story doit avoir au moins 1 test d'intégration avec des dépendances réelles (ex: Drift réel, pas mock DB)
   - Les tests doivent vérifier des comportements, pas juste que le code compile
   - Couverture minimale du code ajouté
7. **Mettre à jour** `_bmad-output/implementation-artifacts/sprint-status.yaml` quand la story change de statut

### Workflow d'implémentation de story (safety net)

Ce workflow est la **référence obligatoire** pour tout agent qui implémente une story — qu'il utilise le skill BMAD ou non. Si `/bmad-bmm-dev-story` est disponible, le lancer en premier. Sinon, suivre ces étapes :

**AVANT de coder :**
1. Lire le story file enrichi dans `_bmad-output/implementation-artifacts/`
2. Lire les sections pertinentes de `_bmad-output/planning-artifacts/architecture.md`
3. Mettre à jour sprint-status.yaml : story → `in-progress`

**PENDANT le développement :**
4. Suivre les Tasks/Subtasks dans l'ORDRE du story file — ne rien implémenter hors tâche
5. Pour chaque tâche : RED (test qui échoue) → GREEN (code minimal) → REFACTOR
6. Cocher `[x]` chaque tâche/sous-tâche SEULEMENT quand les tests passent
7. Respecter la propriété des fichiers (voir section "Propriété des fichiers")

**APRÈS le développement :**
8. Remplir le **Dev Agent Record** dans le story file — **GATE BLOQUANT** :
   - `Agent Model` : modèle utilisé
   - `Date` : date d'implémentation
   - `Completion Notes` : décisions prises, workarounds, problèmes rencontrés
   - `Files Modified` : liste complète des fichiers créés/modifiés/supprimés
   - **NE PAS passer à l'étape suivante si le Dev Agent Record est vide ou incomplet**
   - Si le story file n'a pas de section `## Dev Agent Record`, la créer
9. Mettre à jour le **File List** et le **Change Log** dans le story file
10. Mettre à jour le Status dans le story file → `review`
11. Lancer `dart analyze --fatal-infos` — doit être clean
12. Lancer `flutter test` — tous les tests doivent passer
13. Mettre à jour sprint-status.yaml : story → `review`

**Checklist de complétion (toutes les cases doivent être cochées) :**
- [ ] Story file enrichi lu avant de coder
- [ ] Architecture.md lu (section pertinente)
- [ ] Code implémenté + tous les tests passent
- [ ] Au moins 1 test d'intégration réel (pas juste des mocks)
- [ ] Accessibility Tax vérifié (si story avec UI)
- [ ] **GATE** Dev Agent Record rempli (Agent Model + Date + Completion Notes + Files Modified)
- [ ] Story file status → `review`
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe
- [ ] sprint-status.yaml mis à jour → `review`

### Pendant Code Review (`/bmad-bmm-code-review`)

1. Vérifier les **Acceptance Criteria** un par un
2. Vérifier l'**Accessibility Tax** si la story a du UI :
   - Semantics wrappers présents et descriptifs
   - Contrastes respectés
   - Touch targets conformes
3. Vérifier **zero PII** dans les logs
4. Vérifier que les **tests passent** (`flutter test`)
5. Vérifier que `dart analyze` est **clean**
6. Vérifier la **propriété des fichiers** — pas de modifications hors périmètre
7. **GATE** Vérifier que le **Dev Agent Record** est rempli — rejeter la review si vide
8. Vérifier que le **status du story file** est `review` (pas `ready-for-dev`)

---

## Pièges techniques globaux

Ces pièges s'appliquent à l'ensemble du projet. Les intégrer dans les story files quand pertinent.

### Drift + SQLCipher
- `sqlcipher_flutter_libs` : utiliser la version **0.6.x** — les versions 0.7.0+ sont deprecated/instables
- Ne **jamais** mélanger `sqlite3_flutter_libs` et `sqlcipher_flutter_libs` dans le même projet — conflit de symboles natifs
- Android 6 (API 23) : workaround nécessaire pour le chargement natif de SQLCipher — mais hors scope (Android 12+ minimum)

### Riverpod 3.0
- `StateProvider` et `StateNotifierProvider` sont déplacés dans `legacy.dart` — ne PAS les utiliser
- Utiliser les nouveaux patterns : `Notifier`, `AsyncNotifier`, `Mutation`
- Le code generator `riverpod_generator` est la méthode recommandée

### Code generation (freezed + json_serializable)
- Désactiver le lint `invalid_annotation_target` dans `analysis_options.yaml`
- Exclure `*.g.dart` et `*.freezed.dart` de l'analyse (`analyzer: exclude:`)
- Lancer `dart run build_runner build --delete-conflicting-outputs` après modification des modèles

### Linting — analysis_server_plugin (pas custom_lint)
- `custom_lint` est **abandonné** (bloqué analyzer 8, plus maintenu) — ne PAS l'utiliser
- On utilise `analysis_server_plugin` (officiel Dart team) via `riverpod_lint ^3.1.3`
- Syntaxe dans `analysis_options.yaml` : section `plugins:` au top level (pas dans `analyzer:`)
- Pour ajouter des lint rules custom à l'avenir, utiliser l'API `analysis_server_plugin` (pas custom_lint)

### Android / Gradle
- AGP 9 potentiellement incompatible avec certains plugins Flutter — rester sur AGP 8.x pour le MVP
- Vérifier la compatibilité NDK pour les libs natives (SQLCipher)

### iOS / Impeller
- Impeller est le renderer par défaut sur iOS (Skia retiré) — tester les CustomPainter (KitaOrb) avec Impeller
- Impeller activé par défaut sur Android API 29+ aussi — attention aux performances CustomPainter

### Mix framework
- Package actif mais communauté limitée — avoir un plan B (`ThemeExtension` custom) si maintenance s'arrête
- Vérifier la compatibilité avec la version Flutter utilisée

---

## Règles de qualité (leçons Phase 2)

Ces règles sont issues de la code review adversariale Phase 2. Tout agent DOIT les respecter.

### Zero PII dans les logs — STRICT
- **JAMAIS** de coordonnées GPS, noms, emails, clés API, tokens dans les logs
- Exemple interdit : `_log.info('Position: ${pos.latitude}, ${pos.longitude}')`
- Exemple correct : `_log.info('Position acquired successfully')`
- Vérifier chaque `_log.*()` avant de marquer "review"

### Resource disposal — OBLIGATOIRE
- Tout `Provider` qui crée un service avec état DOIT avoir `ref.onDispose()`
- Tout service avec `Timer`, `StreamSubscription`, ou ressource native DOIT avoir un `dispose()`
- Les callbacks async dans `ref.onDispose()` doivent utiliser `unawaited()` (import `dart:async`)
- Exemple :
  ```dart
  final myServiceProvider = Provider<MyService>((ref) {
    final service = MyServiceImpl();
    ref.onDispose(service.dispose);
    return service;
  });
  ```

### Race conditions — VÉRIFIER
- Pas de TOCTOU (Time-of-Check-Time-of-Use) : si on vérifie une condition puis agit dessus, l'opération doit être atomique
- Les callbacks haute fréquence (camera stream, accelerometer) doivent avoir un guard `_processing` pour éviter les appels concurrents
- Les `Timer.periodic` avec callbacks async doivent utiliser `unawaited()` + `.catchError()` et un flag `_disposed`

### Permissions et sécurité
- `enforcePermissions()` doit **réellement vérifier** les permissions, jamais retourner success par défaut
- Les accès sandboxés (mémoire, capteurs, IA) doivent valider les permissions du plugin avant chaque opération
- Les strings de permission doivent être validées contre un set connu (`camera`, `microphone`, `location`, etc.)
- Le champ `context` de `AIRequest` est metadata interne — JAMAIS envoyé aux providers IA externes

### Exception handling — TYPE CHECK
- Utiliser `is TimeoutException` au lieu de `e.toString().contains('TimeoutException')`
- Toujours utiliser des type checks (`is`) plutôt que du string matching pour les exceptions
- Import `dart:async` pour `TimeoutException` et `unawaited`

### Parsing et valeurs par défaut
- Ne jamais retourner silencieusement une string vide quand un parsing échoue — logger un warning
- Les paramètres de requête (ex: `maxTokens`) doivent être respectés dans toutes les méthodes, pas hardcodés

### Cohérence API
- Utiliser `MediaQuery.of(context).disableAnimations` pour la détection reduced motion (pas `platformDispatcher`)
- Les enums ne doivent pas contenir de valeurs inutilisées — supprimer ou marquer `@Deprecated`
- Les constantes magiques (`'data_storage'`) doivent être extraites en `static const`

### Textes français
- Toujours utiliser les accents corrects dans les strings françaises (`détectée`, pas `detectee`)
- Les tables d'accent-stripping doivent être vérifiées caractère par caractère

### Agent custom pour le développement
- Utiliser `subagent_type: "kita-dev"` (défini dans `.claude/agents/kita-dev.md`) pour spawner les agents de développement
- Cet agent précharge le skill BMAD `dev-story` et force le Dev Agent Record
- Ne plus utiliser `general-purpose` pour les agents de dev
