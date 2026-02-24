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
