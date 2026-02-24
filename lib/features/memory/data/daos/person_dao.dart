import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/person.dart';

final _log = KitaLogger('Memory');

class PersonDao {
  PersonDao(this._db);

  final db.KitaDatabase _db;

  KitaPerson _toDomain(db.Person row) {
    return KitaPerson(
      id: row.id,
      name: row.name,
      relationship: row.relationship,
      notes: row.notes,
      interests: _parseList(row.interests),
      lastMentionedAt: row.lastMentionedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  List<String> _parseList(String? csv) {
    if (csv == null || csv.isEmpty) return [];
    return csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  String? _encodeList(List<String> items) {
    if (items.isEmpty) return null;
    return items.join(',');
  }

  Future<Result<int>> insert({
    required String name,
    String? relationship,
    String? notes,
    List<String> interests = const [],
  }) async {
    try {
      final id = await _db.into(_db.persons).insert(
            db.PersonsCompanion.insert(
              name: name,
              relationship: Value(relationship),
              notes: Value(notes),
              interests: Value(_encodeList(interests)),
            ),
          );
      _log.debug('Person inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert person', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert person'));
    }
  }

  Future<Result<KitaPerson?>> getById(int id) async {
    try {
      final row = await (_db.select(_db.persons)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get person', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get person'));
    }
  }

  Future<Result<KitaPerson?>> getByName(String name) async {
    try {
      final row = await (_db.select(_db.persons)
            ..where((t) => t.name.equals(name)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get person by name', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get person by name'));
    }
  }

  Future<Result<List<KitaPerson>>> getAll() async {
    try {
      final rows = await (_db.select(_db.persons)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all persons', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all persons'));
    }
  }

  Future<Result<bool>> update(int id, {
    String? name,
    String? relationship,
    String? notes,
    List<String>? interests,
    DateTime? lastMentionedAt,
  }) async {
    try {
      final count = await (_db.update(_db.persons)
            ..where((t) => t.id.equals(id)))
          .write(db.PersonsCompanion(
            name: name != null ? Value(name) : const Value.absent(),
            relationship:
                relationship != null ? Value(relationship) : const Value.absent(),
            notes: notes != null ? Value(notes) : const Value.absent(),
            interests: interests != null
                ? Value(_encodeList(interests))
                : const Value.absent(),
            lastMentionedAt: lastMentionedAt != null
                ? Value(lastMentionedAt)
                : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ));
      return Result.success(count > 0);
    } catch (e, stack) {
      _log.error('Failed to update person', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('update person'));
    }
  }

  Future<Result<int>> deleteById(int id) async {
    try {
      final count = await (_db.delete(_db.persons)
            ..where((t) => t.id.equals(id)))
          .go();
      _log.debug('Deleted $count person(s)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete person', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete person'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.persons).go();
      _log.info('Deleted all persons ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all persons', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete all persons'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM persons',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count persons', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count persons'));
    }
  }
}
