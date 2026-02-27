# Contribuer a Kita

Merci de votre interet pour Kita ! Chaque contribution compte, qu'il s'agisse de code, de documentation, de tests d'accessibilite ou simplement d'un rapport de bug.

Kita est un compagnon IA mobile d'assistance au handicap (visuel, auditif, cognitif). Notre mission est de rendre la technologie accessible a tous. L'application est concue pour Marie, 28 ans, aveugle de naissance, utilisatrice VoiceOver -- chaque contribution doit etre pensee pour elle en premier.

> **Licence :** MIT. En contribuant, vous acceptez que vos contributions soient publiees sous cette licence.

---

## Table des matieres

- [Code de conduite](#code-de-conduite)
- [Comment contribuer](#comment-contribuer)
- [Prerequis](#prerequis)
- [Installation locale](#installation-locale)
- [Architecture du projet](#architecture-du-projet)
- [Conventions de code](#conventions-de-code)
- [Regles d'accessibilite](#regles-daccessibilite)
- [Workflow Git](#workflow-git)
- [Processus de review](#processus-de-review)
- [Deploiement](#deploiement)
- [Questions et support](#questions-et-support)

---

## Code de conduite

Ce projet adopte le [Contributor Covenant v2.1](CODE_OF_CONDUCT.md). En participant, vous vous engagez a respecter ses termes. Tout comportement inacceptable peut etre signale a l'equipe de maintenance.

---

## Comment contribuer

### Signaler un bug

1. Verifiez que le bug n'a pas deja ete signale dans les [issues existantes](../../issues).
2. Ouvrez une nouvelle issue en utilisant le template **Bug Report**.
3. Incluez : etapes de reproduction, comportement attendu vs. observe, version Flutter/Dart, appareil et OS.
4. Si le bug concerne l'accessibilite (lecteur d'ecran, contraste, navigation), ajoutez le prefixe `[a11y]` dans le titre.

### Proposer une fonctionnalite

1. Ouvrez une issue avec le template **Feature Request**.
2. Decrivez le besoin utilisateur (pas seulement la solution technique).
3. Precisez quel handicap ou scenario d'accessibilite est concerne.
4. Les propositions alignees avec le [PRD](_bmad-output/planning-artifacts/prd.md) ont plus de chances d'etre acceptees.

### Soumettre du code

1. Consultez les issues ouvertes, en priorite celles avec le label `good first issue`.
2. Commentez l'issue pour signaler que vous travaillez dessus.
3. Suivez le [workflow Git](#workflow-git) ci-dessous.
4. Soumettez une pull request vers `develop`.

### Ameliorer la documentation

Les corrections de typos, ameliorations de documentation et traductions sont toujours bienvenues. Pas besoin d'issue prealable pour les corrections mineures.

### Tester l'accessibilite

Vous utilisez un lecteur d'ecran (VoiceOver, TalkBack) ? Vos retours sont precieux ! Ouvrez une issue avec le label `accessibility` pour signaler tout probleme d'accessibilite rencontre.

---

## Prerequis

| Outil | Version minimale | Notes |
|-------|-----------------|-------|
| Flutter | 3.41+ | `flutter --version` pour verifier |
| Dart | 3.11+ | Inclus dans Flutter |
| Android SDK | API 31 (Android 12), target 35 | Configurer `ANDROID_HOME` |
| Xcode | 15+ | macOS uniquement, pour les builds iOS |
| Git | 2.30+ | |

---

## Installation locale

```bash
# 1. Fork le depot sur GitHub, puis clonez votre fork
git clone https://github.com/<votre-username>/kita.git
cd kita

# 2. Ajoutez le depot principal comme remote
git remote add upstream https://github.com/<org>/kita.git

# 3. Installez les dependances Flutter
flutter pub get

# 4. Lancez la generation de code (Drift, Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 5. Verifiez que tout fonctionne
flutter test
dart analyze --fatal-infos
```

### Variables d'environnement recommandees

```bash
# Ajouter a votre ~/.zshrc ou ~/.bashrc
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
```

Si `flutter test` passe et `dart analyze` est clean, vous etes prets a contribuer.

---

## Architecture du projet

Kita suit une architecture **feature-first + Clean Architecture** :

```
lib/
├── core/           # DI, config, erreurs, theme, utilitaires (protege)
├── features/
│   ├── ai/         # Router IA, providers, classifier, fallback
│   ├── io/         # Camera, audio, haptique, localisation, mouvement
│   ├── memory/     # Base de donnees Drift, vault, collections
│   ├── plugins/    # Systeme de plugins, sandbox, registry
│   ├── onboarding/ # Flux d'accueil, detection accessibilite
│   ├── shell/      # Interface principale (KitaShell, KitaOrb)
│   └── settings/   # Preferences, profil
├── shared/         # Widgets partages
└── platform/       # Code natif bridge (Android/iOS)
```

Chaque feature contient trois couches :
- **`domain/`** : Entites, interfaces, logique metier pure (pas de dependances externes)
- **`data/`** : Implementations, sources de donnees, conversions
- **`presentation/`** : Widgets, state management (Riverpod)

Pour les documents d'architecture complets, voir :
- [`_bmad-output/planning-artifacts/architecture.md`](_bmad-output/planning-artifacts/architecture.md)
- [`_bmad-output/planning-artifacts/ux-design-specification.md`](_bmad-output/planning-artifacts/ux-design-specification.md)

---

## Conventions de code

### Nommage

| Element | Convention | Exemple |
|---------|-----------|---------|
| Classes | `UpperCamelCase` | `AiRouterImpl` |
| Fichiers | `snake_case` | `ai_router_impl.dart` |
| Variables | `lowerCamelCase` | `fallbackChain` |
| Providers | `lowerCamelCase` + suffixe `Provider` | `aiRouterProvider` |
| Plugins | ID reverse domain | `com.kita.describe` |

### Gestion des erreurs

```dart
// Pattern obligatoire : sealed class KitaFailure + Result<T>
// Jamais de throw non type

// INTERDIT
throw Exception('quelque chose a rate');

// CORRECT
return const Result.failure(
  AIProviderFailure(
    userMessage: 'Service temporairement indisponible',
    logMessage: 'Claude API timeout after 30s',
  ),
);
```

Utilisez `is TimeoutException` (type check) et non `e.toString().contains(...)` (string matching).

### Logging

- Format : `[Source] Message`
- **Zero PII dans les logs** : jamais de coordonnees GPS, noms, emails, cles API, tokens.

```dart
// INTERDIT
_log.info('Position: ${pos.latitude}, ${pos.longitude}');
_log.info('Utilisateur: ${user.name}');

// CORRECT
_log.info('Position acquired successfully');
_log.info('User profile loaded');
```

### State management

- Riverpod 3.0 avec `Notifier`, `AsyncNotifier`, `Mutation` (patterns modernes).
- Ne pas utiliser `StateProvider` ou `StateNotifierProvider` (legacy).
- `AsyncValue<T>` pour tous les etats asynchrones.

### Tests

- Chaque PR doit inclure des tests pour le code ajoute/modifie.
- Au moins **1 test d'integration reel** (pas uniquement des mocks).
- Les tests verifient des **comportements**, pas juste que le code compile.
- Utilisez `test()` + `ProviderContainer` pour les tests de state/stream (pas `testWidgets`).
- Reservez `testWidgets` aux tests necessitant `tester.pumpWidget()` ou `tester.tap()`.
- Couverture minimale : **80%** sur le code ajoute.

### Linting

Le projet utilise `flutter_lints` avec des regles supplementaires et `riverpod_lint`. Avant de soumettre :

```bash
dart analyze --fatal-infos
```

Doit etre **clean** (zero warning, zero info).

### Fichiers generes

Les fichiers `*.g.dart`, `*.freezed.dart` et `*.drift.dart` sont generes et **ne doivent pas etre commites**. Regenerez-les avec :

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Regles d'accessibilite

L'accessibilite n'est pas optionnelle dans Kita. C'est la raison d'etre du projet. Toute contribution avec du UI **doit** respecter ces regles. Standard cible : **WCAG 2.1 AA+**.

### Semantics obligatoires

Chaque widget interactif doit etre enveloppe dans un `Semantics` widget avec un label descriptif :

```dart
Semantics(
  label: 'Decrire la scene devant moi',
  button: true,
  child: GestureDetector(
    onTap: onDescribe,
    child: /* ... */,
  ),
)
```

### Contrastes

- Texte normal : ratio minimum **4.5:1** (WCAG AA)
- Texte large / elements d'interface : ratio minimum **3:1**

### Zones tactiles

- Taille minimale : **48x48 pixels**
- Actions critiques : **56x56 pixels**

### Reduction de mouvement

```dart
// Toujours verifier avant d'animer
final reduceMotion = MediaQuery.of(context).disableAnimations;
if (!reduceMotion) {
  // lancer l'animation
}
```

### Tests Semantics obligatoires

```dart
testWidgets('MonWidget a un label Semantics descriptif', (tester) async {
  await tester.pumpWidget(/* ... */);

  final semantics = tester.getSemantics(find.byType(MonWidget));
  expect(semantics.label, contains('description'));
});
```

### Principes generaux

- Navigation clavier et lecteur d'ecran fonctionnelle
- Pas de contenu uniquement visuel sans alternative textuelle
- Textes en francais avec accents corrects (`detectee`, pas `detectee`)

---

## Workflow Git

### Branches

```
main          <- branche stable, protegee (PRs uniquement)
develop       <- integration continue
feature/xxx   <- nouvelles fonctionnalites
fix/xxx       <- corrections de bugs
```

| Type | Format | Base | Cible |
|------|--------|------|-------|
| Feature | `feature/description-courte` | `develop` | `develop` |
| Bug fix | `fix/description-courte` | `develop` | `develop` |
| Hotfix | `hotfix/description-courte` | `main` | `main` + `develop` |

### Processus

```bash
# 1. Synchronisez votre fork
git fetch upstream
git checkout develop
git merge upstream/develop

# 2. Creez votre branche
git checkout -b feature/ma-feature

# 3. Developpez (commits atomiques, messages clairs)
git commit -m "Add scene description retry logic"

# 4. Avant de pousser, verifiez
dart analyze --fatal-infos
flutter test

# 5. Poussez et ouvrez une PR vers develop
git push origin feature/ma-feature
```

### Commits

- Messages en anglais, au present imperatif : `Add`, `Fix`, `Update`, `Remove`
- Un commit = un changement logique
- Titre PR : format conventionnel `type: description courte`
  - `feat: ajouter detection obstacles en mode portrait`
  - `fix: corriger accent manquant dans justification camera`
  - `test: ajouter tests accessibilite pour KitaOrb`

### Merge

Les PR sont **squash-merged** vers `develop`. Ciblez toujours `develop`, jamais `main` directement.

---

## Processus de review

Chaque PR necessite au minimum 1 approbation avant merge. Nous visons une premiere reponse sous **7 jours**.

### Checklist automatique

- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe (tous les tests)
- [ ] Pas de fichiers generes commites (`*.g.dart`, `*.freezed.dart`)

### Review humaine

- [ ] Le code suit les conventions du projet
- [ ] Les tests couvrent les cas importants
- [ ] L'accessibilite est respectee (si UI modifie)
- [ ] Zero PII dans les logs
- [ ] Les ressources sont correctement disposees (`ref.onDispose`, `dispose()`)
- [ ] Pas de race conditions (guards sur callbacks haute frequence)
- [ ] Exception handling par type check (`is`), pas string matching

Les PR avec des tests complets et une bonne description sont traitees en priorite.

---

## Deploiement

### Versioning

```
version: {major}.{minor}.{patch}+{build}
```

Les releases sont declenchees par tags git sur `main` :

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Questions et support

- **Issues GitHub :** pour signaler un bug ou proposer une feature
- **Discussions GitHub :** pour les questions generales
- **Label `accessibility` :** pour les questions liees a l'accessibilite
- **Label `good first issue` :** pour les nouveaux contributeurs

---

*Kita est developpe avec passion pour les personnes en situation de handicap. Chaque ligne de code doit servir Marie.*
