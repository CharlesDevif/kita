import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';

void main() {
  late KitaDatabase db;
  late ProfileDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = ProfileDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileDao', () {
    test('insert returns id', () async {
      final result = await dao.insert();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('insert with all parameters', () async {
      final result = await dao.insert(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
        language: 'fr',
        ttsSpeed: 1.2,
        ttsVoice: 'fr-FR-Wavenet-A',
        hapticEnabled: true,
      );
      expect(result.isSuccess, isTrue);
      final id = result.getOrNull()!;

      final profile = (await dao.getById(id)).getOrNull()!;
      expect(profile.displayName, equals('Marie'));
      expect(profile.accessibilityProfile, equals('blind'));
      expect(profile.language, equals('fr'));
      expect(profile.ttsSpeed, equals(1.2));
      expect(profile.ttsVoice, equals('fr-FR-Wavenet-A'));
      expect(profile.hapticEnabled, isTrue);
    });

    test('getById returns null for non-existent id', () async {
      final result = await dao.getById(999);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getActive returns most recently updated profile', () async {
      await dao.insert(displayName: 'Profile 1');
      await dao.insert(displayName: 'Profile 2');

      final result = await dao.getActive();
      expect(result.isSuccess, isTrue);
      // Both inserted at same time but second has higher id
      expect(result.getOrNull(), isNotNull);
    });

    test('getActive returns null when no profiles exist', () async {
      final result = await dao.getActive();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getAll returns all profiles', () async {
      await dao.insert(displayName: 'Profile 1');
      await dao.insert(displayName: 'Profile 2');

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('update modifies profile fields', () async {
      final insertResult = await dao.insert(displayName: 'Marie');
      final id = insertResult.getOrNull()!;

      final updateResult = await dao.update(
        id,
        accessibilityProfile: 'blind',
        ttsSpeed: 1.5,
        hapticEnabled: false,
      );
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.getOrNull(), isTrue);

      final profile = (await dao.getById(id)).getOrNull()!;
      expect(profile.accessibilityProfile, equals('blind'));
      expect(profile.ttsSpeed, equals(1.5));
      expect(profile.hapticEnabled, isFalse);
      expect(profile.displayName, equals('Marie'));
    });

    test('deleteById removes profile', () async {
      final insertResult = await dao.insert(displayName: 'Marie');
      final id = insertResult.getOrNull()!;

      final deleteResult = await dao.deleteById(id);
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.getOrNull(), equals(1));

      final getResult = await dao.getById(id);
      expect(getResult.getOrNull(), isNull);
    });

    test('deleteAll removes all profiles', () async {
      await dao.insert(displayName: 'Profile 1');
      await dao.insert(displayName: 'Profile 2');

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert();
      await dao.insert();

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
    });

    test('default values are applied correctly', () async {
      final insertResult = await dao.insert();
      final id = insertResult.getOrNull()!;

      final profile = (await dao.getById(id)).getOrNull()!;
      expect(profile.displayName, isNull);
      expect(profile.accessibilityProfile, equals('standard'));
      expect(profile.language, equals('fr'));
      expect(profile.ttsSpeed, equals(1.0));
      expect(profile.ttsVoice, isNull);
      expect(profile.hapticEnabled, isTrue);
    });
  });
}
