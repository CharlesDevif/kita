import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/kita_failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/ai_provider.dart';
import '../../domain/ai_request.dart';
import '../../domain/ai_response.dart';
import '../../domain/image_data.dart';
import '../../domain/provider_tier.dart';

/// OpenAI Chat Completions API provider.
///
/// Implements [AIProvider] with tier [ProviderTier.cloudFast].
class OpenAIProvider implements AIProvider {
  OpenAIProvider({
    required String apiKey,
    http.Client? httpClient,
    this.model = 'gpt-4o-mini',
    this.timeout = AppConfig.aiCloudTimeout,
  })  : _apiKey = apiKey,
        _client = httpClient ?? http.Client();

  static final _log = KitaLogger('AI');
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';

  final String _apiKey;
  final http.Client _client;
  final String model;
  final Duration timeout;

  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  ProviderTier get tier => ProviderTier.cloudFast;

  @override
  bool get isAvailable => _apiKey.isNotEmpty;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    final stopwatch = Stopwatch()..start();

    final body = {
      'model': model,
      'max_tokens': request.maxTokens ?? 1024,
      'messages': [
        {
          'role': 'user',
          'content': request.prompt,
        },
      ],
    };

    return _sendRequest(body, stopwatch);
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    final stopwatch = Stopwatch()..start();

    final base64Image = base64Encode(image.bytes);
    final dataUrl = 'data:${image.mimeType};base64,$base64Image';

    final body = {
      'model': model,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
            {
              'type': 'text',
              'text': prompt,
            },
          ],
        },
      ],
    };

    return _sendRequest(body, stopwatch);
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: _headers(key),
            body: jsonEncode({
              'model': model,
              'max_tokens': 1,
              'messages': [
                {'role': 'user', 'content': 'test'},
              ],
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 401) {
        return Result.failure(AIProviderFailure.invalidApiKey(id));
      }

      return const Result.success(null);
    } on Exception catch (e, stack) {
      _log.warning('API key validation failed', error: e, stackTrace: stack);
      return Result.failure(NetworkFailure(
        userMessage: 'Impossible de verifier la cle API.',
        logMessage: 'OpenAI API key validation error: $e',
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  Future<Result<AIResponse>> _sendRequest(
    Map<String, dynamic> body,
    Stopwatch stopwatch,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: _headers(_apiKey),
            body: jsonEncode(body),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        return _parseResponse(response.body, stopwatch.elapsed);
      }

      if (response.statusCode == 401) {
        _log.warning('Invalid API key');
        return Result.failure(AIProviderFailure.invalidApiKey(id));
      }

      if (response.statusCode == 429) {
        _log.warning('Rate limited');
        return Result.failure(AIProviderFailure.rateLimited(id));
      }

      _log.warning('API error: ${response.statusCode}');
      return Result.failure(AIProviderFailure(
        userMessage: 'Le service OpenAI est temporairement indisponible.',
        logMessage: 'OpenAI API error: ${response.statusCode}',
        providerId: id,
      ));
    } on Exception catch (e, stack) {
      stopwatch.stop();

      if (e.toString().contains('TimeoutException')) {
        _log.warning('Request timed out');
        return Result.failure(NetworkFailure.timeout(endpoint: _baseUrl));
      }

      _log.warning('Network error', error: e, stackTrace: stack);
      return Result.failure(NetworkFailure(
        userMessage: 'Erreur de connexion au service OpenAI.',
        logMessage: 'OpenAI network error: $e',
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  Result<AIResponse> _parseResponse(String body, Duration latency) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      final message =
          (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      final text = message['content'] as String? ?? '';

      return Result.success(AIResponse(
        content: text,
        meta: AIResponseMeta(
          providerId: id,
          latency: latency,
          tier: tier,
        ),
        status: AIResponseStatus.success,
      ));
    } catch (e, stack) {
      _log.error('Failed to parse response', error: e, stackTrace: stack);
      return Result.failure(AIProviderFailure(
        userMessage: 'Reponse du service OpenAI invalide.',
        logMessage: 'OpenAI response parse error: $e',
        providerId: id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  Map<String, String> _headers(String key) => {
        'content-type': 'application/json',
        'authorization': 'Bearer $key',
      };
}
