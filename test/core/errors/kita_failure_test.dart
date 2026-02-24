import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';

void main() {
  group('KitaFailure sealed class', () {
    test('NetworkFailure exposes userMessage and logMessage', () {
      const failure = NetworkFailure(
        userMessage: 'User msg',
        logMessage: 'Log msg',
      );
      expect(failure.userMessage, 'User msg');
      expect(failure.logMessage, 'Log msg');
      expect(failure.cause, isNull);
      expect(failure.stackTrace, isNull);
    });

    test('AIProviderFailure exposes providerId', () {
      const failure = AIProviderFailure(
        userMessage: 'User msg',
        logMessage: 'Log msg',
        providerId: 'openai',
      );
      expect(failure.providerId, 'openai');
    });

    test('PluginFailure exposes pluginId', () {
      const failure = PluginFailure(
        userMessage: 'User msg',
        logMessage: 'Log msg',
        pluginId: 'com.kita.describe',
      );
      expect(failure.pluginId, 'com.kita.describe');
    });

    test('PermissionFailure exposes permission', () {
      const failure = PermissionFailure(
        userMessage: 'User msg',
        logMessage: 'Log msg',
        permission: 'camera',
      );
      expect(failure.permission, 'camera');
    });

    test('UnexpectedFailure has fixed userMessage', () {
      const failure = UnexpectedFailure(logMessage: 'Oops');
      expect(failure.userMessage, 'Une erreur inattendue est survenue.');
      expect(failure.logMessage, 'Oops');
    });

    test('cause and stackTrace are accessible', () {
      final error = Exception('test');
      final stack = StackTrace.current;
      final failure = NetworkFailure(
        userMessage: 'User msg',
        logMessage: 'Log msg',
        cause: error,
        stackTrace: stack,
      );
      expect(failure.cause, error);
      expect(failure.stackTrace, stack);
    });

    test('toString returns runtimeType: logMessage', () {
      const failure = StorageFailure(
        userMessage: 'User msg',
        logMessage: 'DB write failed',
      );
      expect(failure.toString(), 'StorageFailure: DB write failed');
    });

    test('exhaustive switch covers all subtypes', () {
      final failures = <KitaFailure>[
        const NetworkFailure(userMessage: 'u', logMessage: 'l'),
        const AIProviderFailure(userMessage: 'u', logMessage: 'l'),
        const PluginFailure(userMessage: 'u', logMessage: 'l'),
        const StorageFailure(userMessage: 'u', logMessage: 'l'),
        const PermissionFailure(userMessage: 'u', logMessage: 'l'),
        const UnexpectedFailure(logMessage: 'l'),
      ];

      for (final f in failures) {
        // Compile-time exhaustive — no default needed.
        final label = switch (f) {
          NetworkFailure() => 'network',
          AIProviderFailure() => 'ai',
          PluginFailure() => 'plugin',
          StorageFailure() => 'storage',
          PermissionFailure() => 'permission',
          UnexpectedFailure() => 'unexpected',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('Factory constructors', () {
    test('NetworkFailure.timeout()', () {
      final f = NetworkFailure.timeout(endpoint: '/api/chat');
      expect(f.logMessage, contains('/api/chat'));
      expect(f.userMessage, isNotEmpty);
    });

    test('NetworkFailure.timeout() without endpoint', () {
      final f = NetworkFailure.timeout();
      expect(f.logMessage, 'Network timeout');
    });

    test('NetworkFailure.noConnection()', () {
      final f = NetworkFailure.noConnection();
      expect(f.logMessage, contains('No network'));
    });

    test('AIProviderFailure.rateLimited()', () {
      final f = AIProviderFailure.rateLimited('openai');
      expect(f.providerId, 'openai');
      expect(f.logMessage, contains('Rate limited'));
    });

    test('AIProviderFailure.invalidApiKey()', () {
      final f = AIProviderFailure.invalidApiKey('anthropic');
      expect(f.logMessage, contains('Invalid API key'));
    });

    test('AIProviderFailure.modelUnavailable()', () {
      final f = AIProviderFailure.modelUnavailable('openai', 'gpt-4');
      expect(f.logMessage, contains('gpt-4'));
    });

    test('PluginFailure.sandboxViolation()', () {
      final f = PluginFailure.sandboxViolation('com.kita.test', 'camera');
      expect(f.logMessage, contains('Sandbox violation'));
      expect(f.pluginId, 'com.kita.test');
    });

    test('PluginFailure.timeout()', () {
      final f = PluginFailure.timeout('com.kita.slow');
      expect(f.logMessage, contains('timed out'));
    });

    test('StorageFailure.databaseError()', () {
      final f = StorageFailure.databaseError('insert');
      expect(f.logMessage, contains('insert'));
    });

    test('StorageFailure.secureStorageError()', () {
      final f = StorageFailure.secureStorageError('read');
      expect(f.logMessage, contains('Secure storage'));
    });

    test('PermissionFailure.denied()', () {
      final f = PermissionFailure.denied('microphone');
      expect(f.permission, 'microphone');
      expect(f.logMessage, contains('denied'));
    });

    test('PermissionFailure.permanentlyDenied()', () {
      final f = PermissionFailure.permanentlyDenied('location');
      expect(f.logMessage, contains('permanently denied'));
    });
  });
}
