import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/features/ai/data/providers/gemma_failure.dart';

void main() {
  group('gemmaFailure', () {
    test('maps a StateError (an Error, not an Exception) to AIProviderFailure', () {
      final failure = gemmaFailure(StateError('already processing'));
      expect(failure, isA<AIProviderFailure>());
      expect(failure.providerId, 'gemma');
      // Message user par défaut, accentué, sans détail technique.
      expect(failure.userMessage, contains('reconnaissance'));
      expect(failure.userMessage, isNot(contains('StateError')));
      // Le détail technique est conservé côté log.
      expect(failure.logMessage, contains('already processing'));
    });

    test('maps an Exception too', () {
      final failure = gemmaFailure(Exception('boom'));
      expect(failure.providerId, 'gemma');
      expect(failure.logMessage, contains('boom'));
    });

    test('honours a custom user message', () {
      final failure = gemmaFailure(
        Exception('x'),
        userMessage: 'Le modèle IA est indisponible.',
      );
      expect(failure.userMessage, 'Le modèle IA est indisponible.');
    });
  });
}
