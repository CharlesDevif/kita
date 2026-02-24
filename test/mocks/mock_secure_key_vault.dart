import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/secure_key_vault.dart';

class MockSecureKeyVault implements SecureKeyVault {
  bool shouldFail = false;
  final Map<String, String> _store = {};

  @override
  Future<Result<String?>> read(String key) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.secureStorageError('read'));
    }
    return Result.success(_store[key]);
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.secureStorageError('write'));
    }
    _store[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.secureStorageError('delete'));
    }
    _store.remove(key);
    return const Result.success(null);
  }

  @override
  Future<Result<bool>> containsKey(String key) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.secureStorageError('containsKey'));
    }
    return Result.success(_store.containsKey(key));
  }

  @override
  Future<Result<void>> deleteAll() async {
    if (shouldFail) {
      return Result.failure(StorageFailure.secureStorageError('deleteAll'));
    }
    _store.clear();
    return const Result.success(null);
  }
}
