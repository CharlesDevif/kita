import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/openai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';
import 'package:kita/features/ai/domain/tool_models.dart';

http_testing.MockClient _mockClient(
  Future<http.Response> Function(http.Request) handler,
) {
  return http_testing.MockClient(handler);
}

String _successBody(String text) => jsonEncode({
      'choices': [
        {
          'message': {'content': text},
        },
      ],
    });

void main() {
  group('OpenAIProvider', () {
    group('properties', () {
      test('has correct id, displayName, tier', () {
        final provider = OpenAIProvider(apiKey: 'test-key');
        expect(provider.id, equals('openai'));
        expect(provider.displayName, equals('OpenAI'));
        expect(provider.tier, equals(ProviderTier.cloudFast));
      });

      test('isAvailable is true when API key is present', () {
        final provider = OpenAIProvider(apiKey: 'test-key');
        expect(provider.isAvailable, isTrue);
      });

      test('isAvailable is false when API key is empty', () {
        final provider = OpenAIProvider(apiKey: '');
        expect(provider.isAvailable, isFalse);
      });
    });

    group('complete()', () {
      test('returns success on 200 response', () async {
        final client = _mockClient((request) async {
          expect(request.url.toString(),
              contains('api.openai.com/v1/chat/completions'));
          expect(request.headers['authorization'], equals('Bearer test-key'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], isNotEmpty);
          expect(body['messages'], isList);

          return http.Response(_successBody('Hello from OpenAI'), 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'Hello', priority: RequestPriority.standard),
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.content, equals('Hello from OpenAI'));
        expect(response.meta.providerId, equals('openai'));
        expect(response.meta.tier, equals(ProviderTier.cloudFast));
        expect(response.status, equals(AIResponseStatus.success));
      });

      test('returns failure on 401', () async {
        final client = _mockClient((_) async {
          return http.Response('unauthorized', 401);
        });

        final provider =
            OpenAIProvider(apiKey: 'bad-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<AIProviderFailure>());
      });

      test('returns failure on 429', () async {
        final client = _mockClient((_) async {
          return http.Response('rate limited', 429);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
      });

      test('returns failure on 500', () async {
        final client = _mockClient((_) async {
          return http.Response('error', 500);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
      });

      test('returns NetworkFailure on connection error', () async {
        final client = _mockClient((_) async {
          throw Exception('Connection refused');
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<NetworkFailure>());
      });

      test('returns failure on malformed JSON response', () async {
        final client = _mockClient((_) async {
          return http.Response('not json', 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
      });
    });

    group('vision()', () {
      test('sends image as data URL with correct structure', () async {
        final client = _mockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = body['messages'] as List;
          final content = (messages[0] as Map)['content'] as List;

          // First block should be image_url
          expect(content[0]['type'], equals('image_url'));
          expect(
            content[0]['image_url']['url'],
            startsWith('data:image/jpeg;base64,'),
          );

          // Second block should be text
          expect(content[1]['type'], equals('text'));
          expect(content[1]['text'], equals('what is this'));

          return http.Response(_successBody('A photo of a cat'), 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.vision(
          ImageData(bytes: Uint8List.fromList([1, 2, 3])),
          'what is this',
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.content, equals('A photo of a cat'));
      });
    });

    group('validateApiKey()', () {
      test('returns success on valid key', () async {
        final client = _mockClient((_) async {
          return http.Response(_successBody('ok'), 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('valid');

        expect(result.isSuccess, isTrue);
      });

      test('returns failure on 401', () async {
        final client = _mockClient((_) async {
          return http.Response('unauthorized', 401);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('bad');

        expect(result.isFailure, isTrue);
      });

      test('returns NetworkFailure on connection error', () async {
        final client = _mockClient((_) async {
          throw Exception('No connection');
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('key');

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<NetworkFailure>());
      });
    });

    group('completeWithTools()', () {
      test('sends tools with correct OpenAI format (type: function)', () async {
        Map<String, dynamic>? sentBody;
        final client = _mockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'Let me check.',
                    'tool_calls': [
                      {
                        'id': 'call_abc123',
                        'type': 'function',
                        'function': {
                          'name': 'get_weather',
                          'arguments': '{"location":"Paris"}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        await provider.completeWithTools(
          const AIRequest(prompt: 'Weather in Paris?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Get current weather',
              parameters: {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
              },
            ),
          ],
        );

        // Verify OpenAI format: tools use {type: "function", function: {name, description, parameters}}
        final tools = sentBody!['tools'] as List;
        final tool = tools[0] as Map<String, dynamic>;
        expect(tool['type'], equals('function'));
        expect(tool.containsKey('function'), isTrue);
        final fn = tool['function'] as Map<String, dynamic>;
        expect(fn['name'], equals('get_weather'));
        expect(fn['description'], equals('Get current weather'));
        expect(fn['parameters'], isA<Map>());
        expect((fn['parameters'] as Map)['required'], equals(['location']));
        // Should NOT have top-level "input_schema" (that's Anthropic format)
        expect(tool.containsKey('input_schema'), isFalse);
      });

      test('parses tool_calls response correctly', () async {
        final client = _mockClient((_) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'Checking weather.',
                    'tool_calls': [
                      {
                        'id': 'call_xyz',
                        'type': 'function',
                        'function': {
                          'name': 'get_weather',
                          'arguments': '{"location":"Paris","unit":"celsius"}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'Weather in Paris?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.text, equals('Checking weather.'));
        expect(response.hasToolCalls, isTrue);
        expect(response.toolCalls, hasLength(1));
        expect(response.toolCalls[0].id, equals('call_xyz'));
        expect(response.toolCalls[0].name, equals('get_weather'));
        expect(response.toolCalls[0].arguments['location'], equals('Paris'));
        expect(response.toolCalls[0].arguments['unit'], equals('celsius'));
        expect(response.meta.providerId, equals('openai'));
        expect(response.meta.tier, equals(ProviderTier.cloudFast));
      });

      test('parses text-only response (no tool calls)', () async {
        final client = _mockClient((_) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'I cannot help with that.',
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'Hello'),
          tools: [
            const ToolSpec(
              name: 'tool1',
              description: 'A tool',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.hasText, isTrue);
        expect(response.hasToolCalls, isFalse);
        expect(response.text, equals('I cannot help with that.'));
      });

      test('parses multiple parallel tool calls', () async {
        final client = _mockClient((_) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': null,
                    'tool_calls': [
                      {
                        'id': 'call_1',
                        'type': 'function',
                        'function': {
                          'name': 'get_weather',
                          'arguments': '{"location":"Paris"}',
                        },
                      },
                      {
                        'id': 'call_2',
                        'type': 'function',
                        'function': {
                          'name': 'get_time',
                          'arguments': '{"timezone":"Europe/Paris"}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'Weather and time in Paris?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
            const ToolSpec(
              name: 'get_time',
              description: 'Time',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.text, isNull);
        expect(response.toolCalls, hasLength(2));
        expect(response.toolCalls[0].name, equals('get_weather'));
        expect(response.toolCalls[1].name, equals('get_time'));
      });

      test('handles malformed tool call arguments gracefully', () async {
        final client = _mockClient((_) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': null,
                    'tool_calls': [
                      {
                        'id': 'call_bad',
                        'type': 'function',
                        'function': {
                          'name': 'get_weather',
                          'arguments': 'not valid json',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'test'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        // Should still succeed — arguments default to empty map
        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIToolResponse>).value;
        expect(response.toolCalls[0].arguments, isEmpty);
      });

      test('serializes conversation history correctly', () async {
        Map<String, dynamic>? sentBody;
        final client = _mockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'The weather is 15C.'},
                },
              ],
            }),
            200,
          );
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        await provider.completeWithTools(
          const AIRequest(prompt: 'And tomorrow?'),
          tools: [
            const ToolSpec(
              name: 'get_weather',
              description: 'Weather',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
          history: [
            const ConversationMessage.user('Weather in Paris?'),
            ConversationMessage.assistantToolCalls([
              const ToolCall(
                id: 'call_prev1',
                name: 'get_weather',
                arguments: {'location': 'Paris'},
              ),
            ]),
            const ConversationMessage.toolResult(
              callId: 'call_prev1',
              result: '15 degrees celsius',
            ),
          ],
        );

        final messages = sentBody!['messages'] as List;
        expect(messages, hasLength(4)); // 3 history + 1 current

        // User message
        expect(messages[0]['role'], equals('user'));
        expect(messages[0]['content'], equals('Weather in Paris?'));

        // Assistant with tool calls — OpenAI format uses tool_calls array
        expect(messages[1]['role'], equals('assistant'));
        final toolCalls = messages[1]['tool_calls'] as List;
        expect(toolCalls[0]['id'], equals('call_prev1'));
        expect(toolCalls[0]['type'], equals('function'));
        final fn = toolCalls[0]['function'] as Map<String, dynamic>;
        expect(fn['name'], equals('get_weather'));
        // OpenAI sends arguments as JSON string
        expect(jsonDecode(fn['arguments'] as String), equals({'location': 'Paris'}));

        // Tool result — OpenAI format: role=tool, tool_call_id
        expect(messages[2]['role'], equals('tool'));
        expect(messages[2]['tool_call_id'], equals('call_prev1'));
        expect(messages[2]['content'], equals('15 degrees celsius'));

        // Current user message
        expect(messages[3]['role'], equals('user'));
        expect(messages[3]['content'], equals('And tomorrow?'));
      });

      test('returns failure on 429', () async {
        final client = _mockClient((_) async {
          return http.Response('rate limited', 429);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'test'),
          tools: [
            const ToolSpec(
              name: 'tool1',
              description: 'A tool',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isFailure, isTrue);
      });

      test('returns failure on malformed JSON response', () async {
        final client = _mockClient((_) async {
          return http.Response('not json', 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.completeWithTools(
          const AIRequest(prompt: 'test'),
          tools: [
            const ToolSpec(
              name: 'tool1',
              description: 'A tool',
              parameters: {'type': 'object', 'properties': {}},
            ),
          ],
        );

        expect(result.isFailure, isTrue);
      });
    });

    group('zero PII', () {
      test('request body contains no user context data', () async {
        Map<String, dynamic>? sentBody;
        final client = _mockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(_successBody('ok'), 200);
        });

        final provider =
            OpenAIProvider(apiKey: 'test-key', httpClient: client);
        await provider.complete(
          const AIRequest(
            prompt: 'Describe this',
            context: {'userId': 'user-456', 'email': 'test@test.com'},
          ),
        );

        final bodyStr = jsonEncode(sentBody);
        expect(bodyStr, isNot(contains('user-456')));
        expect(bodyStr, isNot(contains('test@test.com')));
      });
    });
  });
}
