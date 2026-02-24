import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';

void main() {
  late KitaDatabase db;
  late PersonDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = PersonDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PersonDao', () {
    test('insert returns id', () async {
      final result = await dao.insert(name: 'Sophie');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('getById returns inserted person', () async {
      final insertResult = await dao.insert(
        name: 'Sophie',
        relationship: 'friend',
        notes: 'Colleague from work',
        interests: ['cooking', 'travel'],
      );
      final id = insertResult.getOrNull()!;

      final result = await dao.getById(id);
      expect(result.isSuccess, isTrue);
      final person = result.getOrNull()!;
      expect(person.name, equals('Sophie'));
      expect(person.relationship, equals('friend'));
      expect(person.notes, equals('Colleague from work'));
      expect(person.interests, equals(['cooking', 'travel']));
    });

    test('getById returns null for non-existent id', () async {
      final result = await dao.getById(999);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getByName returns person by name', () async {
      await dao.insert(name: 'Sophie');

      final result = await dao.getByName('Sophie');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull()!.name, equals('Sophie'));
    });

    test('getByName returns null for non-existent name', () async {
      final result = await dao.getByName('Nobody');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getAll returns all persons ordered by name', () async {
      await dao.insert(name: 'Charlie');
      await dao.insert(name: 'Alice');
      await dao.insert(name: 'Bob');

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      final persons = result.getOrNull()!;
      expect(persons, hasLength(3));
      expect(persons[0].name, equals('Alice'));
      expect(persons[1].name, equals('Bob'));
      expect(persons[2].name, equals('Charlie'));
    });

    test('update modifies person fields', () async {
      final insertResult = await dao.insert(name: 'Sophie');
      final id = insertResult.getOrNull()!;

      final updateResult = await dao.update(
        id,
        relationship: 'best friend',
        interests: ['cooking', 'travel', 'photography'],
      );
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.getOrNull(), isTrue);

      final person = (await dao.getById(id)).getOrNull()!;
      expect(person.relationship, equals('best friend'));
      expect(person.interests, equals(['cooking', 'travel', 'photography']));
    });

    test('deleteById removes person', () async {
      final insertResult = await dao.insert(name: 'Sophie');
      final id = insertResult.getOrNull()!;

      final deleteResult = await dao.deleteById(id);
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.getOrNull(), equals(1));

      final getResult = await dao.getById(id);
      expect(getResult.getOrNull(), isNull);
    });

    test('deleteAll removes all persons', () async {
      await dao.insert(name: 'Alice');
      await dao.insert(name: 'Bob');

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final count = (await dao.count()).getOrNull()!;
      expect(count, equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert(name: 'Alice');
      await dao.insert(name: 'Bob');

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
    });

    test('interests are parsed from comma-separated string', () async {
      final insertResult = await dao.insert(
        name: 'Sophie',
        interests: ['cooking', 'travel'],
      );
      final id = insertResult.getOrNull()!;

      final person = (await dao.getById(id)).getOrNull()!;
      expect(person.interests, equals(['cooking', 'travel']));
    });

    test('empty interests returns empty list', () async {
      final insertResult = await dao.insert(name: 'Sophie');
      final id = insertResult.getOrNull()!;

      final person = (await dao.getById(id)).getOrNull()!;
      expect(person.interests, isEmpty);
    });
  });
}
