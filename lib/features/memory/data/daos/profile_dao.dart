import 'package:drift/drift.dart';

import '../../../../core/data/database.dart' as db;
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/user_profile.dart';

final _log = KitaLogger('Memory');

class ProfileDao {
  ProfileDao(this._db);

  final db.KitaDatabase _db;

  KitaUserProfile _toDomain(db.UserProfile row) {
    return KitaUserProfile(
      id: row.id,
      displayName: row.displayName,
      accessibilityProfile: row.accessibilityProfile,
      language: row.language,
      ttsSpeed: row.ttsSpeed,
      ttsVoice: row.ttsVoice,
      hapticEnabled: row.hapticEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<Result<int>> insert({
    String? displayName,
    String accessibilityProfile = 'standard',
    String language = 'fr',
    double ttsSpeed = 1.0,
    String? ttsVoice,
    bool hapticEnabled = true,
  }) async {
    try {
      final id = await _db.into(_db.userProfiles).insert(
            db.UserProfilesCompanion.insert(
              displayName: Value(displayName),
              accessibilityProfile: Value(accessibilityProfile),
              language: Value(language),
              ttsSpeed: Value(ttsSpeed),
              ttsVoice: Value(ttsVoice),
              hapticEnabled: Value(hapticEnabled),
            ),
          );
      _log.debug('Profile inserted with id=$id');
      return Result.success(id);
    } catch (e, stack) {
      _log.error('Failed to insert profile', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('insert profile'));
    }
  }

  Future<Result<KitaUserProfile?>> getById(int id) async {
    try {
      final row = await (_db.select(_db.userProfiles)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get profile', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get profile'));
    }
  }

  Future<Result<KitaUserProfile?>> getActive() async {
    try {
      final row = await (_db.select(_db.userProfiles)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();
      return Result.success(row == null ? null : _toDomain(row));
    } catch (e, stack) {
      _log.error('Failed to get active profile', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get active profile'));
    }
  }

  Future<Result<List<KitaUserProfile>>> getAll() async {
    try {
      final rows = await _db.select(_db.userProfiles).get();
      return Result.success(rows.map(_toDomain).toList());
    } catch (e, stack) {
      _log.error('Failed to get all profiles', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('get all profiles'));
    }
  }

  Future<Result<bool>> update(int id, {
    String? displayName,
    String? accessibilityProfile,
    String? language,
    double? ttsSpeed,
    String? ttsVoice,
    bool? hapticEnabled,
  }) async {
    try {
      final count = await (_db.update(_db.userProfiles)
            ..where((t) => t.id.equals(id)))
          .write(db.UserProfilesCompanion(
            displayName:
                displayName != null ? Value(displayName) : const Value.absent(),
            accessibilityProfile: accessibilityProfile != null
                ? Value(accessibilityProfile)
                : const Value.absent(),
            language: language != null ? Value(language) : const Value.absent(),
            ttsSpeed: ttsSpeed != null ? Value(ttsSpeed) : const Value.absent(),
            ttsVoice: ttsVoice != null ? Value(ttsVoice) : const Value.absent(),
            hapticEnabled: hapticEnabled != null
                ? Value(hapticEnabled)
                : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ));
      return Result.success(count > 0);
    } catch (e, stack) {
      _log.error('Failed to update profile', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('update profile'));
    }
  }

  Future<Result<int>> deleteById(int id) async {
    try {
      final count = await (_db.delete(_db.userProfiles)
            ..where((t) => t.id.equals(id)))
          .go();
      _log.debug('Deleted $count profile(s)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete profile', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete profile'));
    }
  }

  Future<Result<int>> deleteAll() async {
    try {
      final count = await _db.delete(_db.userProfiles).go();
      _log.info('Deleted all profiles ($count rows)');
      return Result.success(count);
    } catch (e, stack) {
      _log.error('Failed to delete all profiles', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('delete all profiles'));
    }
  }

  Future<Result<int>> count() async {
    try {
      final result = await _db.customSelect(
        'SELECT COUNT(*) AS cnt FROM user_profiles',
      ).getSingle();
      return Result.success(result.read<int>('cnt'));
    } catch (e, stack) {
      _log.error('Failed to count profiles', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('count profiles'));
    }
  }
}
