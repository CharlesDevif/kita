import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/claude_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

http_testing.MockClient _mockClient(
  Future<http.Response> Function(http.Request) handler,
) {
  return http_testing.MockClient(handler);
}

String _successBody(String text) => jsonEncode({
      'content': [
        {'type': 'text', 'text': text},
      ],
    });

void main() {
  group('ClaudeProvider', () {
    group('properties', () {
      test('has correct id, displayName, tier', () {
        final provider = ClaudeProvider(apiKey: 'test-key');
        expect(provider.id, equals('claude'));
        expect(provider.displayName, equals('Claude (Anthropic)'));
        expect(provider.tier, equals(ProviderTier.cloudPowerful));
      });

      test('isAvailable is true when API key is present', () {
        final provider = ClaudeProvider(apiKey: 'test-key');
        expect(provider.isAvailable, isTrue);
      });

      test('isAvailable is false when API key is empty', () {
        final provider = ClaudeProvider(apiKey: '');
        expect(provider.isAvailable, isFalse);
      });
    });

    group('complete()', () {
      test('returns success on 200 response', () async {
        final client = _mockClient((request) async {
          expect(request.url.toString(),
              contains('api.anthropic.com/v1/messages'));
          expect(request.headers['x-api-key'], equals('test-key'));
          expect(request.headers['anthropic-version'], equals('2023-06-01'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], isNotEmpty);
          expect(body['messages'], isList);

          return http.Response(_successBody('Hello from Claude'), 200);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'Hello', priority: RequestPriority.standard),
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.content, equals('Hello from Claude'));
        expect(response.meta.providerId, equals('claude'));
        expect(response.meta.tier, equals(ProviderTier.cloudPowerful));
        expect(response.status, equals(AIResponseStatus.success));
      });

      test('sends maxTokens from request', () async {
        final client = _mockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['max_tokens'], equals(2048));
          return http.Response(_successBody('ok'), 200);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        await provider.complete(
          const AIRequest(prompt: 'test', maxTokens: 2048),
        );
      });

      test('returns failure on 401 (invalid key)', () async {
        final client = _mockClient((_) async {
          return http.Response('{"error": "unauthorized"}', 401);
        });

        final provider =
            ClaudeProvider(apiKey: 'bad-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<AIProviderFailure>());
      });

      test('returns failure on 429 (rate limited)', () async {
        final client = _mockClient((_) async {
          return http.Response('{"error": "rate_limited"}', 429);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<AIProviderFailure>());
      });

      test('returns failure on 500 (server error)', () async {
        final client = _mockClient((_) async {
          return http.Response('Internal Server Error', 500);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
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
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
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
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.complete(
          const AIRequest(prompt: 'test'),
        );

        expect(result.isFailure, isTrue);
      });
    });

    group('vision()', () {
      test('sends image as base64 with correct structure', () async {
        final client = _mockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = body['messages'] as List;
          final content = (messages[0] as Map)['content'] as List;

          // First block should be image
          expect(content[0]['type'], equals('image'));
          expect(content[0]['source']['type'], equals('base64'));
          expect(content[0]['source']['media_type'], equals('image/jpeg'));
          expect(content[0]['source']['data'], isNotEmpty);

          // Second block should be text prompt
          expect(content[1]['type'], equals('text'));
          expect(content[1]['text'], equals('describe this'));

          return http.Response(
            _successBody('A scenic mountain view'),
            200,
          );
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.vision(
          ImageData(bytes: Uint8List.fromList([1, 2, 3, 4])),
          'describe this',
        );

        expect(result.isSuccess, isTrue);
        final response = (result as Success<AIResponse>).value;
        expect(response.content, equals('A scenic mountain view'));
      });
    });

    group('validateApiKey()', () {
      test('returns success on valid key (non-401)', () async {
        final client = _mockClient((_) async {
          return http.Response(_successBody('ok'), 200);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('valid-key');

        expect(result.isSuccess, isTrue);
      });

      test('returns failure on 401', () async {
        final client = _mockClient((_) async {
          return http.Response('unauthorized', 401);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('bad-key');

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<AIProviderFailure>());
      });

      test('returns NetworkFailure on connection error', () async {
        final client = _mockClient((_) async {
          throw Exception('No connection');
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        final result = await provider.validateApiKey('key');

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<NetworkFailure>());
      });
    });

    group('zero PII', () {
      test('request body contains no user data beyond the prompt', () async {
        Map<String, dynamic>? sentBody;
        final client = _mockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(_successBody('ok'), 200);
        });

        final provider =
            ClaudeProvider(apiKey: 'test-key', httpClient: client);
        await provider.complete(
          const AIRequest(
            prompt: 'Describe this scene',
            context: {'userId': 'user-123', 'name': 'Marie'},
          ),
        );

        // The context map should NOT be sent to the API
        final bodyStr = jsonEncode(sentBody);
        expect(bodyStr, isNot(contains('user-123')));
        expect(bodyStr, isNot(contains('Marie')));
      });
    });
  });
}
