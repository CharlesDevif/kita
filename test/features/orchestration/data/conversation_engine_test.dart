import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/ai_router.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/tool_models.dart' as ai;
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/orchestration/data/agent_bus_impl.dart';
import 'package:kita/features/orchestration/data/agent_supervisor.dart';
import 'package:kita/features/orchestration/data/conversation_engine.dart';
import 'package:kita/features/orchestration/data/stub_access.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/conversation_engine.dart'
    as iface;
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';

// ==========================================================================
// Mocks
// ==========================================================================

/// Configurable mock AIRouter for testing ConversationEngineImpl.
///
/// Supports queueing multiple responses for multi-turn tool-use loops.
class _MockAIRouter implements AIRouter {
  final List<Result<ai.AIToolResponse>> _toolResponses = [];
  int toolCallCount = 0;
  final List<AIRequest> receivedRequests = [];
  final List<List<ai.ConversationMessage>> receivedHistories = [];

  void enqueueToolResponse(Result<ai.AIToolResponse> response) {
    _toolResponses.add(response);
  }

  @override
  List<AIProvider> get availableProviders => [_FakeProvider()];

  @override
  Future<Result<ai.AIToolResponse>> routeWithTools(
    AIRequest request, {
    required List<ai.ToolSpec> tools,
    List<ai.ConversationMessage> history = const [],
  }) async {
    toolCallCount++;
    receivedRequests.add(request);
    receivedHistories.add(List.of(history));

    if (_toolResponses.isEmpty) {
      return const Result.failure(AIProviderFailure(
        userMessage: 'No response queued',
        logMessage: 'No response queued in mock',
        providerId: 'mock',
      ));
    }
    return _toolResponses.removeAt(0);
  }

  @override
  Future<Result<AIResponse>> route(AIRequest request) async {
    return const Result.success(AIResponse(
      content: 'fallback',
      meta: AIResponseMeta(
        providerId: 'mock',
        latency: Duration.zero,
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> routeStream(AIRequest request) async* {
    yield 'stream';
  }

  @override
  Stream<String> routeVisionStream(ImageData image, String prompt,
      {int? maxTokens}) async* {
    yield 'vision';
  }
}

class _FakeProvider implements AIProvider {
  @override
  String get id => 'mock';
  @override
  String get displayName => 'Mock';
  @override
  ProviderTier get tier => ProviderTier.cloudFast;
  @override
  bool get isAvailable => true;
  @override
  Future<Result<AIResponse>> complete(AIRequest request) async =>
      throw UnimplementedError();
  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt,
          {int? maxTokens}) async =>
      throw UnimplementedError();
  @override
  Stream<String> completeStream(AIRequest request) =>
      throw UnimplementedError();
  @override
  Stream<String> visionStream(ImageData image, String prompt,
          {int? maxTokens}) =>
      throw UnimplementedError();
  @override
  Future<Result<ai.AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ai.ToolSpec> tools,
    List<ai.ConversationMessage> history = const [],
  }) async =>
      throw UnimplementedError();
  @override
  Future<Result<void>> validateApiKey(String key) async =>
      const Result.success(null);
}

class _MockTTS implements TTSService {
  @override
  bool get isSpeaking => false;
  @override
  Stream<TtsSpeechEvent> get speechEvents => const Stream.empty();
  @override
  Future<Result<void>> speak(String text,
          {TTSPriority priority = TTSPriority.standard}) async =>
      const Result.success(null);
  @override
  Future<Result<void>> stop() async => const Result.success(null);
}

class _MockHaptic implements HapticService {
  @override
  Future<Result<void>> trigger(HapticPattern pattern) async =>
      const Result.success(null);
  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);
  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);
  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);
  @override
  Future<Result<void>> presence() => trigger(HapticPattern.presence);
}

// ==========================================================================
// Helpers
// ==========================================================================

const _textOnlyMeta = AIResponseMeta(
  providerId: 'mock',
  latency: Duration.zero,
  tier: ProviderTier.cloudFast,
);

ai.AIToolResponse _textResponse(String text) => ai.AIToolResponse(
      text: text,
      meta: _textOnlyMeta,
    );

ai.AIToolResponse _toolCallResponse({
  String? text,
  required List<ai.ToolCall> toolCalls,
}) =>
    ai.AIToolResponse(
      text: text,
      toolCalls: toolCalls,
      meta: _textOnlyMeta,
    );

// ==========================================================================
// Tests
// ==========================================================================

void main() {
  late _MockAIRouter mockRouter;
  late AgentSupervisor supervisor;
  late FakeClock clock;
  late AgentBusImpl bus;
  late ConversationEngineImpl engine;

  setUp(() {
    mockRouter = _MockAIRouter();
    clock = FakeClock();
    bus = AgentBusImpl();
    supervisor = AgentSupervisor(
      bus: bus,
      sandbox: PluginSandboxImpl(
        sensorAccess: StubSensorAccess(),
        aiAccess: StubAIAccess(),
      ),
      clock: clock,
      ttsService: _MockTTS(),
      hapticService: _MockHaptic(),
    );
    engine = ConversationEngineImpl(
      aiRouter: mockRouter,
      supervisor: supervisor,
      clock: clock,
    );
  });

  tearDown(() async {
    engine.dispose();
    await supervisor.dispose();
    bus.dispose();
  });

  group('ConversationEngineImpl', () {
    group('processInput with text response', () {
      test('returns text when LLM responds with text only', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Bonjour Marie!')),
        );

        final result = await engine.processInput('Bonjour');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.text, equals('Bonjour Marie!'));
        expect(response.toolCalls, isEmpty);
      });

      test('returns empty response for empty input', () async {
        final result = await engine.processInput('');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.text, isEmpty);
        expect(response.toolCalls, isEmpty);
        expect(mockRouter.toolCallCount, equals(0));
      });

      test('returns failure when LLM is unavailable', () async {
        mockRouter.enqueueToolResponse(
          const Result.failure(AIProviderFailure(
            userMessage: 'Erreur IA',
            logMessage: 'LLM timeout',
            providerId: 'mock',
          )),
        );

        final result = await engine.processInput('Bonjour');

        expect(result.isSuccess, isFalse);
      });
    });

    group('processInput with tool calls', () {
      test('executes describe tool and returns result', () async {
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'describe',
              arguments: {'detail_level': 'brief'},
            ),
          ],
        )));
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Je vois un parc avec une fontaine.')),
        );

        final result = await engine.processInput('Decris ce que tu vois');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.text, contains('Je vois un parc'));
        expect(response.toolCalls, contains('describe'));
      });

      test('executes alert tool with start action', () async {
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'alert',
              arguments: {'action': 'start'},
            ),
          ],
        )));
        mockRouter.enqueueToolResponse(Result.success(
          _textResponse('Surveillance activee.'),
        ));

        final result = await engine.processInput('Active la surveillance');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.toolCalls, contains('alert'));
      });

      test('handles unknown tool gracefully', () async {
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'navigate',
              arguments: {},
            ),
          ],
        )));
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Done')),
        );

        final result = await engine.processInput('Navigate somewhere');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.toolCalls, contains('navigate'));
      });
    });

    group('tool-use loop', () {
      test('handles text + tool call in single LLM response', () async {
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          text: 'Laisse-moi regarder.',
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'describe',
              arguments: {},
            ),
          ],
        )));
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Je vois un arbre.')),
        );

        final result = await engine.processInput('Que vois-tu?');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.text, contains('Laisse-moi regarder.'));
        expect(response.text, contains('Je vois un arbre.'));
        expect(response.toolCalls, ['describe']);
      });

      test('max iterations guard prevents infinite loop', () async {
        // Queue 6 tool-call responses (max is 5 iterations)
        for (var i = 0; i < 6; i++) {
          mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
            toolCalls: [
              ai.ToolCall(
                id: 'call_$i',
                name: 'describe',
                arguments: const {},
              ),
            ],
          )));
        }

        final result = await engine.processInput('Loop forever');

        expect(result.isSuccess, isTrue);
        // 1 initial call + 5 loop iterations = 6 max
        expect(mockRouter.toolCallCount, lessThanOrEqualTo(6));
      });

      test('LLM failure during tool loop returns partial result', () async {
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          text: 'Je vais verifier.',
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'describe',
              arguments: {},
            ),
          ],
        )));
        // Second call fails
        mockRouter.enqueueToolResponse(
          const Result.failure(AIProviderFailure(
            userMessage: 'Erreur',
            logMessage: 'timeout',
            providerId: 'mock',
          )),
        );

        final result = await engine.processInput('Regarde');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        expect(response.text, contains('Je vais verifier.'));
        expect(response.toolCalls, ['describe']);
      });

      test('returns default text when LLM fails mid-loop with no prior text',
          () async {
        // First call: tool call with NO text
        mockRouter.enqueueToolResponse(Result.success(_toolCallResponse(
          toolCalls: [
            const ai.ToolCall(
              id: 'call_1',
              name: 'describe',
              arguments: {},
            ),
          ],
        )));
        // Second call fails
        mockRouter.enqueueToolResponse(
          const Result.failure(AIProviderFailure(
            userMessage: 'Erreur',
            logMessage: 'timeout',
            providerId: 'mock',
          )),
        );

        final result = await engine.processInput('Regarde');

        expect(result.isSuccess, isTrue);
        final response = (result as Success<iface.ConversationResponse>).value;
        // Should return default fallback text
        expect(response.text, contains('effectu'));
      });
    });

    group('concurrent input guard', () {
      test('rejects concurrent processInput calls', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('First response')),
        );

        final first = engine.processInput('First');
        final second = engine.processInput('Second');

        final firstResult = await first;
        final secondResult = await second;

        expect(firstResult.isSuccess, isTrue);
        expect(secondResult.isSuccess, isFalse);
      });
    });

    group('history management', () {
      test('maintains conversation history across calls', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Salut!')),
        );
        await engine.processInput('Bonjour');

        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Je suis Kita.')),
        );
        await engine.processInput('Qui es-tu?');

        expect(mockRouter.receivedHistories.length, equals(2));
        expect(mockRouter.receivedHistories[0], isEmpty);
        // Second call should have user + assistant from first turn
        expect(mockRouter.receivedHistories[1], hasLength(2));
      });

      test('trims history at max length (20)', () async {
        // Send 12 turns (24 messages: 12 user + 12 assistant)
        for (var i = 0; i < 12; i++) {
          mockRouter.enqueueToolResponse(
            Result.success(_textResponse('Response $i')),
          );
          await engine.processInput('Message $i');
        }

        expect(engine.history.length, lessThanOrEqualTo(20));
      });

      test('resetHistory clears conversation context', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Hello')),
        );
        await engine.processInput('Hi');
        expect(engine.history, isNotEmpty);

        engine.resetHistory();
        expect(engine.history, isEmpty);
      });
    });

    group('dispose', () {
      test('prevents further processing after dispose', () async {
        engine.dispose();

        final result = await engine.processInput('Hello');

        expect(result.isSuccess, isFalse);
        expect(mockRouter.toolCallCount, equals(0));
      });

      test('clears history on dispose', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Hello')),
        );
        await engine.processInput('Hi');
        expect(engine.history, isNotEmpty);

        engine.dispose();
        expect(engine.history, isEmpty);
      });
    });

    group('isReady', () {
      test('returns true when providers are available', () {
        expect(engine.isReady, isTrue);
      });

      test('returns false after dispose', () {
        engine.dispose();
        expect(engine.isReady, isFalse);
      });
    });

    group('processInputStream', () {
      test('yields text from processInput on success', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('Streamed response')),
        );

        final chunks = await engine.processInputStream('Test').toList();

        expect(chunks, equals(['Streamed response']));
      });

      test('yields nothing on failure', () async {
        mockRouter.enqueueToolResponse(
          const Result.failure(AIProviderFailure(
            userMessage: 'Erreur',
            logMessage: 'timeout',
            providerId: 'mock',
          )),
        );

        final chunks = await engine.processInputStream('Test').toList();

        expect(chunks, isEmpty);
      });

      test('yields nothing for empty response text', () async {
        mockRouter.enqueueToolResponse(
          Result.success(_textResponse('')),
        );

        final chunks = await engine.processInputStream('Test').toList();

        expect(chunks, isEmpty);
      });
    });
  });
}
