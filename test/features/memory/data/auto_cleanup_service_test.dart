import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/auto_cleanup_service.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';

void main() {
  late KitaDatabase db;
  late EpisodeDao episodeDao;
  late AutoCleanupService service;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    episodeDao = EpisodeDao(db);
    service = AutoCleanupService(
      episodeDao: episodeDao,
      retentionPeriod: const Duration(days: 30),
      cleanupInterval: const Duration(hours: 24),
    );
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  /// Inserts an episode created [daysAgo] days ago.
  Future<int> insertEpisodeAt({
    required int daysAgo,
    bool isPinned = false,
    String summary = 'Test',
  }) async {
    // We insert via raw SQL so we can set created_at in the past.
    final createdAt = DateTime.now().subtract(Duration(days: daysAgo));
    final iso = createdAt.toIso8601String();
    await db.customStatement(
      "INSERT INTO episodes (source, event_type, summary, importance_score, is_pinned, created_at)"
      " VALUES ('test', 'test', '$summary', 0.5, ${isPinned ? 1 : 0}, '$iso')",
    );
    final result = await db.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    return result.read<int>('id');
  }

  group('AutoCleanupService — selective cleanup', () {
    test('deletes episodes older than 30 days', () async {
      await insertEpisodeAt(daysAgo: 45, summary: 'Old episode');
      await insertEpisodeAt(daysAgo: 10, summary: 'Recent episode');

      final result = await service.runCleanup();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.summary, equals('Recent episode'));
    });

    test('preserves pinned episodes even if old', () async {
      await insertEpisodeAt(
          daysAgo: 60, isPinned: true, summary: 'Important old');
      await insertEpisodeAt(daysAgo: 60, summary: 'Unimportant old');
      await insertEpisodeAt(daysAgo: 5, summary: 'Recent');

      final result = await service.runCleanup();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(2));
      final summaries = remaining.map((e) => e.summary).toSet();
      expect(summaries, contains('Important old'));
      expect(summaries, contains('Recent'));
    });

    test('no-op when nothing to clean', () async {
      await insertEpisodeAt(daysAgo: 5, summary: 'Fresh');

      final result = await service.runCleanup();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(0));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
    });

    test('no-op when database is empty', () async {
      final result = await service.runCleanup();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(0));
    });

    test('custom retention period is respected', () async {
      final shortService = AutoCleanupService(
        episodeDao: episodeDao,
        retentionPeriod: const Duration(days: 7),
      );

      await insertEpisodeAt(daysAgo: 10, summary: 'Old for 7d policy');
      await insertEpisodeAt(daysAgo: 3, summary: 'Recent for 7d policy');

      final result = await shortService.runCleanup();
      expect(result.getOrNull(), equals(1));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.summary, equals('Recent for 7d policy'));
      shortService.dispose();
    });
  });

  group('AutoCleanupService — scheduling', () {
    test('start runs cleanup immediately', () async {
      await insertEpisodeAt(daysAgo: 45, summary: 'Should be cleaned');

      final result = await service.start();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(1));
      expect(service.isRunning, isTrue);

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, isEmpty);
    });

    test('stop cancels the periodic timer', () async {
      await service.start();
      expect(service.isRunning, isTrue);

      service.stop();
      expect(service.isRunning, isFalse);
    });

    test('dispose stops the service', () async {
      await service.start();
      service.dispose();
      expect(service.isRunning, isFalse);
    });
  });

  group('AutoCleanupService — mixed scenarios', () {
    test('bulk cleanup removes all old non-pinned episodes', () async {
      for (var i = 0; i < 10; i++) {
        await insertEpisodeAt(daysAgo: 60, summary: 'Old $i');
      }
      for (var i = 0; i < 5; i++) {
        await insertEpisodeAt(
            daysAgo: 60, isPinned: true, summary: 'Pinned $i');
      }
      for (var i = 0; i < 3; i++) {
        await insertEpisodeAt(daysAgo: 5, summary: 'Recent $i');
      }

      final result = await service.runCleanup();
      expect(result.getOrNull(), equals(10));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(8)); // 5 pinned + 3 recent
    });

    test('episodes at exactly 30 days are not deleted', () async {
      await insertEpisodeAt(daysAgo: 30, summary: 'Boundary');
      await insertEpisodeAt(daysAgo: 31, summary: 'Just over');

      final result = await service.runCleanup();
      // daysAgo=31 should be deleted, daysAgo=30 should survive
      expect(result.getOrNull(), equals(1));

      final remaining = (await episodeDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.summary, equals('Boundary'));
    });
  });
}
