import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';

void main() {
  late KitaDatabase db;
  late ConsentDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = ConsentDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ConsentDao', () {
    test('insert returns id', () async {
      final result = await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('getById returns inserted consent entry', () async {
      final insertResult = await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
        details: 'Store visual descriptions',
      );
      final id = insertResult.getOrNull()!;

      final result = await dao.getById(id);
      expect(result.isSuccess, isTrue);
      final entry = result.getOrNull()!;
      expect(entry.consentType, equals('data_storage'));
      expect(entry.scope, equals('episodic'));
      expect(entry.granted, isTrue);
      expect(entry.details, equals('Store visual descriptions'));
      expect(entry.revokedAt, isNull);
    });

    test('getById returns null for non-existent id', () async {
      final result = await dao.getById(999);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getActiveConsent returns active consent', () async {
      await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );

      final result = await dao.getActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNotNull);
      expect(result.getOrNull()!.granted, isTrue);
    });

    test('getActiveConsent returns null when no active consent', () async {
      final result = await dao.getActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getActiveConsent returns null for revoked consent', () async {
      final insertResult = await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );
      final id = insertResult.getOrNull()!;

      await dao.revoke(id);

      final result = await dao.getActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('hasActiveConsent returns true when active', () async {
      await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );

      final result = await dao.hasActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isTrue);
    });

    test('hasActiveConsent returns false when no consent', () async {
      final result = await dao.hasActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isFalse);
    });

    test('getAll returns all consent entries', () async {
      await dao.insert(consentType: 'data_storage', scope: 'episodic', granted: true);
      await dao.insert(consentType: 'data_storage', scope: 'relational', granted: false);

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(2));
    });

    test('getActiveConsents returns only active consents', () async {
      await dao.insert(consentType: 'data_storage', scope: 'episodic', granted: true);
      await dao.insert(consentType: 'data_storage', scope: 'relational', granted: false);
      final revokeId = (await dao.insert(
        consentType: 'data_storage',
        scope: 'semantic',
        granted: true,
      ))
          .getOrNull()!;
      await dao.revoke(revokeId);

      final result = await dao.getActiveConsents();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), hasLength(1));
      expect(result.getOrNull()!.first.scope, equals('episodic'));
    });

    test('revoke sets revokedAt timestamp', () async {
      final insertResult = await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );
      final id = insertResult.getOrNull()!;

      final revokeResult = await dao.revoke(id);
      expect(revokeResult.isSuccess, isTrue);
      expect(revokeResult.getOrNull(), isTrue);

      final entry = (await dao.getById(id)).getOrNull()!;
      expect(entry.revokedAt, isNotNull);
    });

    test('deleteAll removes all consent entries', () async {
      await dao.insert(consentType: 'data_storage', scope: 'episodic', granted: true);
      await dao.insert(consentType: 'data_storage', scope: 'relational', granted: true);

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert(consentType: 'data_storage', scope: 'episodic', granted: true);
      await dao.insert(consentType: 'data_storage', scope: 'relational', granted: true);

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
    });

    test('denied consent is not considered active', () async {
      await dao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: false,
      );

      final result = await dao.hasActiveConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isFalse);
    });
  });
}
