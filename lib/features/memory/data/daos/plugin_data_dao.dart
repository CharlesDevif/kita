import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/plugin_data_entry.dart';

final _log = KitaLogger('Memory');

class PluginDataDao {
  PluginDataDao(this._db);

  final db.KitaDatabase _db;

  PluginDataEntry _toDomain(db.PluginDataData row) {
    return PluginDataEntry(
      id: row.id,
      pluginId: row.pluginId,
      namespace: row.namespace,
      key: row.dataKey,
      value: row.value,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<Result<int>> insert({
    required String pluginId,
    required String namespace,
    required String key,
    required String value,
  }) async {
    try {
      final id = await _db.into(_db.pluginData).insert(
            db.PluginDataCompanion.insert(
              pluginId: pluginId,
              namespace: namespace,
              dataKey: key,
              value: value,
            ),
          );
      _log.debug('Plugin data inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert plugin data', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert plugin data'));
    }
  }

  Future<Result<PluginDataEntry?>> get({
    required String pluginId,
    required String namespace,
    required String key,
  }) async {
    try {
      final row = await (_db.select(_db.pluginData)
            ..where((t) =>
                t.pluginId.equals(pluginId) &
                t.namespace.equals(namespace) &
                t.dataKey.equals(key)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get plugin data', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get plugin data'));
    }
  }

  Future<Result<List<PluginDataEntry>>> getByPlugin(String pluginId) async {
    try {
      final rows = await (_db.select(_db.pluginData)
            ..where((t) => t.pluginId.equals(pluginId))
            ..orderBy([(t) => OrderingTerm.asc(t.namespace),
                       (t) => OrderingTerm.asc(t.dataKey)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get plugin data by plugin',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('get plugin data by plugin'));
    }
  }

  Future<Result<List<PluginDataEntry>>> getByNamespace(
    String pluginId,
    String namespace,
  ) async {
    try {
      final rows = await (_db.select(_db.pluginData)
            ..where((t) =>
                t.pluginId.equals(pluginId) & t.namespace.equals(namespace))
            ..orderBy([(t) => OrderingTerm.asc(t.dataKey)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get plugin data by namespace',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('get plugin data by namespace'));
    }
  }

  Future<Result<List<PluginDataEntry>>> getAll() async {
    try {
      final rows = await (_db.select(_db.pluginData)
            ..orderBy([(t) => OrderingTerm.asc(t.pluginId)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all plugin data', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all plugin data'));
    }
  }

  Future<Result<bool>> upsert({
    required String pluginId,
    required String namespace,
    required String key,
    required String value,
  }) async {
    try {
      final existing = await (_db.select(_db.pluginData)
            ..where((t) =>
                t.pluginId.equals(pluginId) &
                t.namespace.equals(namespace) &
                t.dataKey.equals(key)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.pluginData)
              ..where((t) => t.id.equals(existing.id)))
            .write(db.PluginDataCompanion(
              value: Value(value),
              updatedAt: Value(DateTime.now()),
            ));
        _log.debug('Plugin data updated');
        return const Result.success(true);
      } else {
        await insert(
          pluginId: pluginId,
          namespace: namespace,
          key: key,
          value: value,
        );
        return const Result.success(true);
      }
    } catch (e, stack) {
      _log.error('Failed to upsert plugin data', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('upsert plugin data'));
    }
  }

  Future<Result<int>> deleteByPlugin(String pluginId) async {
    try {
      final count = await (_db.delete(_db.pluginData)
            ..where((t) => t.pluginId.equals(pluginId)))
          .go();
      _log.info('Deleted $count plugin data row(s) for plugin');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete plugin data', error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('delete plugin data by plugin'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.pluginData).go();
      _log.info('Deleted all plugin data ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all plugin data',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('delete all plugin data'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM plugin_data',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count plugin data', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count plugin data'));
    }
  }
}
