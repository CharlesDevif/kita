# Story 1.3: State management Riverpod 3.0 et DI

Status: ready-for-dev

## Story

As a **developpeur**,
I want **Riverpod 3.0 configure comme state management global avec les providers de base**,
So that **chaque feature peut injecter ses dependances de maniere typesafe et coherente**.

**Depends on:** Story 1.2 (Core patterns — KitaFailure, Result<T>, Logger)

## Acceptance Criteria

1. **Given** les core patterns existent (Story 1.2) **When** Riverpod 3.0 est configure **Then** `main.dart` wraps l'app dans `ProviderScope`

2. **And** chaque feature declare ses providers dans `features/{feature}/di/providers.dart` (pas de fichier centralise — Riverpod 3.0 `@riverpod` gere le registre via code generation)

3. **And** `core/di/service_locator.dart` initialise les services au boot

4. **And** les conventions de naming sont suivies : `{feature}Provider`, `{feature}NotifierProvider`, `{feature}ServiceProvider`

5. **And** un test unitaire verifie que `ProviderScope` demarre sans erreur

6. **And** `build_runner` est configure pour la code generation Riverpod

## Tasks / Subtasks

### Task 1 : Verifier les prerequis (AC: #1)

- [ ] Verifier que Story 1.2 est done (core patterns existent : `core/errors/kita_failure.dart`, `core/errors/result.dart`, `core/utils/logger.dart`)
- [ ] Verifier que `flutter_riverpod: ^3.2.1`, `riverpod_annotation: ^4.0.2`, `riverpod_generator: ^4.0.3` sont dans `pubspec.yaml`
- [ ] Verifier que `analysis_options.yaml` contient les exclusions `*.g.dart`

### Task 2 : Configurer le service locator (AC: #3)

- [ ] Creer `lib/core/di/service_locator.dart` avec une classe `ServiceLocator` contenant une methode statique `Future<void> init()` qui initialise les services au boot
- [ ] Le `ServiceLocator.init()` doit :
  - Appeler `WidgetsFlutterBinding.ensureInitialized()`
  - Etre appele dans `main()` avant `runApp()`
  - Logger `[ServiceLocator] Boot started` et `[ServiceLocator] Boot complete` via le logger unifie (Story 1.2)
  - Retourner un `Future<void>` pour permettre l'init async (ex: ouverture DB dans stories suivantes)
- [ ] Le service locator est un point d'entree procedural — il ne gere PAS l'injection Riverpod. Son role est d'initialiser les ressources imperative (binding, DB, etc.) avant que les providers Riverpod prennent le relais.

### Task 3 : Mettre a jour main.dart avec ProviderScope + ServiceLocator (AC: #1, #3)

- [ ] Modifier `lib/main.dart` :
  - `main()` doit etre `async`
  - Appeler `await ServiceLocator.init()` avant `runApp()`
  - Wrapper `KitaApp()` dans `ProviderScope`
- [ ] Code cible :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita/core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.init();
  runApp(const ProviderScope(child: KitaApp()));
}
```

**Note :** `WidgetsFlutterBinding.ensureInitialized()` doit etre appele en tout premier dans `main()` car c'est requis pour tout appel async avant `runApp()`. Le `ServiceLocator.init()` peut aussi le faire en interne de maniere idempotente.

### Task 4 : Creer les providers de base de la feature core (AC: #2, #4)

- [ ] Creer `lib/core/di/providers.dart` — providers globaux core avec code generation
- [ ] Ce fichier doit contenir :
  - Un provider `appConfig` avec `@Riverpod(keepAlive: true)` qui expose la configuration app (pour l'instant, un placeholder retournant un objet simple)
  - Un provider `logger` avec `@Riverpod(keepAlive: true)` qui expose l'instance KitaLogger de Story 1.2
- [ ] Ajouter la directive `part 'providers.g.dart';` en haut du fichier
- [ ] Importer `package:riverpod_annotation/riverpod_annotation.dart`
- [ ] Code cible :

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kita/core/utils/logger.dart';

part 'providers.g.dart';

/// Configuration applicative globale.
/// Sera enrichi quand app_config.dart existera (Story 1.2+).
@Riverpod(keepAlive: true)
KitaLogger kitaLogger(Ref ref) {
  return KitaLogger('Core');
}

@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) {
  return AppConfig();
}
```

**Note sur le naming :** Avec `riverpod_generator`, le nom du provider genere est derive du nom de la fonction/classe. Une fonction `kitaLogger` generera `kitaLoggerProvider`. Une classe `AppConfigNotifier` generera `appConfigNotifierProvider`. Respecter le pattern : `lowerCamelCase` pour les fonctions, `UpperCamelCase` pour les classes Notifier.

### Task 5 : Creer des providers exemples dans une feature (AC: #2, #4)

- [ ] Creer `lib/features/shell/di/providers.dart` comme exemple de providers par feature
- [ ] Ce fichier doit demontrer les 3 patterns principaux :
  1. **Provider simple** (lecture seule, `@riverpod` minuscule = autoDispose) :
  ```dart
  @riverpod
  String shellGreeting(Ref ref) {
    return 'Kita — Initialisation OK';
  }
  ```
  2. **Notifier** (etat mutable, `@riverpod` sur classe) :
  ```dart
  @riverpod
  class ShellState extends _$ShellState {
    @override
    String build() => 'idle';

    void updateState(String newState) {
      state = newState;
    }
  }
  ```
  3. **AsyncNotifier** (etat async, `@riverpod` sur classe) :
  ```dart
  @riverpod
  class ShellInitializer extends _$ShellInitializer {
    @override
    Future<bool> build() async {
      // Placeholder — sera remplace par la vraie init dans E8
      return true;
    }
  }
  ```
- [ ] Ajouter `part 'providers.g.dart';` et les imports necessaires
- [ ] Ce fichier sert de **template de reference** pour les agents des phases 2+ — ils suivront ce modele pour leurs features

### Task 6 : Configurer build_runner pour Riverpod code generation (AC: #6)

- [ ] Executer `dart run build_runner build --delete-conflicting-outputs` pour generer les fichiers `.g.dart`
- [ ] Verifier que les fichiers generes sont crees :
  - `lib/core/di/providers.g.dart`
  - `lib/features/shell/di/providers.g.dart`
- [ ] Verifier que `dart analyze` est clean apres generation
- [ ] Verifier que les fichiers `.g.dart` sont bien dans `.gitignore`
- [ ] **Ne PAS creer de `build.yaml`** sauf si necessaire — les defaults de `riverpod_generator` sont corrects pour Kita (suffix `Provider`, pas de prefix)

### Task 7 : Ecrire les tests unitaires (AC: #5)

- [ ] Creer `test/core/di/service_locator_test.dart` :
  - Test que `ServiceLocator.init()` s'execute sans erreur
  - Test que l'appel est idempotent (peut etre appele plusieurs fois sans crash)

- [ ] Creer `test/core/di/providers_test.dart` :
  - Test que `ProviderScope` demarre sans erreur
  - Test que les providers core sont accessibles via `ProviderContainer`
  - Code pattern :
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:kita/core/di/providers.dart';

  void main() {
    test('ProviderScope starts without error', () {
      final container = ProviderContainer.test();
      // No addTearDown needed — ProviderContainer.test() auto-disposes
      // Accessing a provider should not throw
      expect(() => container.read(kitaLoggerProvider), returnsNormally);
    });
  }
  ```

- [ ] Creer `test/features/shell/di/providers_test.dart` :
  - Test que les providers shell (simple, Notifier, AsyncNotifier) sont accessibles
  - Test que `ShellState` Notifier peut modifier son etat
  - Test que `ShellInitializer` AsyncNotifier retourne une `AsyncValue`

- [ ] Executer `flutter test` — tous les tests doivent passer

### Task 8 : Verification finale

- [ ] `dart analyze` clean (0 warnings, 0 errors)
- [ ] `flutter test` pass
- [ ] `dart run build_runner build --delete-conflicting-outputs` sans erreur
- [ ] Les fichiers `.g.dart` ne sont PAS tracked par git
- [ ] Verifier que `main.dart` contient `ProviderScope`
- [ ] Verifier que `core/di/service_locator.dart` existe et fonctionne
- [ ] Verifier la structure :
  ```
  lib/core/di/
  ├── providers.dart          # Providers globaux core (@riverpod)
  └── service_locator.dart    # Init services au boot
  lib/features/shell/di/
  └── providers.dart          # Providers exemples feature (@riverpod)
  ```

## Dev Notes

### Architecture — Riverpod 3.0 dans Clean Architecture

```
presentation/          data/              domain/
     |                   |                   |
  ref.watch()     implementations      interfaces
     |                   |                   |
     +------- Providers Riverpod --------+
              (font le pont)
```

Les providers Riverpod vivent dans `{feature}/di/providers.dart` pour chaque feature. Ils importent depuis `domain/` et `data/` pour creer le lien. Les widgets de `presentation/` ne lisent que les providers — jamais d'import direct de `data/`.

### Convention providers — naming strict

| Type | Annotation | Naming fonction/classe | Provider genere |
|------|-----------|----------------------|----------------|
| Simple (read-only) | `@riverpod` (minuscule) | `featureName` | `featureNameProvider` |
| Simple keepAlive | `@Riverpod(keepAlive: true)` | `featureName` | `featureNameProvider` |
| Notifier | `@riverpod` sur classe | `FeatureNotifier` | `featureNotifierProvider` |
| AsyncNotifier | `@riverpod` sur classe | `FeatureLoader` | `featureLoaderProvider` |
| Notifier keepAlive | `@Riverpod(keepAlive: true)` sur classe | `FeatureService` | `featureServiceProvider` |

### Regles d'usage dans les widgets

- `ref.watch(provider)` — dans `build()`, reactif
- `ref.read(provider)` — dans les callbacks (`onPressed`, etc.), non-reactif
- `ref.listen(provider, callback)` — pour les side effects (navigation, snackbar)
- `ref.invalidate(provider)` — pour forcer un refresh

### Placement des providers

| Scope | Fichier | Contenu |
|-------|---------|---------|
| Global (core services) | `lib/core/di/providers.dart` | Logger, AppConfig, services transversaux |
| Feature | `lib/features/{feature}/di/providers.dart` | Providers specifiques a la feature |

**Jamais de provider defini dans un widget.** Toujours dans un fichier `providers.dart` dedie.

### ServiceLocator vs Riverpod

Le `ServiceLocator` est un simple initialiseur procedural appele dans `main()`. Il ne remplace PAS Riverpod :

| Aspect | ServiceLocator | Riverpod Providers |
|--------|---------------|-------------------|
| Role | Init imperative au boot | DI reactive + state management |
| Quand | Avant `runApp()` | Pendant la vie de l'app |
| Quoi | WidgetsBinding, DB open, etc. | Services, notifiers, state |
| Testable | Directement | Via `ProviderContainer` |

### Code generation — commandes

```bash
# Generation one-shot (CI, pre-commit)
dart run build_runner build --delete-conflicting-outputs

# Watch mode (dev local)
dart run build_runner watch --delete-conflicting-outputs
```

### Fichiers generes — convention

Pour chaque fichier `providers.dart` avec des annotations `@riverpod`, build_runner genere un `providers.g.dart` dans le meme repertoire. Ce fichier contient :
- Les definitions de `Provider` / `NotifierProvider` / `AsyncNotifierProvider`
- Les classes `_$NotifierName` (base classes pour les Notifiers)

**Ne jamais editer les fichiers `.g.dart`.** Ils sont regeneres a chaque `build_runner`.

### Propriete des fichiers

Cette story cree/modifie uniquement des fichiers dans le scope E1 (Fondation) :
- `lib/main.dart` (modification)
- `lib/core/di/service_locator.dart` (creation)
- `lib/core/di/providers.dart` (creation)
- `lib/features/shell/di/providers.dart` (creation — template reference)
- `test/core/di/service_locator_test.dart` (creation)
- `test/core/di/providers_test.dart` (creation)
- `test/features/shell/di/providers_test.dart` (creation)

## Technical Intelligence

### Riverpod 3.0 — Versions verifiees (fevrier 2026)

| Package | Version | Role |
|---------|---------|------|
| `flutter_riverpod` | `^3.2.1` | Widgets Flutter (ProviderScope, ConsumerWidget, etc.) |
| `riverpod_annotation` | `^4.0.2` | Annotations `@riverpod`, `@Riverpod(keepAlive: true)`, `@mutation` |
| `riverpod_generator` | `^4.0.3` | Code generation — genere les providers depuis les annotations |
| `riverpod_lint` | `^3.1.3` | Lint rules specifiques Riverpod (via analysis_server_plugin) |

### API @riverpod — syntaxe exacte

**Provider simple (autoDispose) :**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'my_file.g.dart';

@riverpod
String myValue(Ref ref) {
  return 'hello';
}
// Genere : myValueProvider (autoDispose par defaut)
```

**Provider keepAlive :**
```dart
@Riverpod(keepAlive: true)
String myPersistentValue(Ref ref) {
  return 'stays alive';
}
// Genere : myPersistentValueProvider (pas autoDispose)
```

**Notifier (etat mutable synchrone) :**
```dart
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}
// Genere : counterProvider (NotifierProvider)
```

**AsyncNotifier (etat mutable async) :**
```dart
@riverpod
class UserProfile extends _$UserProfile {
  @override
  Future<Profile> build() async {
    return await fetchProfile();
  }

  Future<void> updateName(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => saveProfile(name));
  }
}
// Genere : userProfileProvider (AsyncNotifierProvider)
```

**Notifier keepAlive :**
```dart
@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  Map<String, dynamic> build() => {};
}
// Genere : appSettingsProvider (keepAlive, pas autoDispose)
```

### @mutation (experimental, codegen only)

**Status :** Experimental dans Riverpod 3.0. API peut changer sans major bump.

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async => fetchTodos();

  @mutation
  Future<void> addTodo(String title) async {
    await api.createTodo(title);
    ref.invalidateSelf();
  }
}
// Genere un MutationState trackant loading/error/success pour addTodo
```

**Recommandation Kita :** Ne PAS utiliser `@mutation` dans la fondation (Story 1.3). Les agents des phases 2+ peuvent l'utiliser si l'API se stabilise. Pour l'instant, utiliser le pattern `AsyncValue.guard()` pour les side-effects.

### ProviderScope — configuration avancee

```dart
ProviderScope(
  overrides: [
    // Overrides pour tests ou configuration runtime
    myProvider.overrideWithValue('test-value'),
  ],
  observers: [
    // Observers pour logging/debugging
    if (kDebugMode) ProviderLogger(),
  ],
  child: KitaApp(),
)
```

**Pour Kita Story 1.3 :** Utiliser `ProviderScope` sans overrides ni observers. Les observers seront ajoutes dans des stories ulterieures si necessaire.

### ProviderContainer.test() pour les tests

```dart
void main() {
  test('provider test', () {
    final container = ProviderContainer.test(
      overrides: [
        // Overrides pour isoler les tests
      ],
    );
    // Auto-dispose a la fin du test — pas besoin de addTearDown

    final value = container.read(myProvider);
    expect(value, 'expected');
  });
}
```

### build_runner — configuration defaults

`riverpod_generator ^4.0.3` supporte un fichier `build.yaml` optionnel avec ces options :

```yaml
targets:
  $default:
    builders:
      riverpod_generator:
        options:
          provider_name_prefix: ""        # default: ""
          provider_name_suffix: "Provider" # default: "Provider"
```

**Pour Kita :** Les defaults sont corrects. Pas besoin de `build.yaml`. Le suffix `Provider` est automatiquement ajoute, ce qui correspond a la convention Kita (`aiRouterProvider`, `shellStateProvider`).

### Eager initialization pattern

Si un provider doit etre initialise au demarrage (ex: DB connection), utiliser un widget `Consumer` sous `ProviderScope` :

```dart
class EagerInitialization extends ConsumerWidget {
  const EagerInitialization({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them
    ref.watch(databaseProvider);
    ref.watch(appConfigProvider);
    return child;
  }
}
```

**Pour Kita Story 1.3 :** Pas d'eager initialization necessaire. Le `ServiceLocator.init()` gere l'init imperative. Les providers Riverpod seront initialises lazily (defaut Riverpod).

## Pitfalls & Gotchas

### 1. Ne PAS utiliser les legacy providers

`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` sont dans `legacy.dart` depuis Riverpod 3.0. **Interdit dans Kita.** Utiliser exclusivement `@riverpod` + code generation.

Si du code est copie d'un tutorial pre-3.0, verifier qu'il n'utilise pas ces patterns.

### 2. `@riverpod` (minuscule) vs `@Riverpod(keepAlive: true)` (majuscule)

- `@riverpod` (minuscule) = autoDispose (defaut recommande). Le provider est detruit quand plus personne ne l'ecoute.
- `@Riverpod(keepAlive: true)` (majuscule avec parametre) = keepAlive. Le provider reste en memoire tant que l'app vit.

**Regle Kita :** Utiliser `keepAlive: true` uniquement pour les services singletons (Logger, AppConfig, DB, AIRouter). Tous les autres providers sont autoDispose.

### 3. Les Notifiers sont recrees a chaque rebuild

Depuis Riverpod 3.0, les Notifiers sont recrees quand un provider dont ils dependent est invalide. **Ne PAS stocker de ressources long-lived** (subscriptions, controllers) directement dans un Notifier sans cleanup dans `ref.onDispose()`.

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  String build() {
    final sub = someStream.listen((_) {});
    ref.onDispose(() => sub.cancel()); // OBLIGATOIRE
    return 'initial';
  }
}
```

### 4. `Ref` n'a plus de type parameter dans Riverpod 3.0

Avant : `FutureProviderRef<String>`, `AutoDisposeRef<int>`, etc.
Maintenant : juste `Ref`. Plus simple mais attention aux migrations de code.

### 5. Les fichiers .g.dart doivent etre regeneres apres modification

Chaque modification d'un fichier avec `@riverpod` necessite de relancer `build_runner`. En dev local, utiliser `watch` mode :

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Si les tests echouent avec `MissingStubError` ou `UnimplementedError` apres modification, c'est probablement que les `.g.dart` ne sont pas a jour.

### 6. ProviderScope doit etre le widget racine

`ProviderScope` doit etre au-dessus de tout widget qui utilise `ref`. Dans `main.dart`, il wrappe directement `KitaApp`. Ne PAS le placer plus bas dans l'arbre.

### 7. `ProviderContainer.test()` pour les tests

Dans les tests unitaires, utiliser `ProviderContainer.test()` (pas `ProviderContainer()`). Cette factory auto-dispose le container a la fin du test — pas besoin de `addTearDown` :

```dart
final container = ProviderContainer.test();
// Auto-dispose a la fin du test — pas besoin de addTearDown(container.dispose)
```

**Attention :** `ProviderContainer()` (sans `.test()`) ne dispose PAS automatiquement. C'est un piege frequent dans les tests Riverpod 3.0.

### 8. riverpod_lint — utilise analysis_server_plugin, PAS custom_lint

Le projet utilise `analysis_server_plugin` (officiel Dart team) via la section `plugins:` dans `analysis_options.yaml`. `custom_lint` est abandonne et NE DOIT PAS etre ajoute au projet. La configuration actuelle dans `analysis_options.yaml` est correcte :

```yaml
plugins:
  riverpod_lint: ^3.1.3
```

### 9. Auto-retry par defaut dans Riverpod 3.0

Riverpod 3.0 active par defaut un auto-retry (200ms → 6.4s backoff exponentiel) pour les providers en erreur. Pour le desactiver sur un provider specifique, utiliser le parametre `retry` de l'annotation `@Riverpod` :

```dart
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
class MyProvider extends _$MyProvider {
  @override
  Future<Data> build() async {
    return fetchData();
  }
}
```

Pour desactiver globalement au niveau du `ProviderScope` :

```dart
ProviderScope(
  retry: (retryCount, error) => null,
  child: MyApp(),
)
```

**Attention :** `ref.autoRetry(enabled: false)` n'existe PAS dans l'API Riverpod 3.0. L'auto-retry se configure uniquement via le parametre `retry` de `@Riverpod()` ou au niveau `ProviderScope`.

**Pour Kita :** Laisser l'auto-retry par defaut pour la plupart des providers. Le desactiver uniquement sur les providers qui gèrent leur propre retry (ex: FallbackChain dans E2).

### 10. Ne PAS creer de build.yaml pour l'instant

Les defaults de `riverpod_generator` (prefix vide, suffix "Provider") correspondent exactement aux conventions Kita. Un `build.yaml` n'est necessaire que si on veut changer ces defaults.

### 11. Les providers generes ne sont plus des constantes dans riverpod_generator 4.0

Breaking change par rapport aux versions anterieures : les providers generes par `riverpod_generator ^4.0.x` ne sont plus `const`. Du code comme `const [myProvider]` ou `const ProviderScope(overrides: [myProvider.overrideWith(...)])` ne compilera pas. Supprimer le `const` devant les collections ou expressions contenant des providers generes.

### 12. Riverpod 3.0 wrappe les exceptions dans `ProviderException`

Quand un provider lance une exception, Riverpod 3.0 la wrappe dans un `ProviderException`. Les catch handlers qui attrapent des types specifiques (ex: `catch (e) { if (e is MyCustomException) }`) doivent unwrapper le `ProviderException` pour acceder a l'exception originale via `ProviderException.exception`. Sinon, le type matching echouera silencieusement.

### 13. Subscriptions auto-paused pour les widgets invisibles

Riverpod 3.0 met automatiquement en pause les subscriptions (`ref.watch`, `ref.listen`) des widgets qui ne sont plus visibles a l'ecran (ex: onglet en arriere-plan, page sous une autre dans le Navigator). Cela ameliore les performances mais peut surprendre si un widget depend d'un side-effect continu. Pour les providers qui doivent rester actifs meme quand le widget est invisible, utiliser `ref.read()` dans un callback ou un provider `keepAlive`.

## References

- Architecture: `_bmad-output/planning-artifacts/architecture.md` — sections "State Management", "Riverpod Providers", "Code Organization", "Communication Patterns"
- Epics: `_bmad-output/planning-artifacts/epics.md` — Story 1.3
- Story 1.1 (done): `_bmad-output/implementation-artifacts/1-1-initialisation-projet-flutter-structure-feature-first.md`
- Story 1.2 (prerequis): core patterns, errors, logger
- Riverpod docs: https://riverpod.dev/docs/whats_new (Riverpod 3.0 what's new)
- Riverpod code generation: https://riverpod.dev/docs/concepts/about_code_generation
- riverpod_generator pub.dev: https://pub.dev/packages/riverpod_generator
- App initialization with Riverpod: https://codewithandrea.com/articles/robust-app-initialization-riverpod/
- Eager initialization: https://riverpod.dev/docs/how_to/eager_initialization

## Dev Agent Record

### Agent Model Used

(a remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
