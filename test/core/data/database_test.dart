import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';

void main() {
  late KitaDatabase db;
  late sql.Database rawDb;

  setUp(() {
    rawDb = sql.sqlite3.openInMemory();
    // Check if SQLCipher is available; if so, set the key.
    final cipherResult = rawDb.select('PRAGMA cipher_version;');
    if (cipherResult.isNotEmpty) {
      rawDb.execute("PRAGMA key = 'test-encryption-key';");
    }
    db = KitaDatabase(NativeDatabase.opened(rawDb));
  });

  tearDown(() async {
    await db.close();
  });

  test('database opens and responds to queries', () async {
    final result = await db.customSelect('SELECT 1 AS val').get();
    expect(result.first.read<int>('val'), equals(1));
  });

  test('database closes without error', () async {
    // Verify DB is functional before close
    await db.customSelect('SELECT 1').get();
    await db.close();
    // Recreate for tearDown
    rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
  });

  test('all 7 tables exist in schema', () async {
    final result = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).get();
    final tables = result.map((r) => r.read<String>('name')).toSet();
    expect(
      tables,
      containsAll([
        'request_cache',
        'episodes',
        'preferences',
        'persons',
        'user_profiles',
        'consent_log',
        'plugin_data',
      ]),
    );
  });

  test('schema version is 1', () {
    expect(db.schemaVersion, equals(1));
  });

  test('can insert and query request_cache', () async {
    await db.customInsert(
      'INSERT INTO request_cache (request_hash, request_type, response_content, provider_id, ttl_seconds, expires_at) '
      "VALUES ('abc123', 'text', 'response', 'claude', 300, '2026-12-31T00:00:00.000Z')",
    );
    final result = await db
        .customSelect('SELECT * FROM request_cache WHERE request_hash = ?',
            variables: [const Variable('abc123')])
        .get();
    expect(result, hasLength(1));
    expect(result.first.read<String>('request_type'), equals('text'));
  });

  test('can insert and query episodes', () async {
    await db.customInsert(
      'INSERT INTO episodes (source, event_type, summary) '
      "VALUES ('camera', 'describe', 'A red car')",
    );
    final result =
        await db.customSelect('SELECT * FROM episodes').get();
    expect(result, hasLength(1));
    expect(result.first.read<String>('source'), equals('camera'));
    expect(result.first.read<double>('importance_score'), equals(0.5));
  });

  test('cipher_version pragma returns value when SQLCipher is loaded', () async {
    final cipherResult = rawDb.select('PRAGMA cipher_version;');
    // On desktop test runners, SQLCipher may or may not be available.
    // If available, it should return a non-empty version string.
    if (cipherResult.isNotEmpty) {
      expect(cipherResult.first.values.first, isA<String>());
    }
  });
}
