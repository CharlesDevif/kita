import '../../../core/errors/result.dart';

/// Secure key-value storage for sensitive data (API keys, tokens).
///
/// Backed by Keychain (iOS) / Keystore (Android) via flutter_secure_storage.
/// API keys are NEVER stored in plaintext or logged.
abstract interface class SecureKeyVault {
  /// Reads a secure value by key. Returns null if not found.
  Future<Result<String?>> read(String key);

  /// Writes a secure value. Overwrites existing value if present.
  Future<Result<void>> write(String key, String value);

  /// Deletes a secure value by key.
  Future<Result<void>> delete(String key);

  /// Checks whether a key exists in secure storage.
  Future<Result<bool>> containsKey(String key);

  /// Deletes all secure values.
  Future<Result<void>> deleteAll();
}
