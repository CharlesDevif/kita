import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';

void main() {
  group('parseLocalToolResponse', () {
    test('format compact sans argument', () {
      final call = parseLocalToolResponse('TOOL describe');
      expect(call, isNotNull);
      expect(call!.name, 'describe');
      expect(call.firstArg, isNull);
    });

    test('format compact avec argument', () {
      final call = parseLocalToolResponse('TOOL alert start');
      expect(call!.name, 'alert');
      expect(call.firstArg, 'start');
    });

    test('tolère les espaces et une ligne de bavardage avant', () {
      final call = parseLocalToolResponse('Bien sûr.\n  TOOL describe  ');
      expect(call!.name, 'describe');
    });

    test('accepte encore le JSON legacy', () {
      final call = parseLocalToolResponse(
        '{"tool_call": {"name": "alert", "arguments": {"action": "stop"}}}',
      );
      expect(call!.name, 'alert');
      expect(call.arguments['action'], 'stop');
    });

    test('texte simple → pas d\'appel d\'outil', () {
      expect(parseLocalToolResponse('Bonjour ! Comment vas-tu ?'), isNull);
    });

    test('outil inconnu → pas d\'appel d\'outil', () {
      expect(parseLocalToolResponse('TOOL inventer'), isNull);
    });
  });
}
