# Story 1.5: Navigation go_router et ecrans placeholder

Status: ready-for-dev

## Story

As a **developpeur**,
I want **go_router configure avec les 6 routes et des ecrans placeholder**,
So that **la navigation de l'app est fonctionnelle et chaque agent peut implementer son ecran independamment**.

## Acceptance Criteria

1. **Given** le design system est configure (Story 1.4) **When** go_router est configure **Then** `lib/app.dart` contient la classe `KitaApp` avec `MaterialApp.router` et `routerConfig` pointant vers la configuration go_router

2. **And** les 6 routes sont definies :
   - `/` → `KitaShellPlaceholder` (ecran principal)
   - `/onboarding` → `OnboardingPlaceholder`
   - `/settings` → `SettingsPlaceholder`
   - `/settings/plugins` → `PluginManagerPlaceholder`
   - `/settings/memory` → `MemoryViewPlaceholder`
   - `/settings/forget` → `ForgetPlaceholder`

3. **And** chaque route affiche un ecran placeholder fonctionnel avec un `Scaffold`, un titre identifiant la page, et des `Semantics` labels pour l'accessibilite

4. **And** la navigation entre les routes fonctionne correctement :
   - `context.go()` pour la navigation top-level (ex: `/` → `/onboarding`, `/` → `/settings`) — remplace la pile
   - `context.push()` pour la navigation intra-settings (ex: `/settings` → `/settings/plugins`) — empile l'ecran, `pop()` revient a `/settings`

5. **And** un test verifie que chaque route resout correctement vers le bon ecran placeholder

## Tasks / Subtasks

- [ ] **Task 1 : Creer `lib/core/navigation/router.dart` — configuration go_router** (AC: #1, #2)
  - [ ] Creer le fichier `lib/core/navigation/router.dart`
  - [ ] Definir un provider Riverpod `routerProvider` qui expose l'instance `GoRouter`
  - [ ] Configurer les 6 routes avec `GoRoute` :
    - `/` → `KitaShellPlaceholder`
    - `/onboarding` → `OnboardingPlaceholder`
    - `/settings` → `SettingsPlaceholder`
    - `/settings/plugins` → `PluginManagerPlaceholder`
    - `/settings/memory` → `MemoryViewPlaceholder`
    - `/settings/forget` → `ForgetPlaceholder`
  - [ ] Les routes `/settings/*` sont des sous-routes imbriquees de `/settings`
  - [ ] Definir `initialLocation: '/'`
  - [ ] Ajouter `debugLogDiagnostics: kDebugMode` (import `package:flutter/foundation.dart`)

- [ ] **Task 2 : Creer les 6 ecrans placeholder** (AC: #3)
  - [ ] `lib/features/shell/presentation/kita_shell_placeholder.dart` — placeholder pour KitaShell (route `/`)
  - [ ] `lib/features/onboarding/presentation/onboarding_placeholder.dart` — placeholder pour Onboarding (route `/onboarding`)
  - [ ] `lib/features/settings/presentation/settings_placeholder.dart` — placeholder pour Settings (route `/settings`)
  - [ ] `lib/features/settings/presentation/plugin_manager_placeholder.dart` — placeholder pour Plugin Manager (route `/settings/plugins`)
  - [ ] `lib/features/settings/presentation/memory_view_placeholder.dart` — placeholder pour Memory View (route `/settings/memory`)
  - [ ] `lib/features/settings/presentation/forget_placeholder.dart` — placeholder pour Forget (route `/settings/forget`)
  - [ ] Chaque placeholder est un `StatelessWidget` avec :
    - Un `Scaffold` avec `AppBar` (sauf KitaShell qui est l'ecran principal)
    - Un titre texte identifiant la page (ex: "Kita Shell", "Settings", etc.)
    - Un `Semantics` wrapper avec label descriptif
    - Des boutons de navigation vers les autres pages (pour tester la navigation)
    - Un bouton retour dans les sous-pages settings

- [ ] **Task 3 : Creer `lib/app.dart` — KitaApp avec MaterialApp.router** (AC: #1)
  - [ ] Creer `lib/app.dart`
  - [ ] La classe `KitaApp` est un `ConsumerWidget` (Riverpod)
  - [ ] Utiliser `MaterialApp.router(routerConfig: ref.watch(routerProvider))`
  - [ ] Appliquer le theme Kita si disponible (Story 1.4), sinon theme minimal
  - [ ] `debugShowCheckedModeBanner: false`
  - [ ] Titre : `'Kita'`

- [ ] **Task 4 : Mettre a jour `lib/main.dart`** (AC: #1)
  - [ ] Remplacer l'ancien `KitaApp` dans `main.dart` par l'import depuis `app.dart`
  - [ ] `main.dart` ne contient que `runApp(const ProviderScope(child: KitaApp()))`
  - [ ] Supprimer la definition inline de `KitaApp` qui existe actuellement dans `main.dart`

- [ ] **Task 5 : Tests de routage** (AC: #5)
  - [ ] Creer `test/core/navigation/router_test.dart`
  - [ ] Test : chaque route (`/`, `/onboarding`, `/settings`, `/settings/plugins`, `/settings/memory`, `/settings/forget`) resout vers le bon widget placeholder
  - [ ] Test : navigation de `/` vers `/settings` fonctionne
  - [ ] Test : navigation imbriquee `/settings` → `/settings/plugins` fonctionne
  - [ ] Test : retour depuis `/settings/plugins` ramene a `/settings`
  - [ ] Utiliser `ProviderScope` + `MaterialApp.router` dans les tests pour avoir le contexte Riverpod
  - [ ] Verifier la presence de `Semantics` labels dans chaque placeholder

- [ ] **Task 6 : Verification finale** (tous ACs)
  - [ ] `dart analyze` clean (0 warning, 0 error)
  - [ ] `flutter test` pass
  - [ ] Navigation manuelle testee entre toutes les routes
  - [ ] Mettre a jour `sprint-status.yaml` → `1-5-navigation-go-router-ecrans-placeholder: done`

## Dev Notes

### Architecture — Routing dans le projet Kita

D'apres `architecture.md`, la navigation est **minimale** — Kita est conversation-first, pas menu-first. L'ecran principal `/` (KitaShell) represente 95% du temps d'utilisation. Les settings sont des pages secondaires.

**Table de routage definie dans l'architecture :**

| Route | Ecran | Usage |
|-------|-------|-------|
| `/` | KitaShell (Living Aura) | Ecran principal — 95% du temps |
| `/onboarding` | OnboardingFlow | Premier lancement |
| `/settings` | SettingsScreen | Preferences, profil, plugins |
| `/settings/plugins` | PluginManager | Gestion plugins |
| `/settings/memory` | MemoryView | "Qu'est-ce que tu sais sur moi" |
| `/settings/forget` | ForgetScreen | Droit a l'oubli |

### Placement des fichiers

| Fichier | Chemin |
|---------|--------|
| Configuration router | `lib/core/navigation/router.dart` |
| KitaApp | `lib/app.dart` |
| Shell placeholder | `lib/features/shell/presentation/kita_shell_placeholder.dart` |
| Onboarding placeholder | `lib/features/onboarding/presentation/onboarding_placeholder.dart` |
| Settings placeholder | `lib/features/settings/presentation/settings_placeholder.dart` |
| Plugin manager placeholder | `lib/features/settings/presentation/plugin_manager_placeholder.dart` |
| Memory view placeholder | `lib/features/settings/presentation/memory_view_placeholder.dart` |
| Forget placeholder | `lib/features/settings/presentation/forget_placeholder.dart` |
| Tests router | `test/core/navigation/router_test.dart` |

### Conventions Riverpod pour le router

Le router doit etre expose comme un provider Riverpod. Utiliser un simple `Provider` (non-generated, pas async) pour le `GoRouter` car c'est un singleton de configuration :

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const KitaShellPlaceholder(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPlaceholder(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPlaceholder(),
        routes: [
          GoRoute(
            path: 'plugins',
            builder: (context, state) => const PluginManagerPlaceholder(),
          ),
          GoRoute(
            path: 'memory',
            builder: (context, state) => const MemoryViewPlaceholder(),
          ),
          GoRoute(
            path: 'forget',
            builder: (context, state) => const ForgetPlaceholder(),
          ),
        ],
      ),
    ],
  );
});
```

**Important :** Les sous-routes de `/settings` utilisent des paths relatifs (`plugins`, `memory`, `forget`) — PAS des paths absolus (`/settings/plugins`). go_router les concatene automatiquement.

### Conventions accessibilite (Accessibility Tax)

Chaque placeholder doit inclure :
- `Semantics` wrapper avec un label descriptif sur le widget racine
- Touch targets de navigation >= 48x48px
- Texte avec contraste >= 4.5:1 (utiliser les tokens du theme si disponible)

Exemple de placeholder conforme :

```dart
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ecran des parametres Kita',
      child: Scaffold(
        appBar: AppBar(title: const Text('Parametres')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Settings — Placeholder'),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/plugins'),
                  child: const Text('Plugins'),
                ),
              ),
              // ... autres boutons de navigation
            ],
          ),
        ),
      ),
    );
  }
}
```

### Navigation — context.go() vs context.push()

- Utiliser `context.go('/path')` pour la navigation **top-level** (remplacement de pile) :
  - `/` → `/onboarding` : `context.go('/onboarding')`
  - `/` → `/settings` : `context.go('/settings')`
- Utiliser `context.push('/path')` pour les **sous-pages settings** (empile un ecran, `pop()` revient en arriere) :
  - `/settings` → `/settings/plugins` : `context.push('/settings/plugins')`
  - `/settings` → `/settings/memory` : `context.push('/settings/memory')`
  - `/settings` → `/settings/forget` : `context.push('/settings/forget')`
- **Pourquoi cette distinction ?** `context.go()` reconstruit toute la pile de navigation. Pour les sous-pages settings, on veut que le bouton retour (`pop()`) ramene a `/settings`. Avec `context.go('/settings/plugins')`, la pile est reconstruite et le retour peut ne pas fonctionner comme attendu si go_router ne reconstruit pas `/settings` dans la pile. `context.push()` garantit que `/settings` reste dans la pile.
- Import : `import 'package:go_router/go_router.dart';` (fournit les extensions sur `BuildContext`)

### Structure de KitaApp (app.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita/core/navigation/router.dart';

class KitaApp extends ConsumerWidget {
  const KitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kita',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
```

### Testing patterns

Pour tester les routes go_router, creer un helper qui wrappe le widget dans `ProviderScope` + `MaterialApp.router` :

```dart
Widget createTestApp({String initialLocation = '/'}) {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: initialLocation,
        routes: [ /* memes routes que router.dart */ ],
      ),
    ),
  );
}

testWidgets('/ displays KitaShellPlaceholder', (tester) async {
  await tester.pumpWidget(createTestApp(initialLocation: '/'));
  await tester.pumpAndSettle();
  expect(find.byType(KitaShellPlaceholder), findsOneWidget);
});
```

**Alternative plus propre** — reutiliser le provider :

```dart
Widget createTestApp({String initialLocation = '/'}) {
  return ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(
        GoRouter(
          initialLocation: initialLocation,
          routes: [ /* ... */ ],
        ),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        return MaterialApp.router(
          routerConfig: ref.watch(routerProvider),
        );
      },
    ),
  );
}
```

**Approche recommandee** : extraire la liste de routes dans une constante ou fonction reutilisable, utilisable dans le provider ET dans les tests. Par exemple, definir `kitaRoutes` comme liste de `RouteBase` importable.

### Gestion des routes inconnues — onException / errorBuilder

Le `GoRouter` devrait inclure un handler pour les routes inconnues (equivalent d'une page 404). Sans cela, naviguer vers une route non definie provoque une exception non geree. Deux options :

**Option 1 — `onException` (recommandee)** : handler global qui recoit le `GoRouterState` et le `GoRouter`, permet de rediriger vers une page d'erreur ou vers `/` :

```dart
GoRouter(
  // ...
  onException: (context, state, router) {
    router.go('/'); // redirection vers l'ecran principal
  },
)
```

**Option 2 — `errorBuilder`** : construit un widget d'erreur affiche directement :

```dart
GoRouter(
  // ...
  errorBuilder: (context, state) => Semantics(
    label: 'Page non trouvee',
    child: Scaffold(
      body: Center(child: Text('Route inconnue : ${state.uri}')),
    ),
  ),
)
```

Pour le MVP, `onException` avec redirection vers `/` est suffisant. L'important est d'eviter les exceptions non gerees si une route invalide est atteinte.

## Technical Intelligence

### go_router 17.1.0 (fevrier 2026)

| Package | Version | Min SDK |
|---------|---------|---------|
| `go_router` | `17.1.0` | Flutter 3.32 / Dart 3.8 |

**Deja present dans `pubspec.yaml`** avec `go_router: ^17.1.0`.

**Changelog go_router 17.x :**
- **17.0.0 (breaking)** : `ShellRoute` notifie les observers du root GoRouter par defaut. Nouveau parametre `notifyRootObserver` sur `GoRoute`, `ShellRoute`, `StatefulShellRoute`. Ce n'est pas impactant pour cette story (pas de ShellRoute ni d'observers).
- **17.0.1** : Fix `onEnter` blocking qui causait une perte de pile de navigation. Min SDK mis a jour vers Flutter 3.32/Dart 3.8.
- **17.1.0** : Ajoute `TypedQueryParameter` pour les `TypedGoRoute`. Non pertinent pour cette story.

**API principale utilisee :**

```dart
GoRouter({
  required List<RouteBase> routes,
  String initialLocation = '/',
  bool debugLogDiagnostics = false,
  GoRouterRedirect? redirect,          // pour les guards futurs (onboarding)
  GoExceptionHandler? onException,     // gestion erreurs navigation
  Listenable? refreshListenable,       // pour reagir aux changements d'etat
})
```

```dart
GoRoute({
  required String path,
  GoRouterWidgetBuilder? builder,
  GoRouterPageBuilder? pageBuilder,
  GoRouterRedirect? redirect,
  List<RouteBase> routes = const [],  // sous-routes imbriquees
})
```

**Navigation programmatique :**
- `context.go('/path')` — navigation declarative, reconstruit la pile
- `context.push('/path')` — empile un ecran
- `context.pop()` — depile
- `context.goNamed('name')` — par nom de route (optionnel ici)
- Extensions disponibles via `import 'package:go_router/go_router.dart';`

### Riverpod 3.0 — Provider pour GoRouter

En Riverpod 3.0, un simple `Provider<GoRouter>` est suffisant pour le router. Pas besoin de `@riverpod` code generation pour un singleton de configuration :

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(/* ... */);
});
```

Ce pattern est simple et ne necessite pas `build_runner`. Le router est cree une seule fois et reutilise.

**Note pour le futur :** Quand les redirect guards seront implementes (onboarding, authentification), le `routerProvider` pourra etre mis a jour avec `ref.watch()` sur un provider d'etat et `refreshListenable` pour reagir aux changements.

### MaterialApp.router

`MaterialApp.router` est le constructeur utilise pour l'integration go_router :

```dart
MaterialApp.router(
  routerConfig: goRouterInstance,
  title: 'Kita',
  theme: kitaTheme, // si disponible (Story 1.4)
  debugShowCheckedModeBanner: false,
)
```

**`routerConfig`** est le seul parametre necessaire. Il remplace les anciens `routerDelegate` + `routeInformationParser` + `routeInformationProvider` qui sont remplacés par `routerConfig` (pas d'annotation `@Deprecated` formelle, mais supersédés dans la pratique — `routerConfig` est l'approche recommandée).

### Tests go_router — patterns valides

Pour tester les routes dans un `testWidgets` :

1. Creer un `GoRouter` avec `initialLocation` pour la route a tester
2. Wrapper dans `MaterialApp.router(routerConfig: router)`
3. `pumpWidget` puis `pumpAndSettle` (pour les animations de navigation)
4. `expect(find.byType(TargetWidget), findsOneWidget)`

Pour tester la navigation :
1. `pumpWidget` avec `initialLocation: '/settings'`
2. `tap` sur un bouton qui navigue vers `/settings/plugins`
3. `pumpAndSettle`
4. `expect(find.byType(PluginManagerPlaceholder), findsOneWidget)`

## Pitfalls & Gotchas

### 1. Sous-routes : paths relatifs obligatoires

Les sous-routes de `GoRoute` doivent utiliser des paths **relatifs** (sans slash initial) :

```dart
// BON
GoRoute(
  path: '/settings',
  routes: [
    GoRoute(path: 'plugins', ...),  // resolu en /settings/plugins
  ],
)

// MAUVAIS — ERREUR au runtime
GoRoute(
  path: '/settings',
  routes: [
    GoRoute(path: '/plugins', ...),  // FAUX : go_router leve une assertion
  ],
)
```

### 2. `debugLogDiagnostics` — desactiver en production

`debugLogDiagnostics: true` log chaque navigation dans la console. C'est utile en dev mais doit etre conditionnel :

```dart
GoRouter(
  debugLogDiagnostics: kDebugMode,
  // ...
)
```

Importer `kDebugMode` depuis `package:flutter/foundation.dart`.

### 3. KitaApp doit etre ConsumerWidget, pas StatelessWidget

Pour acceder au `routerProvider` Riverpod, `KitaApp` doit etre un `ConsumerWidget` avec `ref.watch(routerProvider)`. Un `StatelessWidget` n'a pas acces au `ref`.

### 4. Ne PAS reconstruire le GoRouter a chaque build

Le `GoRouter` doit etre cree UNE SEULE fois. Avec Riverpod, `Provider<GoRouter>` garantit cela car il est lazy et cache. Ne pas utiliser `ref.read()` dans le build — utiliser `ref.watch()` qui ne declenche pas de rebuild car le provider ne change jamais.

### 5. `pumpAndSettle` obligatoire dans les tests de navigation

Apres un `context.go()` ou `context.push()` dans un test, il faut appeler `await tester.pumpAndSettle()` pour attendre que les animations de transition se terminent. Sans cela, le nouveau widget n'est pas encore visible.

### 6. Tests — attention au `ProviderScope`

Les tests go_router avec Riverpod necessitent un `ProviderScope` parent. Si le test utilise `MaterialApp.router` directement sans `ProviderScope`, les `ConsumerWidget` dans les placeholders echoueront avec `ProviderScope not found`.

### 7. `main.dart` — ne plus definir KitaApp en inline

Le `main.dart` actuel contient une definition inline de `KitaApp` avec un simple `MaterialApp`. Cette story la remplace par l'import de `app.dart`. S'assurer de supprimer completement l'ancienne definition pour eviter les conflits de noms.

### 8. Propriete des fichiers — cette story est dans E1

Cette story fait partie de E1 (Fondation). Elle peut donc modifier `lib/core/` et creer `lib/app.dart`. Les fichiers dans `features/*/presentation/` sont des placeholders qui seront remplaces par les agents des phases suivantes.

### 9. ShellRoute non utilise pour cette story

L'architecture Kita n'utilise PAS de `ShellRoute` pour les 6 routes. L'ecran KitaShell (`/`) est un ecran a part entiere, pas un shell persistant pour les sous-routes settings. Les routes settings sont des ecrans independants empiles. `ShellRoute` sera potentiellement utilise dans E8 (Shell UI) si KitaShell doit persister pendant la navigation settings.

### 10. go_router 17.0.0 breaking change — `notifyRootObserver`

`ShellRoute` notifie maintenant les observers du root par defaut. Ce n'est **pas impactant** pour cette story car nous n'utilisons ni `ShellRoute` ni d'observers. Mais le dev agent doit en etre conscient pour les stories futures.

### 11. GoRouter disposal dans les tests — listener leaks

Creer plusieurs instances `GoRouter` dans les tests sans les disposer cause des fuites de listeners (le `GoRouter` s'abonne a `WidgetsBinding` et `PlatformDispatcher`). Cela peut provoquer des warnings `setState() called after dispose()` ou des tests instables.

**Solution :** Disposer chaque `GoRouter` cree dans les tests :

```dart
testWidgets('route resolves correctly', (tester) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: kitaRoutes,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // ...
});
```

**Bonne pratique :** Creer un helper `createTestRouter()` qui retourne le `GoRouter` et enregistrer `addTearDown(router.dispose)` systematiquement dans chaque test. Cela evite les fuites meme si le test echoue.

## References

- [Source: _bmad-output/planning-artifacts/architecture.md#Frontend Architecture — Routing : go_router]
- [Source: _bmad-output/planning-artifacts/architecture.md#Code Organization — app.dart]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5]
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules]
- [Source: pub.dev/packages/go_router — version 17.1.0]
- [Source: pub.dev/documentation/go_router/latest/go_router/ShellRoute-class.html]

## Dev Agent Record

### Agent Model Used

(a remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
