import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/preference.dart';

final _log = KitaLogger('Memory');

class PreferenceDao {
  PreferenceDao(this._db);

  final db.KitaDatabase _db;

  KitaPreference _toDomain(db.Preference row) {
    return KitaPreference(
      id: row.id,
      category: row.category,
      key: row.prefKey,
      value: row.value,
      confidenceScore: row.confidenceScore,
      source: row.source,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<Result<int>> insert({
    required String category,
    required String key,
    required String value,
    double confidenceScore = 0.5,
    required String source,
  }) async {
    try {
      final id = await _db.into(_db.preferences).insert(
            db.PreferencesCompanion.insert(
              category: category,
              prefKey: key,
              value: value,
              confidenceScore: Value(confidenceScore),
              source: source,
            ),
          );
      _log.debug('Preference inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert preference', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert preference'));
    }
  }

  Future<Result<KitaPreference?>> getByKey(String key) async {
    try {
      final row = await (_db.select(_db.preferences)
            ..where((t) => t.prefKey.equals(key))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get preference', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get preference'));
    }
  }

  Future<Result<KitaPreference?>> getById(int id) async {
    try {
      final row = await (_db.select(_db.preferences)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get preference by id', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get preference by id'));
    }
  }

  Future<Result<List<KitaPreference>>> getByCategory(String category) async {
    try {
      final rows = await (_db.select(_db.preferences)
            ..where((t) => t.category.equals(category))
            ..orderBy([(t) => OrderingTerm.asc(t.prefKey)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get preferences by category',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('get preferences by category'));
    }
  }

  Future<Result<List<KitaPreference>>> getAll() async {
    try {
      final rows = await (_db.select(_db.preferences)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all preferences', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all preferences'));
    }
  }

  Future<Result<bool>> upsert({
    required String category,
    required String key,
    required String value,
    double? confidenceScore,
    required String source,
  }) async {
    try {
      final existing = await (_db.select(_db.preferences)
            ..where((t) => t.prefKey.equals(key) & t.category.equals(category)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.preferences)
              ..where((t) => t.id.equals(existing.id)))
            .write(db.PreferencesCompanion(
              value: Value(value),
              confidenceScore: confidenceScore != null
                  ? Value(confidenceScore)
                  : const Value.absent(),
              source: Value(source),
              updatedAt: Value(DateTime.now()),
            ));
        _log.debug('Preference updated');
        return const Result.success(true);
      } else {
        final insertResult = await insert(
          category: category,
          key: key,
          value: value,
          confidenceScore: confidenceScore ?? 0.5,
          source: source,
        );
        return insertResult.map((_) => true);
      }
    } catch (e, stack) {
      _log.error('Failed to upsert preference', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('upsert preference'));
    }
  }

  Future<Result<int>> deleteByKey(String key) async {
    try {
      final count = await (_db.delete(_db.preferences)
            ..where((t) => t.prefKey.equals(key)))
          .go();
      _log.debug('Deleted $count preference(s)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete preference', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete preference'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.preferences).go();
      _log.info('Deleted all preferences ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all preferences',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('delete all preferences'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM preferences',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count preferences', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count preferences'));
    }
  }
}
