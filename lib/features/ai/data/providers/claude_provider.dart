import 'dart:async';
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
import '../../domain/tool_models.dart';

/// Anthropic Claude API provider.
///
/// Implements [AIProvider] with tier [ProviderTier.cloudPowerful].
/// Uses the Messages API (`/v1/messages`).
class ClaudeProvider implements AIProvider {
  ClaudeProvider({
    required String apiKey,
    http.Client? httpClient,
    this.model = 'claude-sonnet-4-20250514',
    this.timeout = AppConfig.aiCloudTimeout,
  })  : _apiKey = apiKey,
        _client = httpClient ?? http.Client();

  static final _log = KitaLogger('AI');
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  final String _apiKey;
  final http.Client _client;
  final String model;
  final Duration timeout;

  @override
  String get id => 'claude';

  @override
  String get displayName => 'Claude (Anthropic)';

  @override
  ProviderTier get tier => ProviderTier.cloudPowerful;

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
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    final stopwatch = Stopwatch()..start();

    final base64Image = base64Encode(image.bytes);
    final mediaType = image.mimeType;

    final body = {
      'model': model,
      'max_tokens': maxTokens ?? 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
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
  Stream<String> completeStream(AIRequest request) {
    return batchCompleteAsStream(() => complete(request));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt, {int? maxTokens}) {
    return batchVisionAsStream(() => vision(image, prompt, maxTokens: maxTokens));
  }

  @override
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    final stopwatch = Stopwatch()..start();

    final messages = <Map<String, dynamic>>[
      ...history.map(_conversationMessageToJson),
      {
        'role': 'user',
        'content': request.prompt,
      },
    ];

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': request.maxTokens ?? 1024,
      'messages': messages,
      'tools': tools.map(_toolSpecToJson).toList(),
    };

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
        return _parseToolResponse(response.body, stopwatch.elapsed);
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
        userMessage: 'Le service Claude est temporairement indisponible.',
        logMessage: 'Claude API error: ${response.statusCode}',
        providerId: id,
      ));
    } on Exception catch (e, stack) {
      stopwatch.stop();

      if (e is TimeoutException) {
        _log.warning('Tool request timed out');
        return Result.failure(NetworkFailure.timeout(endpoint: _baseUrl));
      }

      _log.warning('Network error', error: e, stackTrace: stack);
      return Result.failure(NetworkFailure(
        userMessage: 'Erreur de connexion au service Claude.',
        logMessage: 'Claude network error: $e',
        cause: e,
        stackTrace: stack,
      ));
    }
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

      // Any non-auth error means the key is at least valid
      return const Result.success(null);
    } on Exception catch (e, stack) {
      _log.warning('API key validation failed', error: e, stackTrace: stack);
      return Result.failure(NetworkFailure(
        userMessage: 'Impossible de vérifier la clé API.',
        logMessage: 'Claude API key validation error: $e',
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
        userMessage: 'Le service Claude est temporairement indisponible.',
        logMessage: 'Claude API error: ${response.statusCode}',
        providerId: id,
      ));
    } on Exception catch (e, stack) {
      stopwatch.stop();

      if (e is TimeoutException) {
        _log.warning('Request timed out');
        return Result.failure(NetworkFailure.timeout(endpoint: _baseUrl));
      }

      _log.warning('Network error', error: e, stackTrace: stack);
      return Result.failure(NetworkFailure(
        userMessage: 'Erreur de connexion au service Claude.',
        logMessage: 'Claude network error: $e',
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  Result<AIResponse> _parseResponse(String body, Duration latency) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>;

      // Extract text from the first text block
      final textBlock = content.firstWhere(
        (block) => (block as Map<String, dynamic>)['type'] == 'text',
        orElse: () => <String, dynamic>{},
      ) as Map<String, dynamic>;

      final text = textBlock['text'] as String? ?? '';

      if (text.isEmpty) {
        _log.warning('Response parsed but text content is empty');
      }

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
        userMessage: 'Réponse du service Claude invalide.',
        logMessage: 'Claude response parse error: $e',
        providerId: id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Tool use helpers
  // ---------------------------------------------------------------------------

  Result<AIToolResponse> _parseToolResponse(String body, Duration latency) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>;

      String? text;
      final toolCalls = <ToolCall>[];

      for (final block in content) {
        final blockMap = block as Map<String, dynamic>;
        final type = blockMap['type'] as String;

        if (type == 'text') {
          text = blockMap['text'] as String?;
        } else if (type == 'tool_use') {
          toolCalls.add(ToolCall(
            id: blockMap['id'] as String,
            name: blockMap['name'] as String,
            arguments: blockMap['input'] as Map<String, dynamic>? ?? {},
          ));
        }
      }

      return Result.success(AIToolResponse(
        text: text,
        toolCalls: toolCalls,
        meta: AIResponseMeta(
          providerId: id,
          latency: latency,
          tier: tier,
        ),
      ));
    } catch (e, stack) {
      _log.error('Failed to parse tool response', error: e, stackTrace: stack);
      return Result.failure(AIProviderFailure(
        userMessage: 'Réponse du service Claude invalide.',
        logMessage: 'Claude tool response parse error: $e',
        providerId: id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  Map<String, dynamic> _toolSpecToJson(ToolSpec tool) => {
        'name': tool.name,
        'description': tool.description,
        'input_schema': tool.parameters,
      };

  Map<String, dynamic> _conversationMessageToJson(ConversationMessage msg) {
    switch (msg.role) {
      case ConversationRole.user:
        return {'role': 'user', 'content': msg.content ?? ''};
      case ConversationRole.assistant:
        if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
          return {
            'role': 'assistant',
            'content': [
              if (msg.content != null) {'type': 'text', 'text': msg.content},
              ...msg.toolCalls!.map((tc) => {
                    'type': 'tool_use',
                    'id': tc.id,
                    'name': tc.name,
                    'input': tc.arguments,
                  }),
            ],
          };
        }
        return {'role': 'assistant', 'content': msg.content ?? ''};
      case ConversationRole.tool:
        return {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': msg.toolCallId,
              'content': msg.content ?? '',
            },
          ],
        };
    }
  }

  Map<String, String> _headers(String key) => {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': _apiVersion,
      };
}
