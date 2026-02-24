import 'package:flutter_test/flutter_test.dart';

import '../../../../test/mocks/mock_secure_key_vault.dart';

void main() {
  late MockSecureKeyVault vault;

  setUp(() {
    vault = MockSecureKeyVault();
  });

  group('SecureKeyVault interface', () {
    test('read returns null for missing key', () async {
      final result = await vault.read('missing');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('write then read returns value', () async {
      await vault.write('key', 'value');
      final result = await vault.read('key');
      expect(result.getOrNull(), equals('value'));
    });

    test('delete removes key', () async {
      await vault.write('key', 'value');
      await vault.delete('key');
      final result = await vault.read('key');
      expect(result.getOrNull(), isNull);
    });

    test('containsKey returns true when present', () async {
      await vault.write('key', 'value');
      final result = await vault.containsKey('key');
      expect(result.getOrNull(), isTrue);
    });

    test('containsKey returns false when absent', () async {
      final result = await vault.containsKey('missing');
      expect(result.getOrNull(), isFalse);
    });

    test('deleteAll clears all keys', () async {
      await vault.write('a', '1');
      await vault.write('b', '2');
      await vault.deleteAll();
      expect((await vault.containsKey('a')).getOrNull(), isFalse);
      expect((await vault.containsKey('b')).getOrNull(), isFalse);
    });

    test('shouldFail mode returns failures', () async {
      vault.shouldFail = true;
      expect((await vault.read('key')).isFailure, isTrue);
      expect((await vault.write('key', 'val')).isFailure, isTrue);
      expect((await vault.delete('key')).isFailure, isTrue);
      expect((await vault.containsKey('key')).isFailure, isTrue);
      expect((await vault.deleteAll()).isFailure, isTrue);
    });
  });
}
