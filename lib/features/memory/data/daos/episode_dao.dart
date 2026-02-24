import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/episode.dart';

final _log = KitaLogger('Memory');

class EpisodeDao {
  EpisodeDao(this._db);

  final db.KitaDatabase _db;

  KitaEpisode _toDomain(db.Episode row) {
    return KitaEpisode(
      id: row.id,
      source: row.source,
      eventType: row.eventType,
      summary: row.summary,
      details: row.details,
      tags: _parseTags(row.tags),
      importanceScore: row.importanceScore,
      isPinned: row.isPinned,
      createdAt: row.createdAt,
      expiresAt: row.expiresAt,
    );
  }

  List<String> _parseTags(String? tags) {
    if (tags == null || tags.isEmpty) return [];
    return tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  String? _encodeTags(List<String> tags) {
    if (tags.isEmpty) return null;
    return tags.join(',');
  }

  Future<Result<int>> insert({
    required String source,
    required String eventType,
    required String summary,
    String? details,
    List<String> tags = const [],
    double importanceScore = 0.5,
    bool isPinned = false,
    DateTime? expiresAt,
  }) async {
    try {
      final id = await _db.into(_db.episodes).insert(
            db.EpisodesCompanion.insert(
              source: source,
              eventType: eventType,
              summary: summary,
              details: Value(details),
              tags: Value(_encodeTags(tags)),
              importanceScore: Value(importanceScore),
              isPinned: Value(isPinned),
              expiresAt: Value(expiresAt),
            ),
          );
      _log.debug('Episode inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert episode', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert episode'));
    }
  }

  Future<Result<KitaEpisode?>> getById(int id) async {
    try {
      final row = await (_db.select(_db.episodes)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get episode', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get episode'));
    }
  }

  Future<Result<List<KitaEpisode>>> getAll() async {
    try {
      final rows = await (_db.select(_db.episodes)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all episodes', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all episodes'));
    }
  }

  Future<Result<List<KitaEpisode>>> getExpiredBefore(DateTime cutoff) async {
    try {
      final rows = await (_db.select(_db.episodes)
            ..where(
                (t) => t.isPinned.equals(false) & t.createdAt.isSmallerThanValue(cutoff)))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get expired episodes', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get expired episodes'));
    }
  }

  Future<Result<int>> deleteById(int id) async {
    try {
      final count = await (_db.delete(_db.episodes)
            ..where((t) => t.id.equals(id)))
          .go();
      _log.debug('Deleted $count episode(s)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete episode', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete episode'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.episodes).go();
      _log.info('Deleted all episodes ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all episodes', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete all episodes'));
    }
  }

  Future<Result<int>> deleteExpiredBefore(DateTime cutoff) async {
    try {
      final count = await (_db.delete(_db.episodes)
            ..where(
                (t) => t.isPinned.equals(false) & t.expiresAt.isSmallerThanValue(cutoff)))
          .go();
      _log.info('Cleaned up $count expired episode(s)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete expired episodes', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete expired episodes'));
    }
  }

  Future<Result<bool>> update(int id, {
    String? summary,
    String? details,
    List<String>? tags,
    double? importanceScore,
    bool? isPinned,
  }) async {
    try {
      final count = await (_db.update(_db.episodes)
            ..where((t) => t.id.equals(id)))
          .write(db.EpisodesCompanion(
            summary: summary != null ? Value(summary) : const Value.absent(),
            details: details != null ? Value(details) : const Value.absent(),
            tags: tags != null ? Value(_encodeTags(tags)) : const Value.absent(),
            importanceScore: importanceScore != null
                ? Value(importanceScore)
                : const Value.absent(),
            isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
          ));
      return Result.success(count > 0);
    } catch (e, stack) {
      _log.error('Failed to update episode', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('update episode'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM episodes',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count episodes', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count episodes'));
    }
  }
}
