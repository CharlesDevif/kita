import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';

import 'describe_test_helpers.dart';

// === Mock OutputHandle ===

class MockOutputHandle implements OutputHandle {
  MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];
  int completeCalled = 0;

  final StreamController<SpeechEvent> speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => speechEventsController.stream;

  @override
  Future<void> speak(String text,
      {OutputPriority priority = OutputPriority.standard}) async {
    speakCalls.add((text: text, priority: priority));
  }

  @override
  Future<void> haptic(HapticPattern pattern,
      {OutputPriority priority = OutputPriority.standard}) async {}

  @override
  void updateViewport(Widget widget) {}

  @override
  void complete() {
    completeCalled++;
  }

  void dispose() {
    speechEventsController.close();
  }
}

class MockAgentBus implements AgentBus {
  @override
  void publish(AgentMessage message) {}
  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}
  @override
  void unsubscribe(String agentId) {}
  @override
  Stream<AgentMessage> streamFor(String agentId) => const Stream.empty();
}

AgentInput _agentInput({String command = 'decris'}) {
  return AgentInput(
    command: command,
    params: const {},
    source: InputSource.voice,
    timestamp: DateTime(2026, 1, 1),
  );
}

// --- Tests ---

void main() {
  late KitaDescribePlugin plugin;
  late MockSensorAccess mockSensors;
  late MockAIAccess mockAI;
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;
  late List<LogEntry> logEntries;

  setUp(() {
    plugin = KitaDescribePlugin();
    mockSensors = MockSensorAccess();
    mockAI = MockAIAccess();
    mockOutput = MockOutputHandle(agentId: 'com.kita.describe');
    mockBus = MockAgentBus();
    fakeClock = FakeClock();
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockOutput.dispose();
  });

  Future<void> spawnPlugin() async {
    final context = AgentContext(
      sensors: mockSensors,
      ai: mockAI,
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
    );
    await plugin.onSpawn(context);
  }

  /// Helper to do initial describe and set up state.
  Future<void> doInitialDescribe({String content = 'Un salon lumineux.'}) async {
    mockSensors.photoToReturn = testImage();
    mockAI.responseToReturn = testAIResponse(content: content);
    await plugin.handleInput(_agentInput());
  }

  group('initial describe', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('sets state to describing with image and description', () async {
      await doInitialDescribe();

      expect(plugin.state.phase, DescribePhase.describing);
      expect(plugin.state.imageData, isNotNull);
      expect(plugin.state.description, 'Un salon lumineux.');
    });

    test('returns text response with description', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.type, AgentOutputType.text);
      expect(output.content, contains('salon'));
    });
  });

  group('plus de details', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('sends enriched prompt to AI', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee du salon.');
      await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(mockAI.lastPromptReceived, KitaDescribePlugin.detailedPrompt);
    });

    test('transitions state to detailed', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee.');
      await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(plugin.state.phase, DescribePhase.detailed);
      expect(plugin.state.detailedDescription, 'Description detaillee.');
      expect(plugin.state.description, 'Un salon lumineux.');
    });

    test('returns detailed description', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee du salon.');
      final result = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.content, contains('detaillee'));
      expect(output.metadata!['detailed'], true);
    });

    test('fails gracefully without prior describe', () async {
      final result = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure.userMessage, contains('decris'));
    });

    test('also works with "details" alias', () async {
      await doInitialDescribe();

      mockAI.responseToReturn = testAIResponse(content: 'Details.');
      final result = await plugin.handleInput(
        _agentInput(command: 'details'),
      );

      expect(result.isSuccess, isTrue);
    });

    test('also works with "detaille" alias', () async {
      await doInitialDescribe();

      mockAI.responseToReturn = testAIResponse(content: 'Details.');
      final result = await plugin.handleInput(
        _agentInput(command: 'detaille'),
      );

      expect(result.isSuccess, isTrue);
    });
  });

  group('repete', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns last description without calling AI', () async {
      await doInitialDescribe();

      // Reset AI mock to verify it is NOT called
      mockAI.lastPromptReceived = null;

      final result = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.content, 'Un salon lumineux.');
      expect(output.metadata!['repeated'], true);
      expect(mockAI.lastPromptReceived, isNull);
    });

    test('returns detailed description if available', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee.');
      await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      mockAI.lastPromptReceived = null;

      final result = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );

      final output = (result as Success<AgentOutput>).value;
      expect(output.content, 'Description detaillee.');
    });

    test('fails gracefully without prior describe', () async {
      final result = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure.userMessage, contains('rien'));
    });
  });

  group('merci', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns to idle state and calls complete()', () async {
      await doInitialDescribe();

      final result = await plugin.handleInput(
        _agentInput(command: 'merci'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
      final output = (result as Success<AgentOutput>).value;
      expect(output.metadata!['action'], 'return_passive');

      // complete() was called on OutputHandle
      expect(mockOutput.completeCalled, 1);
    });
  });

  group('unknown command', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns failure for unrecognized command', () async {
      final result = await plugin.handleInput(
        _agentInput(command: 'zoomer'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.userMessage, 'Commande non reconnue.');
      expect((failure as PluginFailure).pluginId, 'com.kita.describe');
    });

    test('does not trigger camera capture for unknown command', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(
        _agentInput(command: 'unknown'),
      );

      expect(result.isFailure, isTrue);
      // AI should NOT have been called
      expect(mockAI.lastPromptReceived, isNull);
    });
  });

  group('silence timeout', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('resets state to idle and calls complete() after speech completes + 5s',
        () async {
      await doInitialDescribe();
      expect(plugin.state.phase, DescribePhase.describing);
      expect(mockOutput.completeCalled, 0);

      // Simulate speech completed event (starts silence timer via Clock.delayed)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Advance 4s — should still be describing
      fakeClock.advance(const Duration(seconds: 4));
      expect(plugin.state.phase, DescribePhase.describing);
      expect(mockOutput.completeCalled, 0);

      // Advance 1 more second (total 5s) — should be idle
      fakeClock.advance(const Duration(seconds: 1));
      expect(plugin.state.phase, DescribePhase.idle);
      expect(mockOutput.completeCalled, 1);
    });

    test('timer resets on new command before expiry', () async {
      await doInitialDescribe();

      // Simulate speech completed (starts silence timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Advance 3s
      fakeClock.advance(const Duration(seconds: 3));
      expect(plugin.state.phase, DescribePhase.describing);

      // Send "repete" which resets the timer (handleInput cancels current timer)
      await plugin.handleInput(_agentInput(command: 'repete'));

      // Simulate speech completed again (restarts silence timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Advance 4s after repete — should still NOT be idle (timer was reset)
      fakeClock.advance(const Duration(seconds: 4));
      expect(plugin.state.phase, DescribePhase.describing);
      expect(mockOutput.completeCalled, 0);

      // Advance 1 more second (5s since repete speech completed) — should now be idle
      fakeClock.advance(const Duration(seconds: 1));
      expect(plugin.state.phase, DescribePhase.idle);
      expect(mockOutput.completeCalled, 1);
    });

    test('onTerminate cancels silence timer (no complete() fire)', () async {
      await doInitialDescribe();
      expect(plugin.state.phase, DescribePhase.describing);

      // Simulate speech completed (starts timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      await plugin.onTerminate();
      expect(plugin.state.phase, DescribePhase.idle);

      // Advance past timeout — complete() should NOT have been called
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);
      expect(mockOutput.completeCalled, 0);
    });
  });

  group('complete() callback', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('merci calls output.complete()', () async {
      await doInitialDescribe();

      await plugin.handleInput(_agentInput(command: 'merci'));

      expect(mockOutput.completeCalled, 1);
    });

    test('silence timeout calls output.complete()', () async {
      await doInitialDescribe();

      // Simulate speech completed (starts silence timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Advance past timeout
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);

      expect(mockOutput.completeCalled, 1);
    });

    test('onTerminate does not invoke complete() (it is for timer only)',
        () async {
      await doInitialDescribe();

      await plugin.onTerminate();

      // onTerminate cancels the timer, so complete() should NOT fire
      expect(mockOutput.completeCalled, 0);
    });
  });

  group('fallback offline', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('flags offline when AI response is degraded', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR brut.',
        status: AIResponseStatus.degraded,
      );

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      expect(plugin.state.isOffline, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.content, contains('Mode local'));
      expect(output.metadata!['offline'], true);
    });

    test('detailed request with degraded response flags offline', () async {
      // First: normal describe
      await doInitialDescribe(content: 'Normal.');

      // Then: detailed, but degraded
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR detaille.',
        status: AIResponseStatus.degraded,
      );

      final result = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.content, contains('Mode local'));
    });
  });

  group('full conversation cycle', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('decris -> plus de details -> repete -> merci', () async {
      // Step 1: decris
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un salon.');
      var result = await plugin.handleInput(_agentInput());
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.describing);

      // Step 2: plus de details
      mockAI.responseToReturn = testAIResponse(content: 'Salon detaille.');
      result = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.detailed);

      // Step 3: repete
      result = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );
      expect(result.isSuccess, isTrue);
      expect(
          (result as Success<AgentOutput>).value.content, 'Salon detaille.');

      // Step 4: merci
      result = await plugin.handleInput(
        _agentInput(command: 'merci'),
      );
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
      expect(mockOutput.completeCalled, 1);
    });
  });

  group('buildViewport', () {
    setUp(() async {
      await spawnPlugin();
    });

    testWidgets('returns null when idle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(plugin.buildViewport(context), isNull);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('returns DescribeViewport when describing', (tester) async {
      await doInitialDescribe();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final viewport = plugin.buildViewport(context);
                expect(viewport, isNotNull);
                return SingleChildScrollView(
                  child: viewport ?? const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(); // Let error builders render

      // Terminate to cancel the silence timer and avoid pending timer assertion.
      // Use tester.runAsync because onTerminate awaits stream subscription cancel.
      await tester.runAsync(() => plugin.onTerminate());
    });
  });

  group('onTerminate', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('cancels silence timer and resets state', () async {
      await doInitialDescribe();
      expect(plugin.state.phase, DescribePhase.describing);

      await plugin.onTerminate();

      expect(plugin.state.phase, DescribePhase.idle);
    });
  });

  group('voice commands', () {
    test('declares plus de details voice command', () {
      final moreDetailsCmd = plugin.voiceCommands.firstWhere(
        (c) => c.trigger == 'plus de details',
        orElse: () => throw StateError('Missing plus de details command'),
      );
      expect(moreDetailsCmd.aliases, contains('detaille'));
      expect(moreDetailsCmd.aliases, contains('details'));
    });
  });

  group('AgentOutput integration', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('describe response contains fields for Shell/ProfileAdapter',
        () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un salon lumineux.');

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;

      // The Shell uses these fields to route through ProfileAdapter:
      // - type: determines output modality
      // - content: text for TTS (vocal) and viewport (visual)
      // - metadata: provider info for logging/analytics
      expect(output.type, AgentOutputType.text);
      expect(output.content, isNotEmpty);
      expect(output.metadata, isNotNull);
      expect(output.metadata!['provider'], isA<String>());
      expect(output.metadata!['latency_ms'], isA<int>());
      expect(output.metadata!['tier'], isA<String>());
    });

    test('merci response contains return_passive action for Shell', () async {
      await doInitialDescribe();

      final result = await plugin.handleInput(
        _agentInput(command: 'merci'),
      );

      final output = (result as Success<AgentOutput>).value;

      // The Shell checks metadata['action'] == 'return_passive' to know
      // it should transition back to passive mode via ProfileAdapter.
      expect(output.metadata, isNotNull);
      expect(output.metadata!['action'], 'return_passive');
      expect(output.content, isEmpty);
    });

    test('offline response contains offline flag for Shell', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR.',
        status: AIResponseStatus.degraded,
      );

      final result = await plugin.handleInput(_agentInput());

      final output = (result as Success<AgentOutput>).value;

      // The Shell uses 'offline' metadata to adjust ProfileAdapter output
      // (e.g., announce "Mode local" prefix via TTS).
      expect(output.metadata!['offline'], true);
      expect(output.content, contains('Mode local'));
    });
  });
}
