import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';

void main() {
  late KitaDatabase db;
  late PluginDataDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = PluginDataDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PluginDataDao', () {
    test('insert returns id', () async {
      final result = await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('get returns inserted entry', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );

      final result = await dao.get(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
      );
      expect(result.isSuccess, isTrue);
      final entry = result.getOrNull()!;
      expect(entry.pluginId, equals('com.kita.describe'));
      expect(entry.namespace, equals('settings'));
      expect(entry.key, equals('model'));
      expect(entry.value, equals('yolo-v8'));
    });

    test('get returns null for non-existent key', () async {
      final result = await dao.get(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'nonexistent',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getByPlugin returns all entries for a plugin', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'cache',
        key: 'last_run',
        value: '2026-02-24',
      );
      await dao.insert(
        pluginId: 'com.kita.alert',
        namespace: 'settings',
        key: 'threshold',
        value: '0.8',
      );

      final result = await dao.getByPlugin('com.kita.describe');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('getByNamespace returns entries for plugin+namespace', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'confidence',
        value: '0.7',
      );
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'cache',
        key: 'last_run',
        value: '2026-02-24',
      );

      final result = await dao.getByNamespace('com.kita.describe', 'settings');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('getAll returns all entries', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await dao.insert(
        pluginId: 'com.kita.alert',
        namespace: 'settings',
        key: 'threshold',
        value: '0.8',
      );

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('upsert inserts when key does not exist', () async {
      final result = await dao.upsert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      expect(result.isSuccess, isTrue);

      final entry = (await dao.get(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
      ))
          .getOrNull()!;
      expect(entry.value, equals('yolo-v8'));
    });

    test('upsert updates when key already exists', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );

      await dao.upsert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v9',
      );

      final entry = (await dao.get(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
      ))
          .getOrNull()!;
      expect(entry.value, equals('yolo-v9'));

      // Should still be only one entry
      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(1));
    });

    test('upsert propagates a typed failure when the insert path fails',
        () async {
      // Force every INSERT on plugin_data to abort at the SQL level.
      await db.customStatement(
        'CREATE TRIGGER fail_plugin_insert BEFORE INSERT ON plugin_data '
        "BEGIN SELECT RAISE(ABORT, 'insert blocked'); END;",
      );

      // No existing row -> upsert takes the insert branch, which now fails.
      final result = await dao.upsert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );

      expect(result.isFailure, isTrue);
    });

    test('deleteByPlugin removes all entries for a plugin', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'cache',
        key: 'last_run',
        value: '2026-02-24',
      );
      await dao.insert(
        pluginId: 'com.kita.alert',
        namespace: 'settings',
        key: 'threshold',
        value: '0.8',
      );

      final result = await dao.deleteByPlugin('com.kita.describe');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final remaining = (await dao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.pluginId, equals('com.kita.alert'));
    });

    test('deleteAll removes all entries', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await dao.insert(
        pluginId: 'com.kita.alert',
        namespace: 'settings',
        key: 'threshold',
        value: '0.8',
      );

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });
  });
}
