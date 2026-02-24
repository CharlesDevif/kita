import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import '../utils/logger.dart';

const _kDbKeyStorageKey = 'kita_db_encryption_key';
final _log = KitaLogger('Database');

/// Configuration and helpers for the encrypted SQLCipher database.
abstract final class DatabaseConfig {
  /// Configures the SQLCipher native library for the current platform.
  static Future<void> setupSqlCipher() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  /// Verifies that the loaded SQLite library is actually SQLCipher.
  static bool debugCheckHasCipher(sql.Database database) {
    return database.select('PRAGMA cipher_version;').isNotEmpty;
  }

  /// Opens an encrypted database file using SQLCipher on a background isolate.
  static QueryExecutor openEncryptedDatabase(
    File dbFile,
    String encryptionKey,
  ) {
    final token = ServicesBinding.rootIsolateToken!;
    return NativeDatabase.createInBackground(
      dbFile,
      isolateSetup: () async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        await setupSqlCipher();
      },
      setup: (rawDb) {
        assert(debugCheckHasCipher(rawDb));
        rawDb.execute("PRAGMA key = '$encryptionKey';");
        rawDb.config.doubleQuotedStringLiterals = false;
      },
    );
  }

  /// Generates or retrieves the AES-256 encryption key from secure storage.
  static Future<String> getOrCreateEncryptionKey({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) async {
    var key = await storage.read(key: _kDbKeyStorageKey);
    if (key == null) {
      final bytes =
          List<int>.generate(32, (_) => Random.secure().nextInt(256));
      key = base64Url.encode(bytes);
      await storage.write(key: _kDbKeyStorageKey, value: key);
      _log.info('Encryption key generated');
    }
    return key;
  }

  /// Returns the database file in the app support directory.
  static Future<File> getDatabaseFile() async {
    final appDir = await getApplicationSupportDirectory();
    return File(p.join(appDir.path, 'kita.db'));
  }
}
