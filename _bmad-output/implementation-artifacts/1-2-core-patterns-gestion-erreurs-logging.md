# Story 1.2: Core patterns — Gestion d'erreurs et logging

Status: ready-for-dev

## Story

As a **developpeur**,
I want **les patterns de gestion d'erreurs (KitaFailure, Result<T>) et le logger unifies**,
So that **tous les agents utilisent les memes patterns d'erreur et de logging des le depart**.

## Acceptance Criteria

1. **Given** le projet Flutter est initialise (Story 1.1) **When** les core patterns sont implementes **Then** `core/errors/kita_failure.dart` contient la sealed class `KitaFailure` avec les sous-types : `NetworkFailure`, `AIProviderFailure`, `PluginFailure`, `StorageFailure`, `PermissionFailure`

2. **And** chaque `KitaFailure` expose `userMessage` (message affichable a l'utilisateur via ProfileAdapter) et `logMessage` (message pour les logs internes, sans PII)

3. **And** `core/errors/result.dart` contient le type `Result<T>` avec `Success(data)` et `Failure(error)` — sealed class avec pattern matching exhaustif

4. **And** `core/utils/logger.dart` implemente le format `[Source] Message` avec les niveaux debug/info/warning/error/critical

5. **And** le logger ne contient JAMAIS de PII (test unitaire verifiant le pattern)

6. **And** `core/config/app_config.dart` contient les constantes (timeouts, limites, TTL)

7. **And** `core/config/environment.dart` gere les flavors dev/staging/prod

8. **And** `core/constants/durations.dart` et `core/constants/limits.dart` sont crees

## Tasks / Subtasks

### Task 1: Refactorer `KitaFailure` sealed class (AC: #1, #2)

Le fichier `lib/core/errors/kita_failure.dart` existe deja avec une implementation placeholder de Story 1.1. Il faut le refactorer pour matcher les ACs.

- [ ] Remplacer le contenu de `lib/core/errors/kita_failure.dart` :
  - Sealed class `KitaFailure` avec deux champs `final` : `String userMessage` et `String logMessage`
  - Conserver un champ optionnel `cause` (`Object?`) et `stackTrace` (`StackTrace?`) pour le debug
  - Sous-types requis (tous `final class extends KitaFailure`) :
    - `NetworkFailure` — echecs reseau (timeout, DNS, connexion)
    - `AIProviderFailure` — echecs providers IA (rate limit, API error, model unavailable)
    - `PluginFailure` — echecs plugin (sandbox violation, timeout, crash)
    - `StorageFailure` — echecs stockage (DB, secure storage, fichier)
    - `PermissionFailure` — echecs permissions (camera, micro, GPS, notification)
  - Conserver `UnexpectedFailure` pour les erreurs non typees (catch-all)
  - **NE PAS** conserver `DatabaseFailure` ni `IOFailure` (remplaces par `StorageFailure` et sous-types plus specifiques)
- [ ] Chaque sous-type DOIT prendre `userMessage` et `logMessage` comme parametres requis dans le constructeur
- [ ] Ajouter un constructeur factory nomme pratique sur chaque sous-type pour les cas frequents (ex: `NetworkFailure.timeout()`, `AIProviderFailure.rateLimited()`)

**Exemple de code cible :**

```dart
sealed class KitaFailure {
  const KitaFailure({
    required this.userMessage,
    required this.logMessage,
    this.cause,
    this.stackTrace,
  });

  /// Message safe pour l'utilisateur (passe au ProfileAdapter).
  final String userMessage;

  /// Message technique pour les logs internes — JAMAIS de PII.
  final String logMessage;

  /// Cause originale (exception, error).
  final Object? cause;

  /// Stack trace pour le debug.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $logMessage';
}

final class NetworkFailure extends KitaFailure {
  const NetworkFailure({
    required super.userMessage,
    required super.logMessage,
    super.cause,
    super.stackTrace,
  });

  factory NetworkFailure.timeout({String? endpoint}) => NetworkFailure(
    userMessage: 'La connexion a expire. Verifiez votre reseau.',
    logMessage: 'Network timeout${endpoint != null ? ' on $endpoint' : ''}',
  );

  factory NetworkFailure.noConnection() => const NetworkFailure(
    userMessage: 'Pas de connexion internet.',
    logMessage: 'No network connection available',
  );
}

final class AIProviderFailure extends KitaFailure {
  const AIProviderFailure({
    required super.userMessage,
    required super.logMessage,
    this.providerId,
    super.cause,
    super.stackTrace,
  });

  final String? providerId;

  factory AIProviderFailure.rateLimited(String providerId) =>
      AIProviderFailure(
        userMessage: 'Le service IA est temporairement surcharge.',
        logMessage: 'Rate limited by provider $providerId',
        providerId: providerId,
      );

  factory AIProviderFailure.invalidApiKey(String providerId) =>
      AIProviderFailure(
        userMessage: 'La cle API est invalide. Verifiez dans les reglages.',
        logMessage: 'Invalid API key for provider $providerId',
        providerId: providerId,
      );

  factory AIProviderFailure.modelUnavailable(String providerId,
          String model) =>
      AIProviderFailure(
        userMessage: 'Le modele IA est indisponible.',
        logMessage: 'Model $model unavailable on provider $providerId',
        providerId: providerId,
      );
}

final class PluginFailure extends KitaFailure {
  const PluginFailure({
    required super.userMessage,
    required super.logMessage,
    this.pluginId,
    super.cause,
    super.stackTrace,
  });

  final String? pluginId;

  factory PluginFailure.sandboxViolation(String pluginId,
          String permission) =>
      PluginFailure(
        userMessage: 'Le plugin a tente un acces non autorise.',
        logMessage:
            'Sandbox violation: plugin $pluginId tried $permission',
        pluginId: pluginId,
      );

  factory PluginFailure.timeout(String pluginId) => PluginFailure(
    userMessage: 'Le plugin n\'a pas repondu a temps.',
    logMessage: 'Plugin $pluginId timed out',
    pluginId: pluginId,
  );
}

final class StorageFailure extends KitaFailure {
  const StorageFailure({
    required super.userMessage,
    required super.logMessage,
    super.cause,
    super.stackTrace,
  });

  factory StorageFailure.databaseError(String operation) =>
      StorageFailure(
        userMessage: 'Erreur de stockage interne.',
        logMessage: 'Database error during $operation',
      );

  factory StorageFailure.secureStorageError(String operation) =>
      StorageFailure(
        userMessage: 'Erreur d\'acces au stockage securise.',
        logMessage: 'Secure storage error during $operation',
      );
}

final class PermissionFailure extends KitaFailure {
  const PermissionFailure({
    required super.userMessage,
    required super.logMessage,
    this.permission,
    super.cause,
    super.stackTrace,
  });

  final String? permission;

  factory PermissionFailure.denied(String permission) =>
      PermissionFailure(
        userMessage:
            'Permission refusee. Activez-la dans les reglages.',
        logMessage: 'Permission denied: $permission',
        permission: permission,
      );

  factory PermissionFailure.permanentlyDenied(String permission) =>
      PermissionFailure(
        userMessage:
            'Permission bloquee. Allez dans les reglages systeme.',
        logMessage: 'Permission permanently denied: $permission',
        permission: permission,
      );
}

final class UnexpectedFailure extends KitaFailure {
  const UnexpectedFailure({
    required super.logMessage,
    super.cause,
    super.stackTrace,
  }) : super(
            userMessage: 'Une erreur inattendue est survenue.');
}
```

### Task 2: Refactorer `Result<T>` sealed class (AC: #3)

Le fichier `lib/core/errors/result.dart` existe deja. Ameliorer l'API.

- [ ] Conserver la structure sealed class existante (`Result<T>`, `Success<T>`, `Failure<T>`)
- [ ] Ajouter les methodes utilitaires manquantes :
  - `Result<U> map<U>(U Function(T) transform)` — transforme la valeur si Success
  - `Result<U> flatMap<U>(Result<U> Function(T) transform)` — chaine les Results
  - `T getOrElse(T Function(KitaFailure) orElse)` — deja present, conserver
  - `T? getOrNull()` — deja present, conserver
  - `Result<T> mapFailure(KitaFailure Function(KitaFailure) transform)` — transforme l'erreur
  - `void when({required void Function(T) success, required void Function(KitaFailure) failure})` — callback pattern
  - `bool get isSuccess` / `bool get isFailure` — deja presents, conserver
- [ ] Ajouter un helper top-level `Result<T> runCatching<T>(T Function() block)` qui wrappe les exceptions en `UnexpectedFailure`
- [ ] Ajouter un helper async `Future<Result<T>> runCatchingAsync<T>(Future<T> Function() block)`

**Exemple de code cible pour les ajouts :**

```dart
// Dans Result<T>:
Result<U> map<U>(U Function(T value) transform) {
  return switch (this) {
    Success(:final value) => Result.success(transform(value)),
    Failure(:final failure) => Result.failure(failure),
  };
}

Result<U> flatMap<U>(Result<U> Function(T value) transform) {
  return switch (this) {
    Success(:final value) => transform(value),
    Failure(:final failure) => Result.failure(failure),
  };
}

Result<T> mapFailure(KitaFailure Function(KitaFailure failure) transform) {
  return switch (this) {
    Success() => this,
    Failure(:final failure) => Result.failure(transform(failure)),
  };
}

void when({
  required void Function(T value) success,
  required void Function(KitaFailure failure) failure,
}) {
  switch (this) {
    case Success(:final value):
      success(value);
    case Failure(:final failure):
      failure(failure);
  }
}

// Top-level helpers:
Result<T> runCatching<T>(T Function() block) {
  try {
    return Result.success(block());
  } catch (e, stack) {
    return Result.failure(
      UnexpectedFailure(logMessage: e.toString(), cause: e, stackTrace: stack),
    );
  }
}

Future<Result<T>> runCatchingAsync<T>(Future<T> Function() block) async {
  try {
    return Result.success(await block());
  } catch (e, stack) {
    return Result.failure(
      UnexpectedFailure(logMessage: e.toString(), cause: e, stackTrace: stack),
    );
  }
}
```

### Task 3: Refactorer `KitaLogger` (AC: #4, #5)

Le fichier `lib/core/utils/logger.dart` existe deja. Ameliorer pour ajouter le niveau `critical` et le filtrage PII.

- [ ] Ajouter le niveau `critical` (level: 1200 — au-dessus de `error` 1000)
- [ ] Ajouter un parametre optionnel `error` et `stackTrace` sur les methodes `warning`, `error`, `critical`
- [ ] Ajouter une methode statique `KitaLogger.setMinLevel(LogLevel level)` pour filtrer les logs en production
- [ ] Creer un enum `LogLevel { debug, info, warning, error, critical }` dans le meme fichier
- [ ] En mode prod, le min level devrait etre `warning` par defaut
- [ ] Le logger DOIT utiliser `dart:developer log()` (pas `print()`, pas `package:logging`)
- [ ] **NE PAS** ajouter de dependance externe — `dart:developer` suffit pour le MVP

**Pattern de logging attendu :**
```
[AIRouter] Routing to cloud-powerful         // debug
[Plugin.Describe] Photo captured             // info
[AIRouter] Cloud timeout, fallback to local  // warning
[Plugin.Alert] Model loading failed, retry   // error
[Fallback] All providers failed, brute alert // critical
```

**Exemple de code cible :**

```dart
import 'dart:developer' as dev;

enum LogLevel implements Comparable<LogLevel> {
  debug(0),
  info(800),
  warning(900),
  error(1000),
  critical(1200);

  const LogLevel(this.value);
  final int value;

  @override
  int compareTo(LogLevel other) => value.compareTo(other.value);
}

class KitaLogger {
  const KitaLogger._(this._source);

  factory KitaLogger(String source) => KitaLogger._(source);

  final String _source;

  static LogLevel _minLevel = LogLevel.debug;

  /// Set minimum log level. In prod, set to LogLevel.warning.
  static void setMinLevel(LogLevel level) => _minLevel = level;

  void debug(String message) =>
      _log(message, level: LogLevel.debug);

  void info(String message) =>
      _log(message, level: LogLevel.info);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.warning, error: error, stackTrace: stackTrace);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);

  void critical(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.critical, error: error, stackTrace: stackTrace);

  void _log(
    String message, {
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < _minLevel.value) return;
    dev.log(
      '[$_source] $message',
      level: level.value,
      name: 'kita',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
```

### Task 4: Creer `app_config.dart` (AC: #6)

- [ ] Creer `lib/core/config/app_config.dart`
- [ ] Classe abstraite `AppConfig` avec des constantes statiques :
  - Timeouts : `aiCloudTimeout` (3s), `aiLocalTimeout` (500ms), `pluginTimeout` (10s), `networkTimeout` (10s)
  - TTL cache : `cacheTtlCritical` (0 — jamais cache), `cacheTtlUrgent` (30s), `cacheTtlStandard` (5min), `cacheTtlBackground` (1h)
  - Episode cleanup : `episodeRetention` (30 jours)
  - Version : `appVersion` ("0.1.0"), `minAndroidSdk` (31), `minIosVersion` ("16.0")
  - **Note :** les quotas/seuils ressources (`maxRetryCount`, `maxPluginMemoryMb`, `maxRamUsageMb`, `maxBatteryPercentPerHour`) sont dans `Limits` (source canonique)

**Exemple de code cible :**

```dart
abstract final class AppConfig {
  // AI Provider timeouts
  static const Duration aiCloudTimeout = Duration(seconds: 3);
  static const Duration aiLocalTimeout = Duration(milliseconds: 500);
  static const Duration pluginTimeout = Duration(seconds: 10);
  static const Duration networkTimeout = Duration(seconds: 10);

  // Cache TTL by request priority
  static const Duration cacheTtlCritical = Duration.zero; // never cached
  static const Duration cacheTtlUrgent = Duration(seconds: 30);
  static const Duration cacheTtlStandard = Duration(minutes: 5);
  static const Duration cacheTtlBackground = Duration(hours: 1);

  // Episode cleanup
  static const Duration episodeRetention = Duration(days: 30);

  // Note: Resource quotas/thresholds (maxRetryCount, maxPluginMemoryMb,
  // maxRamUsageMb, maxBatteryPercentPerHour) are in Limits (canonical source).

  // App identity
  static const String appVersion = '0.1.0';
  static const int minAndroidSdk = 31;
  static const String minIosVersion = '16.0';
}
```

### Task 5: Creer `environment.dart` (AC: #7)

- [ ] Creer `lib/core/config/environment.dart`
- [ ] Enum `Environment { dev, staging, prod }`
- [ ] Classe `EnvironmentConfig` qui lit l'environnement depuis `--dart-define=ENV=dev`
- [ ] Utiliser `const String.fromEnvironment('ENV', defaultValue: 'dev')` pour lire le flavor
- [ ] Exposer : `isDebug`, `isProduction`, `logLevel` (debug pour dev, warning pour prod), `name`

**Exemple de code cible :**

```dart
enum Environment {
  dev,
  staging,
  prod;

  static Environment fromString(String value) {
    return Environment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Environment.dev,
    );
  }
}

class EnvironmentConfig {
  const EnvironmentConfig._();

  static const String _envString =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static final Environment current = Environment.fromString(_envString);

  static bool get isDev => current == Environment.dev;
  static bool get isStaging => current == Environment.staging;
  static bool get isProd => current == Environment.prod;
  static bool get isDebug => !isProd;

  static LogLevel get logLevel => switch (current) {
    Environment.dev => LogLevel.debug,
    Environment.staging => LogLevel.info,
    Environment.prod => LogLevel.warning,
  };
}
```

### Task 6: Creer `durations.dart` et `limits.dart` (AC: #8)

- [ ] Creer `lib/core/constants/durations.dart` — constantes Duration pour animations, debounce, polling
- [ ] Creer `lib/core/constants/limits.dart` — constantes numeriques pour quotas, tailles, seuils

**`durations.dart` — valeurs cibles :**

```dart
abstract final class KitaDurations {
  // Animation durations (from UX spec)
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration transition = Duration(milliseconds: 300);
  static const Duration stateChange = Duration(milliseconds: 500);

  // Debounce
  static const Duration inputDebounce = Duration(milliseconds: 300);
  static const Duration sttDebounce = Duration(milliseconds: 200);

  // Polling / refresh
  static const Duration batteryCheckInterval = Duration(minutes: 5);
  static const Duration memoryCleanupInterval = Duration(hours: 6);

  // STT/TTS performance targets
  static const Duration sttMaxLatency = Duration(milliseconds: 200);
  static const Duration ttsMaxLatency = Duration(milliseconds: 100);

  // Cold start target
  static const Duration coldStartTarget = Duration(seconds: 3);

  // Alert latency target
  static const Duration alertMaxLatency = Duration(milliseconds: 50);

  // Describe E2E target
  static const Duration describeMaxLatency = Duration(seconds: 5);
}
```

**`limits.dart` — valeurs cibles :**

```dart
abstract final class Limits {
  // RAM
  static const int maxRamUsageMb = 200;
  static const int maxPluginMemoryMb = 50;

  // Battery
  static const int maxBatteryPercentPerHour = 5;
  static const int lowBatteryThreshold = 20;

  // Plugin quotas
  static const int maxPluginApiCallsPerMinute = 10;
  static const int maxPluginStorageMb = 20;
  static const int maxActivePlugins = 5;

  // AI
  static const int maxRetryCount = 3;
  static const int maxConcurrentAiRequests = 3;

  // Memory domains
  // Note: episode retention TTL is in AppConfig.episodeRetention (canonical source).
  static const int maxEpisodesInMemory = 1000;
  static const int maxPersons = 500;

  // UI
  static const double minTouchTarget = 48.0;
  static const double criticalTouchTarget = 56.0;
  static const double minTextContrast = 4.5;
  static const double minUiContrast = 3.0;

  // Text scaling
  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;
}
```

### Task 7: Ecrire les tests unitaires (AC: #1, #2, #3, #4, #5)

- [ ] Creer `test/core/errors/kita_failure_test.dart` :
  - Test que chaque sous-type expose `userMessage` et `logMessage` non-vides
  - Test exhaustive switch sur `KitaFailure` (compile-time via sealed)
  - Test factory constructeurs (`.timeout()`, `.rateLimited()`, etc.)
  - Test `toString()` retourne le `logMessage`
  - Test que `cause` et `stackTrace` sont accessibles

- [ ] Creer `test/core/errors/result_test.dart` :
  - Test `Result.success(value)` — `isSuccess == true`, `getOrNull() == value`
  - Test `Result.failure(failure)` — `isFailure == true`, `getOrNull() == null`
  - Test `getOrElse` avec Success et Failure
  - Test `map` transforme Success, passe Failure
  - Test `flatMap` chaine Success, court-circuite Failure
  - Test `mapFailure` transforme Failure, passe Success
  - Test `when` appelle le bon callback
  - Test `runCatching` avec succes et exception
  - Test `runCatchingAsync` avec succes et exception
  - Test exhaustive pattern matching (switch sans default)

- [ ] Creer `test/core/utils/logger_test.dart` :
  - Test format `[Source] Message` est respecte
  - Test que chaque niveau de log fonctionne (debug, info, warning, error, critical)
  - Test `setMinLevel` filtre les messages en dessous du seuil
  - **Test PII : verifier que le logger ne passe PAS les patterns PII courants** :
    - Creer un helper `containsPii(String message)` qui detecte : emails (`@`+domain), telephones (regex), noms propres en contexte, etc.
    - Ecrire un test qui verifie qu'aucun message de log dans les fixtures ne contient de PII
    - Ce test sert de pattern documentaire — les agents futurs doivent ecrire des tests similaires

- [ ] Creer `test/core/config/app_config_test.dart` :
  - Test que toutes les constantes de timeout sont positives
  - Test que `cacheTtlCritical` est `Duration.zero`
  - Test que les constantes sont coherentes (ex: `aiCloudTimeout < networkTimeout`)

- [ ] Creer `test/core/config/environment_test.dart` :
  - Test `Environment.fromString` avec valeurs valides et invalides
  - Test `EnvironmentConfig.logLevel` retourne le bon niveau par environment

### Task 8: Verifier dart analyze et flutter test (tous ACs)

- [ ] Executer `dart analyze` — doit etre clean (0 warnings, 0 errors)
- [ ] Executer `flutter test` — tous les tests passent
- [ ] Verifier que les imports sont corrects (pas de circular imports)
- [ ] Verifier que `lib/core/errors/kita_failure.dart` est correctement importe par `result.dart`

## Dev Notes

### Architecture — Error Handling Never-Fail Pattern

Le systeme d'erreurs Kita est base sur deux principes :

1. **Typed errors only** — Jamais de `throw` non type. Toutes les erreurs sont des `KitaFailure`. Le `Result<T>` encapsule success/failure sans exceptions.

2. **Never-fail pour le chemin critique** — Les requetes critiques (alertes obstacles) ne doivent JAMAIS echouer. Le fallback chain cascade jusqu'a l'alerte brute.

```
Requete -> RequestClassifier -> AIRouter
  |-- cloud-powerful (timeout 3s) -> succes -> reponse
  |-- cloud-fast (timeout 3s) -> succes -> reponse
  |-- local (ML Kit/CoreML) -> succes -> reponse (degradee)
  '-- alerte brute -> succes GARANTI -> reponse minimale
```

### Architecture — Separation userMessage / logMessage

- `userMessage` : texte en francais, adapte au profil utilisateur, passe au `ProfileAdapter` pour sortie multi-modale (voix, texte, haptique). Ne doit JAMAIS contenir de details techniques.
- `logMessage` : texte technique en anglais, pour les logs internes. Ne doit JAMAIS contenir de PII (noms, emails, numeros de telephone, adresses). Peut contenir des identifiants techniques (provider ID, plugin ID, operation name).

### Architecture — Result<T> vs fpdart

Le projet utilise un `Result<T>` custom (sealed class) au lieu de `fpdart` (Either) pour plusieurs raisons :
- Zero dependance externe pour un pattern fondamental
- Dart 3 sealed classes + pattern matching rendent `Either` moins necessaire
- API plus simple et directe pour le cas d'usage (success/failure)
- fpdart v2 est en pre-release et instable

### Architecture — Logger dart:developer

Le logger utilise `dart:developer log()` et non `package:logging` car :
- Zero dependance externe
- Integration native avec Dart DevTools (filtrage par nom et niveau)
- Suffisant pour le MVP (pas besoin de multiple sinks)
- Migration future vers `package:logging` possible si besoin (meme API)

### File Paths

| Fichier | Action |
|---------|--------|
| `lib/core/errors/kita_failure.dart` | Refactorer (existe) |
| `lib/core/errors/result.dart` | Refactorer (existe) |
| `lib/core/utils/logger.dart` | Refactorer (existe) |
| `lib/core/config/app_config.dart` | Creer |
| `lib/core/config/environment.dart` | Creer |
| `lib/core/constants/durations.dart` | Creer |
| `lib/core/constants/limits.dart` | Creer |
| `test/core/errors/kita_failure_test.dart` | Creer |
| `test/core/errors/result_test.dart` | Creer |
| `test/core/utils/logger_test.dart` | Creer |
| `test/core/config/app_config_test.dart` | Creer |
| `test/core/config/environment_test.dart` | Creer |

### Testing Standards

- Tous les fichiers source de cette story doivent avoir des tests associes
- Couverture cible : 100% des methodes publiques testees
- Tests PII : au moins un test verifiant que le logger refuse les patterns PII
- Pattern matching exhaustif sur `KitaFailure` : le test ne compile pas si un sous-type est manquant dans le switch

### Dependencies

Cette story ne necessite AUCUNE nouvelle dependance dans `pubspec.yaml`. Tout est fait avec :
- `dart:developer` pour le logging
- Les sealed classes Dart 3 pour les erreurs
- `const String.fromEnvironment` pour les flavors

## Technical Intelligence

### Dart 3.11 Sealed Classes

**Version :** Dart 3.11.0 (bundle Flutter 3.41.2)

Les sealed classes sont pleinement supportees depuis Dart 3.0 (mai 2023). En Dart 3.11 :

- Le mot-cle `sealed` marque une classe abstraite dont les sous-classes doivent etre dans la meme library
- Le compilateur connait tous les sous-types possibles — switch exhaustif garanti a la compilation
- Combinable avec `final class` pour les sous-types (non extensibles hors library)
- Pattern matching via `switch` expressions (Dart 3.0+) et destructuring

**Pattern cle pour KitaFailure :**
```dart
sealed class KitaFailure { ... }
final class NetworkFailure extends KitaFailure { ... }

// Exhaustif — erreur de compilation si un sous-type manque :
String handleError(KitaFailure f) => switch (f) {
  NetworkFailure() => 'Reseau',
  AIProviderFailure() => 'IA',
  PluginFailure() => 'Plugin',
  StorageFailure() => 'Stockage',
  PermissionFailure() => 'Permission',
  UnexpectedFailure() => 'Inattendu',
};
```

### Dart 3 Pattern Matching dans switch

```dart
// Destructuring avec named fields :
final message = switch (result) {
  Success(:final value) => 'Got: $value',
  Failure(:final failure) => 'Error: ${failure.logMessage}',
};

// Guard clauses :
switch (failure) {
  case NetworkFailure() when failure.cause is TimeoutException:
    // handle timeout specifically
  case NetworkFailure():
    // handle other network failures
}
```

### dart:developer log() API

```dart
import 'dart:developer' as dev;

dev.log(
  'message',
  name: 'kita',      // Filtrable dans DevTools
  level: 800,         // int : 0=ALL, 300=FINEST, 500=FINE, 800=INFO, 900=WARNING, 1000=SEVERE, 1200=SHOUT
  error: exception,   // Objet error optionnel
  stackTrace: stack,  // StackTrace optionnelle
  zone: null,         // Zone (rarement utilise)
);
```

**Niveaux de log (dart:developer) :**
- 0 : ALL / debug (note : FINEST est 300, mais on utilise 0 pour debug car c'est le niveau minimum)
- 300 : FINER / FINEST
- 500 : FINE
- 800 : INFO
- 900 : WARNING
- 1000 : SEVERE / error
- 1200 : SHOUT / critical

Le parametre `name` est utilise par DevTools pour filtrer les logs. Utiliser `'kita'` comme namespace global.

### Flutter --dart-define pour les flavors

```bash
# Dev (defaut)
flutter run

# Staging
flutter run --dart-define=ENV=staging

# Prod
flutter run --dart-define=ENV=prod
flutter build apk --dart-define=ENV=prod
```

Lecture cote Dart :
```dart
const env = String.fromEnvironment('ENV', defaultValue: 'dev');
```

`String.fromEnvironment` est `const` — resolve a la compilation. Pas de overhead runtime.

### Result<T> — pourquoi pas fpdart

| Critere | Result custom | fpdart Either |
|---------|--------------|---------------|
| Dependance | Zero | `fpdart: ^1.1.0` (v2 pre-release instable) |
| Pattern matching | Natif Dart 3 sealed | Possible mais moins idiomatique |
| API async | `runCatchingAsync` helper | `TaskEither` (plus puissant mais complexite) |
| Courbe d'apprentissage | Minimale | FP concepts (functor, monad) |
| Maintenance | Interne | Dependance externe |

Pour le MVP, le `Result<T>` custom est suffisant. Migration vers fpdart possible post-MVP si besoin de TaskEither.

## Pitfalls & Gotchas

### 1. Sealed class — meme library obligatoire

Tous les sous-types de `KitaFailure` DOIVENT etre dans le meme fichier (`kita_failure.dart`) ou dans des `part` files de la meme library. Si un sous-type est defini dans un autre fichier sans `part`/`part of`, le switch ne sera PAS exhaustif.

**Solution :** Garder tous les sous-types dans `kita_failure.dart`. Le fichier sera long (~200 lignes) mais c'est le pattern correct.

### 2. Ne pas utiliser `part` files pour KitaFailure

Meme si Dart supporte `part`/`part of`, cela complique les imports et la navigation. Preferer un seul fichier pour la sealed class et ses sous-types.

### 3. Logger — zero PII dans les logs

Le logger lui-meme ne peut pas empecher les developpeurs de passer du PII. La prevention est via :
- Convention : `logMessage` en anglais, technique, sans donnees utilisateur
- Tests : verifier que les messages de test ne contiennent pas de patterns PII
- Code review : lint custom future (post-MVP) pour detecter les patterns PII dans les strings de log

Le test PII de cette story est un **test documentaire** — il montre le pattern aux agents futurs, il ne peut pas intercepter tous les cas a la compilation.

### 4. Environment — `fromEnvironment` est const uniquement

`String.fromEnvironment` ne fonctionne que comme `const`. On ne peut pas l'utiliser dans une variable non-const. Toujours declarer avec `const` ou `static const`.

```dart
// BON
static const String _envString = String.fromEnvironment('ENV', defaultValue: 'dev');

// MAUVAIS — retourne toujours la defaultValue
final env = String.fromEnvironment('ENV', defaultValue: 'dev');
```

### 5. Ne pas creer `failure_handler.dart` dans cette story

L'architecture mentionne `core/errors/failure_handler.dart` (logging + ProfileAdapter error feedback). Ce fichier depend de `ProfileAdapter` qui sera cree dans E8 (Shell UI). Ne PAS le creer maintenant — il sera cree quand ProfileAdapter existera.

### 6. Conflit de nommage `Durations`

Flutter definit deja une classe `Durations` dans `package:flutter/material.dart`. Pour eviter le conflit :
- Nommer la classe `KitaDurations` au lieu de `Durations`
- OU utiliser un import prefixe si necessaire
- La solution recommandee est d'utiliser `KitaDurations` pour la clarte

### 7. `abstract final class` pour les classes de constantes

En Dart 3, utiliser `abstract final class` pour les classes qui ne contiennent que des constantes statiques. Cela empeche l'instanciation ET l'extension.

```dart
abstract final class AppConfig { ... }  // BON — pas instanciable, pas extensible
class AppConfig { ... }                  // MAUVAIS — instanciable
abstract class AppConfig { ... }         // OK mais extensible
```

### 8. Logger — `dart:developer log()` n'est pas testable directement

`dart:developer log()` n'a AUCUN mecanisme de capture integre pour les tests (contrairement a `print()` qui peut etre capture via `Zone`). Cela signifie qu'on ne peut pas ecrire un test qui verifie le contenu exact du message passe a `dev.log()`.

**Solutions recommandees :**
- Ajouter un hook testable dans `KitaLogger` :
  ```dart
  @visibleForTesting
  static void Function(String message, {required LogLevel level, Object? error, StackTrace? stackTrace})? testLogHandler;
  ```
  Dans `_log()`, si `testLogHandler != null`, appeler le handler au lieu de (ou en plus de) `dev.log()`. Cela permet aux tests de capturer et verifier les messages.
- Alternative : deleguer l'appel log a une fonction injectable (pattern similaire a `Color.computeLuminance()` qui delegue a une fonction remplacable).

Le `testLogHandler` doit etre `null` en production et n'est set que dans les tests via `setUp`/`tearDown`.

### 9. Tests — pas de flutter_test pour les tests core purs

Les fichiers `core/` ne dependent pas de Flutter. On peut utiliser `package:test` directement au lieu de `package:flutter_test`. Cependant, puisque `flutter_test` inclut `package:test`, utiliser `flutter_test` pour la coherence — cela evite d'ajouter `package:test` au pubspec.

## References

- [Source: _bmad-output/planning-artifacts/architecture.md#Process Patterns — Error Handling]
- [Source: _bmad-output/planning-artifacts/architecture.md#Logging — niveaux et format]
- [Source: _bmad-output/planning-artifacts/architecture.md#Data Architecture — Strategie de cache]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2]
- [Source: CLAUDE.md#Conventions de code — Error handling, Logging]
- [Source: dart.dev/language/class-modifiers — Sealed classes]
- [Source: dart.dev/libraries/core/environment-declarations — fromEnvironment]
- [Source: Story 1.1 implementation — existing kita_failure.dart, result.dart, logger.dart]

## Dev Agent Record

### Agent Model Used

(a remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
