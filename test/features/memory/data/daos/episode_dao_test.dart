import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';

void main() {
  late KitaDatabase db;
  late EpisodeDao dao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    dao = EpisodeDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('EpisodeDao', () {
    test('insert returns id', () async {
      final result = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A red car',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
    });

    test('getById returns inserted episode', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A red car',
        details: 'Parked on the street',
        tags: ['outdoor', 'vehicle'],
        importanceScore: 0.8,
      );
      final id = insertResult.getOrNull()!;

      final result = await dao.getById(id);
      expect(result.isSuccess, isTrue);
      final episode = result.getOrNull()!;
      expect(episode.source, equals('camera'));
      expect(episode.eventType, equals('describe'));
      expect(episode.summary, equals('A red car'));
      expect(episode.details, equals('Parked on the street'));
      expect(episode.tags, equals(['outdoor', 'vehicle']));
      expect(episode.importanceScore, equals(0.8));
      expect(episode.isPinned, isFalse);
    });

    test('getById returns null for non-existent id', () async {
      final result = await dao.getById(999);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('getAll returns all episodes ordered by createdAt desc', () async {
      await dao.insert(source: 'a', eventType: 'test', summary: 'First');
      await dao.insert(source: 'b', eventType: 'test', summary: 'Second');
      await dao.insert(source: 'c', eventType: 'test', summary: 'Third');

      final result = await dao.getAll();
      expect(result.isSuccess, isTrue);
      final episodes = result.getOrNull()!;
      expect(episodes, hasLength(3));
    });

    test('update modifies episode fields', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A red car',
      );
      final id = insertResult.getOrNull()!;

      final updateResult = await dao.update(
        id,
        summary: 'A blue car',
        isPinned: true,
        importanceScore: 0.9,
      );
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.getOrNull(), isTrue);

      final episode = (await dao.getById(id)).getOrNull()!;
      expect(episode.summary, equals('A blue car'));
      expect(episode.isPinned, isTrue);
      expect(episode.importanceScore, equals(0.9));
    });

    test('deleteById removes episode', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A red car',
      );
      final id = insertResult.getOrNull()!;

      final deleteResult = await dao.deleteById(id);
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.getOrNull(), equals(1));

      final getResult = await dao.getById(id);
      expect(getResult.getOrNull(), isNull);
    });

    test('deleteAll removes all episodes', () async {
      await dao.insert(source: 'a', eventType: 'test', summary: 'First');
      await dao.insert(source: 'b', eventType: 'test', summary: 'Second');

      final result = await dao.deleteAll();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));

      final countResult = await dao.count();
      expect(countResult.getOrNull(), equals(0));
    });

    test('count returns correct number', () async {
      await dao.insert(source: 'a', eventType: 'test', summary: 'First');
      await dao.insert(source: 'b', eventType: 'test', summary: 'Second');

      final result = await dao.count();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
    });

    test('tags are parsed from comma-separated string', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A scene',
        tags: ['outdoor', 'sunny', 'park'],
      );
      final id = insertResult.getOrNull()!;

      final episode = (await dao.getById(id)).getOrNull()!;
      expect(episode.tags, equals(['outdoor', 'sunny', 'park']));
    });

    test('empty tags returns empty list', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'A scene',
      );
      final id = insertResult.getOrNull()!;

      final episode = (await dao.getById(id)).getOrNull()!;
      expect(episode.tags, isEmpty);
    });

    test('deleteExpiredBefore removes old non-pinned episodes', () async {
      final now = DateTime.now();
      final pastExpiry = now.subtract(const Duration(days: 10));
      // Insert expired episode
      await dao.insert(
        source: 'old',
        eventType: 'test',
        summary: 'Old episode',
        expiresAt: pastExpiry,
      );
      // Insert pinned expired episode (should be preserved)
      await dao.insert(
        source: 'pinned',
        eventType: 'test',
        summary: 'Pinned episode',
        isPinned: true,
        expiresAt: pastExpiry,
      );

      // Delete episodes expired before now
      final result = await dao.deleteExpiredBefore(now);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));

      // Pinned episode should remain
      final remaining = (await dao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.source, equals('pinned'));
    });

    test('deleteExpiredBefore also removes old episodes with no expiry date',
        () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));

      // Old episode, NO expiry date, created before the cutoff -> must be deleted.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'old',
            eventType: 'test',
            summary: 'Old no-expiry',
            createdAt: Value(now.subtract(const Duration(days: 40))),
          ));

      // Recent episode, NO expiry date, created after the cutoff -> must survive.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'recent',
            eventType: 'test',
            summary: 'Recent no-expiry',
            createdAt: Value(now.subtract(const Duration(days: 5))),
          ));

      final result = await dao.deleteExpiredBefore(cutoff);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));

      final remaining = (await dao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.source, equals('recent'));
    });

    test('deleteExpiredBefore keeps pinned old episodes with no expiry date',
        () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));

      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'pinned-old',
            eventType: 'test',
            summary: 'Pinned old no-expiry',
            isPinned: const Value(true),
            createdAt: Value(now.subtract(const Duration(days: 40))),
          ));

      final result = await dao.deleteExpiredBefore(cutoff);
      expect(result.getOrNull(), equals(0));
      expect((await dao.getAll()).getOrNull(), hasLength(1));
    });

    test('deleteExpiredBefore keeps episodes whose expiry is still in the future',
        () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));

      // Created long ago but explicitly set to expire later -> must survive.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'future-expiry',
            eventType: 'test',
            summary: 'Future expiry',
            createdAt: Value(now.subtract(const Duration(days: 40))),
            expiresAt: Value(now.add(const Duration(days: 10))),
          ));

      final result = await dao.deleteExpiredBefore(cutoff);
      expect(result.getOrNull(), equals(0));
      expect((await dao.getAll()).getOrNull(), hasLength(1));
    });

    test('getExpiredBefore uses the same predicate as deleteExpiredBefore',
        () async {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));

      // Old, no expiry -> expired.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'old',
            eventType: 'test',
            summary: 'Old no-expiry',
            createdAt: Value(now.subtract(const Duration(days: 40))),
          ));
      // Recent, no expiry -> not expired.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'recent',
            eventType: 'test',
            summary: 'Recent no-expiry',
            createdAt: Value(now.subtract(const Duration(days: 5))),
          ));
      // Old created_at but future expiry -> not expired.
      await db.into(db.episodes).insert(EpisodesCompanion.insert(
            source: 'future-expiry',
            eventType: 'test',
            summary: 'Future expiry',
            createdAt: Value(now.subtract(const Duration(days: 40))),
            expiresAt: Value(now.add(const Duration(days: 10))),
          ));

      final expired = (await dao.getExpiredBefore(cutoff)).getOrNull()!;
      expect(expired, hasLength(1));
      expect(expired.first.source, equals('old'));
    });

    test('insert with isPinned true preserves pinned state', () async {
      final insertResult = await dao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Important scene',
        isPinned: true,
      );
      final id = insertResult.getOrNull()!;

      final episode = (await dao.getById(id)).getOrNull()!;
      expect(episode.isPinned, isTrue);
    });
  });
}
