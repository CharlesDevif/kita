import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/consent_entry.dart';

final _log = KitaLogger('Memory');

class ConsentDao {
  ConsentDao(this._db);

  final db.KitaDatabase _db;

  ConsentEntry _toDomain(db.ConsentLogData row) {
    return ConsentEntry(
      id: row.id,
      consentType: row.consentType,
      scope: row.scope,
      granted: row.granted,
      grantedAt: row.grantedAt,
      revokedAt: row.revokedAt,
      details: row.details,
    );
  }

  Future<Result<int>> insert({
    required String consentType,
    required String scope,
    required bool granted,
    String? details,
  }) async {
    try {
      final id = await _db.into(_db.consentLog).insert(
            db.ConsentLogCompanion.insert(
              consentType: consentType,
              scope: scope,
              granted: granted,
              details: Value(details),
            ),
          );
      _log.debug('Consent entry inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert consent entry', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert consent'));
    }
  }

  Future<Result<ConsentEntry?>> getById(int id) async {
    try {
      final row = await (_db.select(_db.consentLog)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get consent entry', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get consent'));
    }
  }

  Future<Result<ConsentEntry?>> getActiveConsent({
    required String consentType,
    required String scope,
  }) async {
    try {
      final row = await (_db.select(_db.consentLog)
            ..where((t) =>
                t.consentType.equals(consentType) &
                t.scope.equals(scope) &
                t.granted.equals(true) &
                t.revokedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.grantedAt)])
            ..limit(1))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get active consent', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get active consent'));
    }
  }

  Future<Result<bool>> hasActiveConsent({
    required String consentType,
    required String scope,
  }) async {
    final result = await getActiveConsent(
      consentType: consentType,
      scope: scope,
    );
    return result.map((entry) => entry != null);
  }

  Future<Result<List<ConsentEntry>>> getAll() async {
    try {
      final rows = await (_db.select(_db.consentLog)
            ..orderBy([(t) => OrderingTerm.desc(t.grantedAt)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all consents', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all consents'));
    }
  }

  Future<Result<List<ConsentEntry>>> getActiveConsents() async {
    try {
      final rows = await (_db.select(_db.consentLog)
            ..where((t) => t.granted.equals(true) & t.revokedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.grantedAt)]))
          .get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get active consents', error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('get active consents'));
    }
  }

  Future<Result<bool>> revoke(int id) async {
    try {
      final count = await (_db.update(_db.consentLog)
            ..where((t) => t.id.equals(id)))
          .write(db.ConsentLogCompanion(
            revokedAt: Value(DateTime.now()),
          ));
      _log.info('Consent revoked');
      return Result.success(count > 0);
    } catch (e, stack) {
      _log.error('Failed to revoke consent', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('revoke consent'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.consentLog).go();
      _log.info('Deleted all consent entries ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all consents', error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('delete all consents'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM consent_log',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count consents', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count consents'));
    }
  }
}
