import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/core/config/database_config.dart';

/// In-memory fake of FlutterSecureStorage for testing.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DatabaseConfig', () {
    test('getOrCreateEncryptionKey generates a base64url key from 32 bytes',
        () async {
      final storage = FakeSecureStorage();
      final key = await DatabaseConfig.getOrCreateEncryptionKey(
        storage: storage,
      );
      // 32 bytes → base64url → 43-44 characters
      expect(key.length, greaterThanOrEqualTo(43));
      final decoded = base64Url.decode(key);
      expect(decoded, hasLength(32));
    });

    test('getOrCreateEncryptionKey returns same key on second call', () async {
      final storage = FakeSecureStorage();
      final key1 = await DatabaseConfig.getOrCreateEncryptionKey(
        storage: storage,
      );
      final key2 = await DatabaseConfig.getOrCreateEncryptionKey(
        storage: storage,
      );
      expect(key1, equals(key2));
    });

    test('getOrCreateEncryptionKey generates unique keys per storage',
        () async {
      final storage1 = FakeSecureStorage();
      final storage2 = FakeSecureStorage();
      final key1 = await DatabaseConfig.getOrCreateEncryptionKey(
        storage: storage1,
      );
      final key2 = await DatabaseConfig.getOrCreateEncryptionKey(
        storage: storage2,
      );
      expect(key1, isNot(equals(key2)));
    });
  });
}
