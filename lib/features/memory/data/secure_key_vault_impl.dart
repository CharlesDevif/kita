import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/secure_key_vault.dart';

final _log = KitaLogger('Memory');

/// Implementation of [SecureKeyVault] backed by flutter_secure_storage.
///
/// Uses Keychain (iOS) / Keystore (Android) for hardware-backed encryption.
/// API keys and tokens are NEVER stored in plaintext or logged.
class SecureKeyVaultImpl implements SecureKeyVault {
  SecureKeyVaultImpl({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      _log.debug('Secure key read: $key (found=${value != null})');
      return Result.success(value);
    } catch (e, stack) {
      _log.error('Failed to read secure key', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.secureStorageError('read'));
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      _log.debug('Secure key written: $key');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Failed to write secure key', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.secureStorageError('write'));
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      _log.debug('Secure key deleted: $key');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Failed to delete secure key', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.secureStorageError('delete'));
    }
  }

  @override
  Future<Result<bool>> containsKey(String key) async {
    try {
      final exists = await _storage.containsKey(key: key);
      return Result.success(exists);
    } catch (e, stack) {
      _log.error('Failed to check secure key',
          error: e, stackTrace: stack);
      return Result.failure(StorageFailure.secureStorageError('containsKey'));
    }
  }

  @override
  Future<Result<void>> deleteAll() async {
    try {
      await _storage.deleteAll();
      _log.info('All secure keys deleted');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Failed to delete all secure keys',
          error: e, stackTrace: stack);
      return Result.failure(StorageFailure.secureStorageError('deleteAll'));
    }
  }
}
