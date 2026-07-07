import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';

void main() {
  late KitaDatabase db;
  late PreferenceDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = PreferenceDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PreferenceDao', () {
    test('insert returns id', () async {
      final result = await dao.insert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('getByKey returns inserted preference', () async {
      await dao.insert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        confidenceScore: 0.9,
        source: 'user',
      );

      final result = await dao.getByKey('theme');
      expect(result.isSuccess, isTrue);
      final pref = result.getOrNull()!;
      expect(pref.category, equals('display'));
      expect(pref.key, equals('theme'));
      expect(pref.value, equals('dark'));
      expect(pref.confidenceScore, equals(0.9));
      expect(pref.source, equals('user'));
    });

    test('getByKey returns null for non-existent key', () async {
      final result = await dao.getByKey('nonexistent');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getById returns inserted preference', () async {
      final insertResult = await dao.insert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );
      final id = insertResult.getOrNull()!;

      final result = await dao.getById(id);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull()!.key, equals('theme'));
    });

    test('getByCategory returns filtered preferences', () async {
      await dao.insert(category: 'display', key: 'theme', value: 'dark', source: 'user');
      await dao.insert(category: 'display', key: 'font_size', value: '16', source: 'user');
      await dao.insert(category: 'audio', key: 'volume', value: '80', source: 'user');

      final result = await dao.getByCategory('display');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('getAll returns all preferences', () async {
      await dao.insert(category: 'display', key: 'theme', value: 'dark', source: 'user');
      await dao.insert(category: 'audio', key: 'volume', value: '80', source: 'user');

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('upsert inserts when key does not exist', () async {
      final result = await dao.upsert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );
      expect(result.isSuccess, isTrue);

      final pref = (await dao.getByKey('theme')).getOrNull()!;
      expect(pref.value, equals('dark'));
    });

    test('upsert updates when key already exists', () async {
      await dao.insert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );

      await dao.upsert(
        category: 'display',
        key: 'theme',
        value: 'light',
        source: 'user',
      );

      final pref = (await dao.getByKey('theme')).getOrNull()!;
      expect(pref.value, equals('light'));

      // Should still be only one preference with this key
      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(1));
    });

    test('upsert propagates a typed failure when the insert path fails',
        () async {
      // Force every INSERT on preferences to abort at the SQL level.
      await db.customStatement(
        'CREATE TRIGGER fail_pref_insert BEFORE INSERT ON preferences '
        "BEGIN SELECT RAISE(ABORT, 'insert blocked'); END;",
      );

      // No existing row -> upsert takes the insert branch, which now fails.
      final result = await dao.upsert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );

      expect(result.isFailure, isTrue);
    });

    test('deleteByKey removes preference', () async {
      await dao.insert(category: 'display', key: 'theme', value: 'dark', source: 'user');

      final result = await dao.deleteByKey('theme');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));

      final getResult = await dao.getByKey('theme');
      expect(getResult.getOrNull(), isNull);
    });

    test('deleteAll removes all preferences', () async {
      await dao.insert(category: 'display', key: 'theme', value: 'dark', source: 'user');
      await dao.insert(category: 'audio', key: 'volume', value: '80', source: 'user');

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert(category: 'display', key: 'theme', value: 'dark', source: 'user');
      await dao.insert(category: 'audio', key: 'volume', value: '80', source: 'user');

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
    });

    test('default confidence score is 0.5', () async {
      await dao.insert(
        category: 'display',
        key: 'theme',
        value: 'dark',
        source: 'user',
      );

      final pref = (await dao.getByKey('theme')).getOrNull()!;
      expect(pref.confidenceScore, equals(0.5));
    });
  });
}
