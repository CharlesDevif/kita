# Story 1.6: Infrastructure Drift + SQLCipher

Status: ready-for-dev

## Story

As a **developpeur**,
I want **Drift + SQLCipher configures avec la base de donnees chiffree vide**,
So that **les epics Memoire et Plugins peuvent ajouter leurs tables a la DB chiffree**.

## Acceptance Criteria

1. **Given** le projet est structure (Story 1.1) **When** Drift + SQLCipher est configure **Then** `core/config/database_config.dart` initialise SQLCipher avec chiffrement AES-256

2. **And** `core/data/database.dart` contient la classe `KitaDatabase` qui importe les tables Drift de chaque feature

3. **And** les 7 tables sont pre-declarees dans des fichiers `.drift` separes par feature :
   - `features/ai/data/tables/request_cache.drift` (request_cache)
   - `features/memory/data/tables/episodes.drift` (episodes)
   - `features/memory/data/tables/preferences.drift` (preferences)
   - `features/memory/data/tables/persons.drift` (persons)
   - `features/memory/data/tables/user_profiles.drift` (user_profiles)
   - `features/memory/data/tables/consent_log.drift` (consent_log)
   - `features/plugins/data/tables/plugin_data.drift` (plugin_data)

4. **And** convention : chaque agent cree ses fichiers DAO dans `features/{feature}/data/daos/`, mais l'enregistrement dans `@DriftDatabase(daos: [...])` de `database.dart` est coordonne par l'agent E1 (les agents des phases 2+ ne modifient pas `database.dart` eux-memes)

5. **And** `build_runner` est configure pour la code generation Drift

6. **And** `dart run build_runner build` s'execute sans erreur

7. **And** un test unitaire verifie que la DB s'ouvre et se ferme correctement avec chiffrement

8. **And** le fichier DB est illisible sans la cle de chiffrement

## Tasks / Subtasks

### Task 1 : Creer `core/config/database_config.dart` — Configuration SQLCipher (AC: #1)

- [ ] Creer `lib/core/config/database_config.dart`
- [ ] Implementer `DatabaseConfig` avec :
  - [ ] Methode `setupSqlCipher()` : appelle `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` et `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)`
  - [ ] Methode privee `_debugCheckHasCipher(Database db)` : verifie que `PRAGMA cipher_version` retourne un resultat
  - [ ] Methode `openEncryptedDatabase(File dbFile, String encryptionKey)` : retourne un `NativeDatabase` configure avec SQLCipher
  - [ ] Methode `getOrCreateEncryptionKey()` : utilise `flutter_secure_storage` pour stocker/recuperer la cle AES-256 dans Keychain/Keystore
  - [ ] Methode `getDatabaseFile()` : retourne le `File` du fichier DB via `path_provider`
- [ ] Utiliser `NativeDatabase.createInBackground()` avec `isolateSetup` et `setup` callbacks
- [ ] Dans le callback `setup`, executer `PRAGMA key = '...';` et `rawDb.config.doubleQuotedStringLiterals = false`
- [ ] Ajouter assertion `_debugCheckHasCipher(rawDb)` dans le callback setup

### Task 2 : Creer les 7 fichiers `.drift` avec schemas de tables (AC: #3)

- [ ] Creer `lib/features/ai/data/tables/request_cache.drift` :
  ```sql
  CREATE TABLE request_cache (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    request_hash TEXT NOT NULL,
    request_type TEXT NOT NULL,
    response_content TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    ttl_seconds INTEGER NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    expires_at DATETIME NOT NULL
  );
  ```

- [ ] Creer `lib/features/memory/data/tables/episodes.drift` :
  ```sql
  CREATE TABLE episodes (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    event_type TEXT NOT NULL,
    summary TEXT NOT NULL,
    details TEXT,
    tags TEXT,
    importance_score REAL NOT NULL DEFAULT 0.5,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    expires_at DATETIME
  );
  ```

- [ ] Creer `lib/features/memory/data/tables/preferences.drift` :
  ```sql
  CREATE TABLE preferences (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence_score REAL NOT NULL DEFAULT 0.5,
    source TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  );
  ```

- [ ] Creer `lib/features/memory/data/tables/persons.drift` :
  ```sql
  CREATE TABLE persons (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    relationship TEXT,
    notes TEXT,
    interests TEXT,
    last_mentioned_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  );
  ```

- [ ] Creer `lib/features/memory/data/tables/user_profiles.drift` :
  ```sql
  CREATE TABLE user_profiles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    display_name TEXT,
    accessibility_profile TEXT NOT NULL DEFAULT 'standard',
    language TEXT NOT NULL DEFAULT 'fr',
    tts_speed REAL NOT NULL DEFAULT 1.0,
    tts_voice TEXT,
    haptic_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  );
  ```

- [ ] Creer `lib/features/memory/data/tables/consent_log.drift` :
  ```sql
  CREATE TABLE consent_log (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    consent_type TEXT NOT NULL,
    scope TEXT NOT NULL,
    granted BOOLEAN NOT NULL,
    granted_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    revoked_at DATETIME,
    details TEXT
  );
  ```

- [ ] Creer `lib/features/plugins/data/tables/plugin_data.drift` :
  ```sql
  CREATE TABLE plugin_data (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    plugin_id TEXT NOT NULL,
    namespace TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
  );
  ```

### Task 3 : Creer `core/data/database.dart` — Classe KitaDatabase (AC: #2)

- [ ] Creer `lib/core/data/database.dart`
- [ ] Definir la classe `KitaDatabase` avec l'annotation `@DriftDatabase` :
  ```dart
  @DriftDatabase(
    include: {
      'package:kita/features/ai/data/tables/request_cache.drift',
      'package:kita/features/memory/data/tables/episodes.drift',
      'package:kita/features/memory/data/tables/preferences.drift',
      'package:kita/features/memory/data/tables/persons.drift',
      'package:kita/features/memory/data/tables/user_profiles.drift',
      'package:kita/features/memory/data/tables/consent_log.drift',
      'package:kita/features/plugins/data/tables/plugin_data.drift',
    },
  )
  class KitaDatabase extends _$KitaDatabase {
    KitaDatabase(super.e);

    @override
    int get schemaVersion => 1;
  }
  ```
- [ ] Ajouter la directive `part 'database.g.dart';`
- [ ] Importer `package:drift/drift.dart`
- [ ] NE PAS ajouter de DAOs ici — chaque feature les cree dans son epic

### Task 4 : Creer le provider Riverpod pour la base de donnees (AC: #1, #2)

- [ ] Creer `lib/core/di/database_provider.dart`
- [ ] Implementer un provider Riverpod qui :
  - [ ] Appelle `DatabaseConfig.getOrCreateEncryptionKey()` pour obtenir la cle
  - [ ] Appelle `DatabaseConfig.getDatabaseFile()` pour obtenir le fichier
  - [ ] Appelle `DatabaseConfig.openEncryptedDatabase()` pour ouvrir la DB
  - [ ] Retourne une instance de `KitaDatabase`
  - [ ] Gere le `dispose` pour fermer la DB proprement

### Task 5 : Configurer `build_runner` pour Drift code generation (AC: #5, #6)

- [ ] Verifier que `pubspec.yaml` contient deja `drift: ^2.31.0`, `drift_dev: ^2.31.0`, `build_runner: ^2.11.1` (deja fait en Story 1.1)
- [ ] Verifier que `pubspec.yaml` contient `sqlite3: ^2.9.4` et `sqlcipher_flutter_libs: ^0.6.8` (deja fait en Story 1.1)
- [ ] Executer `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verifier que `core/data/database.g.dart` est genere sans erreur
- [ ] Verifier que `dart analyze` est clean
- [ ] Verifier que `flutter pub deps` ne contient PAS `sqlite3_flutter_libs`

### Task 6 : Ecrire les tests unitaires (AC: #7, #8)

- [ ] Creer `test/core/data/database_test.dart`
- [ ] Test : La DB s'ouvre correctement en memoire avec chiffrement
  - Utiliser l'une des deux approches suivantes :
    ```dart
    // Option A : Simple (recommande)
    db = KitaDatabase(NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = 'test-encryption-key';");
      },
    ));

    // Option B : Controle manuel
    final rawDb = sql.sqlite3.openInMemory();
    rawDb.execute("PRAGMA key = 'test-encryption-key';");
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    ```
  - Verifier que `PRAGMA cipher_version` retourne une valeur
- [ ] Test : La DB se ferme correctement sans erreur
- [ ] Test : Les 7 tables existent dans le schema
  - Verifier avec `SELECT name FROM sqlite_master WHERE type='table'`
- [ ] Creer `test/core/config/database_config_test.dart`
- [ ] Test : `getOrCreateEncryptionKey()` genere une cle de 44 caracteres (32 bytes base64-encoded) si aucune n'existe
- [ ] Test : `getOrCreateEncryptionKey()` retourne la meme cle au deuxieme appel
- [ ] Test : Le fichier DB chiffre est illisible sans la bonne cle
  - Creer un fichier DB temporaire avec chiffrement
  - Tenter d'ouvrir le fichier sans le PRAGMA key — doit echouer
  - Tenter d'ouvrir avec la bonne cle — doit reussir

### Task 7 : Verifications finales (tous ACs)

- [ ] `dart analyze` est clean
- [ ] `dart run build_runner build --delete-conflicting-outputs` passe
- [ ] `flutter test` passe (tous les tests existants + nouveaux)
- [ ] Le fichier `database.g.dart` est dans `.gitignore` et n'est PAS commite
- [ ] Mettre a jour `sprint-status.yaml` : story → `done`

## Dev Notes

### Architecture — Placement des fichiers

```
lib/
├── core/
│   ├── config/
│   │   └── database_config.dart     # THIS STORY — SQLCipher init, key management
│   ├── data/
│   │   ├── database.dart            # THIS STORY — KitaDatabase class
│   │   └── database.g.dart          # GENERATED — ne pas commiter
│   └── di/
│       └── database_provider.dart   # THIS STORY — Riverpod provider
├── features/
│   ├── ai/data/tables/
│   │   └── request_cache.drift      # THIS STORY — schema table
│   ├── memory/data/tables/
│   │   ├── episodes.drift           # THIS STORY — schema table
│   │   ├── preferences.drift        # THIS STORY — schema table
│   │   ├── persons.drift            # THIS STORY — schema table
│   │   ├── user_profiles.drift      # THIS STORY — schema table
│   │   └── consent_log.drift        # THIS STORY — schema table
│   └── plugins/data/tables/
│       └── plugin_data.drift        # THIS STORY — schema table
test/
├── core/
│   ├── config/
│   │   └── database_config_test.dart # THIS STORY
│   └── data/
│       └── database_test.dart        # THIS STORY
```

### Convention DAOs pour les futures Epics

Les agents des Epics 2-5 creent leurs DAOs dans leurs features respectives :

```
features/ai/data/daos/cache_dao.dart         # E2 (Story 2.7)
features/memory/data/daos/episode_dao.dart    # E4 (Story 4.1)
features/memory/data/daos/preference_dao.dart # E4 (Story 4.1)
features/memory/data/daos/person_dao.dart     # E4 (Story 4.1)
features/memory/data/daos/profile_dao.dart    # E4 (Story 4.1)
features/memory/data/daos/consent_dao.dart    # E4 (Story 4.1)
features/plugins/data/daos/plugin_data_dao.dart # E5
```

Chaque DAO :
- Etend `DatabaseAccessor<KitaDatabase>` avec le mixin genere `_$XxxDaoMixin`
- Est annote `@DriftAccessor(tables: [XxxTable])` ou reference le `.drift` file
- Retourne des objets domain, PAS des row objects Drift
- Est ajoute au `@DriftDatabase(daos: [...])` dans `database.dart` par l'agent E1 uniquement (ou via PR coordonnee)

**IMPORTANT :** Les agents des phases 2+ NE MODIFIENT PAS `core/data/database.dart`. Si un DAO a besoin d'etre enregistre dans la DB, cela doit etre coordonne via le lead E1 ou un mecanisme de merge.

### CRITICAL WARNING — drift_flutter interdit

**NE JAMAIS utiliser le package `drift_flutter`** dans ce projet.

`drift_flutter` importe transitivement `sqlite3_flutter_libs`. Ce package fournit les binaires SQLite natifs standards. `sqlcipher_flutter_libs` fournit les binaires SQLCipher (SQLite + chiffrement). Les deux packages fournissent les memes symboles natifs (`.so` sur Android, `.dylib` sur iOS/macOS), ce qui cree un conflit de linkage.

A la place, utiliser `NativeDatabase` directement depuis `package:drift/native.dart`.

### Gestion de la cle de chiffrement

La cle de chiffrement SQLCipher est :
1. Generee aleatoirement au premier lancement (32 bytes, base64-encoded)
2. Stockee dans `flutter_secure_storage` (Keychain iOS / Keystore Android)
3. Recuperee depuis le secure storage a chaque ouverture de la DB
4. JAMAIS logguee, JAMAIS incluse dans un crash report

Pattern :
```dart
const _kDbKeyStorageKey = 'kita_db_encryption_key';

Future<String> getOrCreateEncryptionKey() async {
  const storage = FlutterSecureStorage();
  var key = await storage.read(key: _kDbKeyStorageKey);
  if (key == null) {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    key = base64Url.encode(bytes);
    await storage.write(key: _kDbKeyStorageKey, value: key);
  }
  return key;
}
```

### Tests — strategie pour les tests en memoire

Pour les tests unitaires, on ne peut PAS utiliser `flutter_secure_storage` directement (il faut un host platform). Options :

1. **Tests de la DB elle-meme** : Utiliser `NativeDatabase.memory(setup: ...)` (approche la plus simple) ou `NativeDatabase.opened(sqlite3.openInMemory())` avec PRAGMA key applique manuellement. Pas besoin de `flutter_secure_storage`.

2. **Tests de `DatabaseConfig`** : Mocker `FlutterSecureStorage` avec une implementation en memoire.

3. **Test d'illisibilite** : Creer un fichier temporaire, ecrire des donnees chiffrees, tenter d'ouvrir sans cle → doit echouer avec une `SqliteException`.

**Approche recommandee** — `NativeDatabase.memory()` avec callback `setup` :
```dart
// Le plus simple — NativeDatabase.memory() gere l'ouverture en memoire
db = KitaDatabase(NativeDatabase.memory(
  setup: (rawDb) {
    rawDb.execute("PRAGMA key = 'test-encryption-key';");
  },
));
```

**Approche alternative** — controle manuel avec `sqlite3.openInMemory()` :
```dart
import 'package:sqlite3/sqlite3.dart' as sql;

// Open in-memory database for testing
final rawDb = sql.sqlite3.openInMemory();
rawDb.execute("PRAGMA key = 'test-key';");
final db = KitaDatabase(NativeDatabase.opened(rawDb));
```

**IMPORTANT :** Les tests doivent importer `sqlcipher_flutter_libs` pour que le binding natif SQLCipher soit charge (meme en mode test). Sur le CI, les tests de chiffrement necessitent que les libs natives soient disponibles — utiliser `flutter test` (pas `dart test`) pour que les bindings natifs soient resolus.

### Logging

Suivre le format `[Database] Message` pour tous les logs lies a la DB :
```dart
KitaLogger.info('[Database] Opening encrypted database');
KitaLogger.info('[Database] Database closed successfully');
KitaLogger.warning('[Database] Cipher version check failed');
```

Zero PII dans les logs — ne JAMAIS logger la cle de chiffrement ni le chemin complet du fichier DB.

## Technical Intelligence

### Packages et versions verifiees (fevrier 2026)

| Package | Version | Statut | Notes |
|---------|---------|--------|-------|
| `drift` | `2.31.0` | Stable, publie fevrier 2026 | ORM SQLite type-safe, bien maintenu |
| `drift_dev` | `2.31.0` | Stable | Code generator pour Drift |
| `sqlite3` | `^2.9.4` | Stable | Bindings Dart pour SQLite3/SQLCipher |
| `sqlcipher_flutter_libs` | `0.6.8` | Derniere version 0.6.x stable | Fournit les binaires SQLCipher natifs |
| `flutter_secure_storage` | `^10.0.0` | Stable | Keychain (iOS) / Keystore (Android) |
| `path_provider` | `^2.1.5` | Stable | Chemin app documents |
| `build_runner` | `^2.11.1` | Stable | Code generation runner |

**ALERTE :** `sqlcipher_flutter_libs 0.7.0+eol` publie en fevrier 2026 est un stub vide (no-op). Il est marque EOL. Le `^0.6.8` dans pubspec.yaml resoudra correctement vers 0.6.8 et ne montera PAS vers 0.7.0 grace au caret constraint.

**ALERTE :** Drift n'a PAS migre vers `sqlite3` v3 (issue simolus3/drift#3710). Le package `drift 2.31.0` depend de `sqlite3: ^2.6.0`. Rester sur `sqlite3: ^2.9.4`.

### API NativeDatabase — Setup complet avec SQLCipher

```dart
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Configures the SQLCipher native library for the current platform.
Future<void> setupSqlCipher() async {
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

/// Verifies that the loaded SQLite library is actually SQLCipher.
bool _debugCheckHasCipher(sql.Database database) {
  return database.select('PRAGMA cipher_version;').isNotEmpty;
}

/// Opens an encrypted database file using SQLCipher.
NativeDatabase openEncryptedDatabase(File dbFile, String encryptionKey) {
  final token = RootIsolateToken.instance!;
  return NativeDatabase.createInBackground(
    dbFile,
    isolateSetup: () async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      await setupSqlCipher();
    },
    setup: (rawDb) {
      assert(_debugCheckHasCipher(rawDb));
      rawDb.execute("PRAGMA key = '$encryptionKey';");
      rawDb.config.doubleQuotedStringLiterals = false;
    },
  );
}

/// Returns the database file in the app support directory.
/// NOTE: Utiliser getApplicationSupportDirectory() plutot que
/// getApplicationDocumentsDirectory(). Sur iOS, le dossier Documents est
/// sauvegarde par iCloud et visible dans l'app Fichiers, ce qui est
/// inapproprie pour une base de donnees chiffree contenant des donnees
/// sensibles. Le dossier Application Support n'est ni visible ni
/// sauvegarde par defaut.
Future<File> getDatabaseFile() async {
  final appDir = await getApplicationSupportDirectory();
  return File(p.join(appDir.path, 'kita.db'));
}
```

### API .drift file — Syntaxe SQL pour les tables

Les fichiers `.drift` contiennent du SQL standard SQLite avec des extensions Drift :

```sql
-- Types supportes :
-- TEXT      → String
-- INTEGER   → int
-- REAL      → double
-- BOOLEAN   → bool (stocke comme INTEGER 0/1)
-- DATETIME  → DateTime (stocke comme ISO-8601 TEXT ou UNIX timestamp)
-- BLOB      → Uint8List

-- Contraintes supportees :
-- NOT NULL, PRIMARY KEY, AUTOINCREMENT
-- DEFAULT value
-- REFERENCES table(column) — foreign keys
-- UNIQUE
```

### Integration .drift files dans @DriftDatabase

Les fichiers `.drift` sont references via le parametre `include` de l'annotation `@DriftDatabase`. Les chemins sont relatifs au fichier Dart ou utilisent le format `package:` :

```dart
@DriftDatabase(
  include: {
    'package:kita/features/memory/data/tables/episodes.drift',
    // ...
  },
)
class KitaDatabase extends _$KitaDatabase { ... }
```

Les tables definies dans les fichiers `.drift` sont automatiquement accessibles via des getters sur la classe DB generee (ex: `database.episodes`, `database.requestCache`).

### Test pattern pour DB en memoire avec SQLCipher

```dart
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KitaDatabase db;

  setUp(() {
    // Open in-memory database with encryption for testing
    final rawDb = sql.sqlite3.openInMemory();
    rawDb.execute("PRAGMA key = 'test-encryption-key';");
    db = KitaDatabase(NativeDatabase.opened(rawDb));
  });

  tearDown(() async {
    await db.close();
  });

  test('database opens and closes successfully', () async {
    // Just verify the database is open and functional
    final result = await db.customSelect('SELECT 1 AS val').get();
    expect(result.first.read<int>('val'), equals(1));
  });

  test('all 7 tables exist', () async {
    final result = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).get();
    final tables = result.map((r) => r.read<String>('name')).toSet();
    expect(tables, containsAll([
      'request_cache',
      'episodes',
      'preferences',
      'persons',
      'user_profiles',
      'consent_log',
      'plugin_data',
    ]));
  });
}
```

## Pitfalls & Gotchas

### 1. CRITIQUE — Conflit `sqlite3_flutter_libs` vs `sqlcipher_flutter_libs`

`sqlite3_flutter_libs` et `sqlcipher_flutter_libs` fournissent tous deux les binaires natifs SQLite. Ils ne peuvent PAS coexister. Avant chaque `pub get`, verifier :
```bash
flutter pub deps | grep sqlite3_flutter_libs
```
Si `sqlite3_flutter_libs` apparait, identifier la dependance qui le tire (souvent `drift_flutter`) et la supprimer.

### 2. CRITIQUE — Ne JAMAIS utiliser `drift_flutter`

Le package `drift_flutter` est un helper qui simplifie la creation de `NativeDatabase` mais il depend de `sqlite3_flutter_libs`. Pour ce projet, utiliser `package:drift/native.dart` directement avec `NativeDatabase`.

### 3. `sqlcipher_flutter_libs` 0.7.0+eol est un no-op

La version 0.7.0 publiee en fevrier 2026 est un stub vide concu pour la migration vers `sqlite3` v3. NE PAS monter vers 0.7.0. Le constraint `^0.6.8` dans pubspec.yaml empeche cette montee (le caret `^0.6.8` autorise `>=0.6.8 <0.7.0`).

### 4. PRAGMA key doit etre la premiere instruction qui accede aux donnees

Apres l'ouverture de la DB, `PRAGMA key = '...';` doit etre la premiere instruction qui accede aux donnees de la DB. Sinon SQLCipher ne pourra pas dechiffrer la base. `PRAGMA cipher_version` est une exception car il verifie uniquement le binding natif (il ne lit pas les donnees de la DB).

### 5. `RootIsolateToken` requis pour background isolate

`NativeDatabase.createInBackground()` execute les operations DB sur un isolate separe. Pour que `flutter_secure_storage` et `path_provider` fonctionnent dans l'isolateSetup, il faut :
1. Capturer `RootIsolateToken.instance!` sur l'isolate principal
2. Appeler `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` dans l'isolateSetup

### 6. Tests — SQLCipher natif requis

Les tests qui verifient le chiffrement necessitent les binaires natifs SQLCipher. Utiliser `flutter test` (pas `dart test`) pour que les bindings natifs soient charges. Sur CI (GitHub Actions), les runners Linux/macOS ont les libs necessaires via le pod/aar de `sqlcipher_flutter_libs`.

### 7. Tests en memoire — PRAGMA cipher_version

Meme avec une DB en memoire, si `sqlcipher_flutter_libs` est correctement charge, `PRAGMA cipher_version` doit retourner une version. Si ce pragma retourne un resultat vide, cela signifie que le binding natif n'est pas SQLCipher mais SQLite standard.

### 8. Chemin d'inclusion .drift dans @DriftDatabase — `package:` URI non garanti

Les docs officielles de Drift montrent uniquement des chemins relatifs dans le parametre `include`. Les URI `package:` (ex: `'package:kita/features/memory/data/tables/episodes.drift'`) peuvent fonctionner ou non selon la version de Drift et le resolver utilise par `build_runner`. **Valider pendant l'implementation** que `build_runner` resout correctement les URI `package:` dans `include`. Si ca ne fonctionne pas, utiliser des chemins relatifs depuis `lib/core/data/database.dart` :
```dart
include: {
  '../../../features/ai/data/tables/request_cache.drift',
  '../../../features/memory/data/tables/episodes.drift',
  '../../../features/memory/data/tables/preferences.drift',
  '../../../features/memory/data/tables/persons.drift',
  '../../../features/memory/data/tables/user_profiles.drift',
  '../../../features/memory/data/tables/consent_log.drift',
  '../../../features/plugins/data/tables/plugin_data.drift',
}
```
Les chemins relatifs sont fragiles si le fichier `database.dart` est deplace, mais ils sont garantis de fonctionner.

### 9. Pas de migration dans cette story

Cette story cree le schema initial (version 1). Les migrations (`from1To2`, etc.) seront implementees dans les epics suivants quand les schemas evoluent. La methode `migration` de `KitaDatabase` peut rester avec le defaut (create all tables).

### 10. Double-quoted string literals

Toujours desactiver les double-quoted string literals dans le callback setup :
```dart
rawDb.config.doubleQuotedStringLiterals = false;
```
Cela garantit que les guillemets doubles sont traites comme des identifiants SQL (standard), pas comme des string literals (comportement non-standard de SQLite).

### 11. iOS — Pas de configuration supplementaire pour SQLCipher

Sur iOS, `sqlcipher_flutter_libs` gere automatiquement le linkage via CocoaPods. Pas besoin d'ajouter de flags Xcode manuellement pour cette story. Le pod `sqlcipher_flutter_libs` embarque les binaires SQLCipher compiles.

### 12. Android — NDK et SQLCipher

`sqlcipher_flutter_libs` embarque des binaires pre-compiles pour les architectures Android (arm64-v8a, armeabi-v7a, x86, x86_64). Pas besoin de configurer le NDK manuellement. Le plugin Gradle gere l'inclusion dans l'APK.

## References

- Architecture : `_bmad-output/planning-artifacts/architecture.md` — sections "Data Architecture", "Securite & Authentification"
- Epics : `_bmad-output/planning-artifacts/epics.md` — Story 1.6, Story 4.1 (schema de reference)
- Story 1.1 : `_bmad-output/implementation-artifacts/1-1-initialisation-projet-flutter-structure-feature-first.md` — dependances et pitfalls drift
- Drift docs : https://drift.simonbinder.eu/platforms/encryption/ — setup SQLCipher
- Drift docs : https://drift.simonbinder.eu/platforms/vm/ — NativeDatabase setup
- Drift docs : https://drift.simonbinder.eu/sql_api/drift_files/ — syntaxe .drift
- Drift docs : https://drift.simonbinder.eu/dart_api/daos/ — pattern DAO
- pub.dev : https://pub.dev/packages/drift — drift 2.31.0
- pub.dev : https://pub.dev/packages/sqlcipher_flutter_libs — sqlcipher_flutter_libs 0.6.8
- pub.dev : https://pub.dev/packages/flutter_secure_storage — flutter_secure_storage 10.0.0
