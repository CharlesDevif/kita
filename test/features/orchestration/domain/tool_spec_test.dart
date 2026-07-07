import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/orchestration/domain/tool_spec.dart';
import 'package:kita/features/orchestration/data/kita_tools.dart';

void main() {
  group('ToolSpec', () {
    group('toClaudeFormat()', () {
      test('produces valid JSON structure for describe tool', () {
        final json = KitaTools.describe.toClaudeFormat();

        expect(json['name'], equals('describe'));
        expect(json['description'], isA<String>());
        expect(json['description'], isNotEmpty);

        final inputSchema = json['input_schema'] as Map<String, dynamic>;
        expect(inputSchema['type'], equals('object'));

        final properties =
            inputSchema['properties'] as Map<String, dynamic>;
        expect(properties, contains('detail_level'));

        final detailLevel =
            properties['detail_level'] as Map<String, dynamic>;
        expect(detailLevel['type'], equals('string'));
        expect(detailLevel['enum'], equals(['brief', 'detailed']));
      });

      test('produces valid JSON structure for alert tool', () {
        final json = KitaTools.alert.toClaudeFormat();

        expect(json['name'], equals('alert'));
        expect(json['description'], isA<String>());

        final inputSchema = json['input_schema'] as Map<String, dynamic>;
        expect(inputSchema['type'], equals('object'));

        final properties =
            inputSchema['properties'] as Map<String, dynamic>;
        expect(properties, contains('action'));

        // 'action' is required
        final required = inputSchema['required'] as List;
        expect(required, contains('action'));

        final action = properties['action'] as Map<String, dynamic>;
        expect(action['type'], equals('string'));
        expect(action['enum'], equals(['start', 'stop']));
      });

      test('does not include required array when no required params', () {
        const spec = ToolSpec(
          name: 'test',
          description: 'Test tool',
          parameters: {
            'optional_param': ToolParameter(
              type: 'string',
              description: 'Optional',
            ),
          },
        );

        final json = spec.toClaudeFormat();
        final inputSchema = json['input_schema'] as Map<String, dynamic>;

        expect(inputSchema.containsKey('required'), isFalse);
      });

      test('handles tool with no parameters', () {
        const spec = ToolSpec(
          name: 'simple',
          description: 'Simple tool',
        );

        final json = spec.toClaudeFormat();

        expect(json['name'], equals('simple'));
        final inputSchema = json['input_schema'] as Map<String, dynamic>;
        expect(inputSchema['type'], equals('object'));
        expect(
          (inputSchema['properties'] as Map<String, dynamic>),
          isEmpty,
        );
      });
    });

    group('toOpenAIFormat()', () {
      test('produces valid function-calling structure for describe tool', () {
        final json = KitaTools.describe.toOpenAIFormat();

        expect(json['type'], equals('function'));

        final function_ = json['function'] as Map<String, dynamic>;
        expect(function_['name'], equals('describe'));
        expect(function_['description'], isA<String>());

        final parameters = function_['parameters'] as Map<String, dynamic>;
        expect(parameters['type'], equals('object'));

        final properties =
            parameters['properties'] as Map<String, dynamic>;
        expect(properties, contains('detail_level'));
      });

      test('produces valid function-calling structure for alert tool', () {
        final json = KitaTools.alert.toOpenAIFormat();

        expect(json['type'], equals('function'));

        final function_ = json['function'] as Map<String, dynamic>;
        expect(function_['name'], equals('alert'));

        final parameters = function_['parameters'] as Map<String, dynamic>;
        final required = parameters['required'] as List;
        expect(required, contains('action'));
      });

      test('does not include required array when no required params', () {
        const spec = ToolSpec(
          name: 'test',
          description: 'Test tool',
          parameters: {
            'opt': ToolParameter(
              type: 'string',
              description: 'Optional',
            ),
          },
        );

        final json = spec.toOpenAIFormat();
        final function_ = json['function'] as Map<String, dynamic>;
        final parameters = function_['parameters'] as Map<String, dynamic>;

        expect(parameters.containsKey('required'), isFalse);
      });
    });

    group('toGemmaPrompt()', () {
      test('produces readable text for describe tool', () {
        final prompt = KitaTools.describe.toGemmaPrompt();

        expect(prompt, contains('Outil "describe"'));
        expect(prompt, contains('Paramètres:'));
        expect(prompt, contains('detail_level'));
        expect(prompt, contains('(string)'));
        expect(prompt, contains('(optionnel)'));
        expect(prompt, contains('brief'));
        expect(prompt, contains('detailed'));
      });

      test('produces readable text for alert tool', () {
        final prompt = KitaTools.alert.toGemmaPrompt();

        expect(prompt, contains('Outil "alert"'));
        expect(prompt, contains('Paramètres:'));
        expect(prompt, contains('action'));
        expect(prompt, contains('(obligatoire)'));
        expect(prompt, contains('start'));
        expect(prompt, contains('stop'));
      });

      test('handles tool with no parameters', () {
        const spec = ToolSpec(
          name: 'simple',
          description: 'Outil simple sans parametres.',
        );

        final prompt = spec.toGemmaPrompt();

        expect(prompt, contains('Outil "simple"'));
        expect(prompt, contains('Outil simple sans parametres.'));
        expect(prompt, isNot(contains('Parametres:')));
      });

      test('includes enum values in brackets', () {
        const spec = ToolSpec(
          name: 'test',
          description: 'Test',
          parameters: {
            'mode': ToolParameter(
              type: 'string',
              description: 'Le mode',
              enumValues: ['a', 'b', 'c'],
            ),
          },
        );

        final prompt = spec.toGemmaPrompt();

        expect(prompt, contains('[a, b, c]'));
      });
    });
  });

  group('ToolParameter', () {
    test('_toJsonSchema produces correct JSON', () {
      // We test this indirectly through toClaudeFormat since _toJsonSchema
      // is private. The parameter with enum values should include them.
      const spec = ToolSpec(
        name: 'test',
        description: 'Test',
        parameters: {
          'color': ToolParameter(
            type: 'string',
            description: 'The color',
            isRequired: true,
            enumValues: ['red', 'blue'],
          ),
          'count': ToolParameter(
            type: 'integer',
            description: 'The count',
          ),
        },
      );

      final json = spec.toClaudeFormat();
      final inputSchema = json['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;

      final color = properties['color'] as Map<String, dynamic>;
      expect(color['type'], equals('string'));
      expect(color['description'], equals('The color'));
      expect(color['enum'], equals(['red', 'blue']));

      final count = properties['count'] as Map<String, dynamic>;
      expect(count['type'], equals('integer'));
      expect(count['description'], equals('The count'));
      expect(count.containsKey('enum'), isFalse);

      final required = inputSchema['required'] as List;
      expect(required, equals(['color']));
    });

    test('empty enumValues are not included in JSON', () {
      const spec = ToolSpec(
        name: 'test',
        description: 'Test',
        parameters: {
          'value': ToolParameter(
            type: 'string',
            description: 'A value',
            enumValues: [],
          ),
        },
      );

      final json = spec.toClaudeFormat();
      final inputSchema = json['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final value = properties['value'] as Map<String, dynamic>;

      expect(value.containsKey('enum'), isFalse);
    });
  });

  group('KitaTools', () {
    test('all returns both describe and alert', () {
      expect(KitaTools.all, hasLength(2));
      expect(KitaTools.all.map((t) => t.name), containsAll(['describe', 'alert']));
    });

    test('describe has expected structure', () {
      expect(KitaTools.describe.name, equals('describe'));
      expect(KitaTools.describe.parameters, contains('detail_level'));
    });

    test('alert has expected structure', () {
      expect(KitaTools.alert.name, equals('alert'));
      expect(KitaTools.alert.parameters, contains('action'));
      expect(KitaTools.alert.parameters['action']!.isRequired, isTrue);
    });
  });
}
