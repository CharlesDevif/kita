# Contributing to Kita

Kita est un compagnon IA mobile d'assistance au handicap visuel, auditif et cognitif. Nous accueillons les contributions qui améliorent l'accessibilité, la qualité du code et l'expérience utilisateur.

**Persona cible :** Marie, 28 ans, aveugle de naissance, utilisatrice VoiceOver. Chaque contribution doit être pensée pour elle en premier.

---

## Prérequis

| Outil | Version minimale | Notes |
|-------|-----------------|-------|
| Flutter | 3.41.2 | `flutter --version` pour vérifier |
| Dart | 3.11.0 | Inclus dans Flutter |
| Android SDK | API 31 (Android 12), target 35 | Configurer `ANDROID_HOME` |
| Xcode | 15+ | macOS uniquement, pour les builds iOS |
| Ruby | 3.1+ | Pour Fastlane |
| Bundler | dernière version | `gem install bundler` |

---

## Setup de l'environnement de développement

```bash
# 1. Cloner le repository
git clone https://github.com/[org]/kita.git
cd kita

# 2. Installer les dépendances Flutter
flutter pub get

# 3. Générer les fichiers de code (Drift, Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 4. Lancer les tests pour vérifier que tout fonctionne
flutter test

# 5. (Optionnel) Installer les dépendances Fastlane
bundle install
```

### Variables d'environnement recommandées

```bash
# Ajouter à votre ~/.zshrc ou ~/.bashrc
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
```

---

## Workflow de contribution

### Branches

```
main          ← branche stable, protégée (PRs uniquement)
develop       ← intégration continue
epic/e{N}-{nom} ← branche par epic/agent depuis develop
```

**Pour une contribution :**
```bash
git checkout develop
git pull origin develop
git checkout -b fix/description-courte-du-fix
# ... vos modifications ...
git push origin fix/description-courte-du-fix
# Ouvrir une PR vers develop
```

### Pull Requests

- **Target :** `develop` (jamais directement vers `main`)
- **Merge strategy :** squash-merge (1 commit par story/feature)
- **Titre :** format conventionnel `type: description courte`
  - `feat: ajouter détection obstacles en mode portrait`
  - `fix: corriger accent manquant dans justification caméra`
  - `test: ajouter tests accessibilité pour KitaOrb`
  - `docs: mettre à jour politique de confidentialité`
- **Corps de PR :** inclure le Dev Agent Record si applicable

### Code review

Chaque PR nécessite au minimum 1 approbation avant merge. Le reviewer vérifie :
- [ ] Les tests passent (`flutter test`)
- [ ] L'analyse est clean (`dart analyze --fatal-infos`)
- [ ] L'Accessibility Tax est appliqué (voir section Accessibilité)
- [ ] Aucun PII dans les logs
- [ ] Les ressources sont libérées (`ref.onDispose`, `dispose()`)

---

## Standards de qualité — OBLIGATOIRES

### 1. Analyse statique

```bash
dart analyze --fatal-infos lib/
```

Doit retourner **"No issues found."** sans exception. Les warnings bloquent la PR.

### 2. Tests

```bash
flutter test
flutter test --coverage  # pour mesurer la couverture
```

- Couverture minimale : **80%** sur le code ajouté
- Chaque story doit avoir au moins **1 test d'intégration** avec dépendances réelles (ex: Drift in-memory, pas de mock DB)
- Les tests vérifient des **comportements**, pas juste que le code compile

### 3. Génération de code

Après modification de fichiers `*.drift`, `*.freezed.dart`, ou providers Riverpod annotés :

```bash
dart run build_runner build --delete-conflicting-outputs
```

Ne **jamais commiter** les fichiers générés (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`).

### 4. Zéro PII dans les logs

```dart
// INTERDIT
_log.info('Position: ${pos.latitude}, ${pos.longitude}');
_log.info('Utilisateur: ${user.name}');

// CORRECT
_log.info('Position acquired successfully');
_log.info('User profile loaded');
```

---

## Accessibilité — Exigence non négociable

**Standard :** WCAG 2.1 AA+ sur tous les écrans et composants.

L'"Accessibility Tax" s'applique à **toute story avec UI** — pas d'exception.

### Checklist Accessibility Tax

```dart
// 1. Semantics wrapper sur chaque widget interactif
Semantics(
  label: 'Décrire la scène devant moi',
  button: true,
  child: GestureDetector(
    onTap: onDescribe,
    child: /* ... */,
  ),
)

// 2. Touch targets >= 48x48px (56x56px pour actions critiques)
SizedBox(
  width: 56,
  height: 56,
  child: /* bouton critique */,
)

// 3. Contrastes
// texte normal : >= 4.5:1
// texte large / éléments UI : >= 3:1
```

### Tests Semantics obligatoires

```dart
testWidgets('MonWidget a un label Semantics descriptif', (tester) async {
  await tester.pumpWidget(/* ... */);

  final semantics = tester.getSemantics(find.byType(MonWidget));
  expect(semantics.label, contains('description'));
});
```

### Réduction de mouvement

```dart
// Toujours vérifier avant d'animer
final reduceMotion = MediaQuery.of(context).disableAnimations;
if (!reduceMotion) {
  // lancer l'animation
}
```

---

## Architecture

Kita suit une architecture **feature-first + Clean Architecture** :

```
lib/
├── core/           # DI, config, errors, theme, utils (protégé)
├── features/
│   ├── ai/         # AI Router, providers, classifier, fallback
│   ├── io/         # Camera, audio, haptic, location, motion
│   ├── memory/     # Drift store, vault, collections
│   ├── plugins/    # Plugin interface, registry, sandbox
│   ├── onboarding/ # Flow complet, detection accessibilité
│   ├── shell/      # KitaShell, KitaOrb, KitaInput
│   └── settings/   # Preferences, profil, forget
├── shared/         # Widgets partagés, multi_modal/
└── platform/       # Code natif bridge
```

**Règle :** Chaque agent/contributeur ne touche **que** son feature directory.

Pour les documents d'architecture complets, voir :
- [`_bmad-output/planning-artifacts/architecture.md`](_bmad-output/planning-artifacts/architecture.md)
- [`_bmad-output/planning-artifacts/ux-design-specification.md`](_bmad-output/planning-artifacts/ux-design-specification.md)

---

## Gestion des erreurs

```dart
// Pattern obligatoire : sealed class KitaFailure + Result<T>
// Jamais de throw non typé

// INTERDIT
throw Exception('quelque chose a raté');

// CORRECT
return const Result.failure(
  AIProviderFailure(
    userMessage: 'Service temporairement indisponible',
    logMessage: 'Claude API timeout after 30s',
  ),
);
```

---

## Déploiement

### Versioning

```
version: {major}.{minor}.{patch}+{build}
```

Pattern de release via tags git :
```bash
# Après merge dans main
git tag v1.0.0
git push origin v1.0.0
# → déclenche automatiquement les workflows build-android et build-ios
```

Pour incrémenter la version :
```bash
bundle exec fastlane bump_version type:patch  # ou minor/major
```

### Fastlane

```bash
# Beta Android (Play Store internal testing)
bundle exec fastlane android beta_android

# Beta iOS (TestFlight)
bundle exec fastlane ios beta_ios
```

Voir [`fastlane/README.md`](fastlane/README.md) pour les prérequis détaillés.

---

## Questions et support

- **Issues GitHub :** [Signaler un bug ou proposer une feature](https://github.com/[org]/kita/issues)
- **Discussions :** [Forum de la communauté](https://github.com/[org]/kita/discussions)
- **Accessibilité :** Pour les questions liées à l'accessibilité, ouvrir une issue avec le tag `accessibility`
- **RGPD :** privacy@kita.app

---

*Kita est développé avec passion pour les personnes en situation de handicap. Chaque ligne de code doit servir Marie.*
