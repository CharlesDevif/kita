import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
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
  final List<({HapticPattern pattern, OutputPriority priority})> hapticCalls = [];
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
      {OutputPriority priority = OutputPriority.standard}) async {
    hapticCalls.add((pattern: pattern, priority: priority));
  }

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

// === Mock AgentBus ===

class MockAgentBus implements AgentBus {
  final List<AgentMessage> publishedMessages = [];

  @override
  void publish(AgentMessage message) {
    publishedMessages.add(message);
  }

  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}

  @override
  void unsubscribe(String agentId) {}

  @override
  Stream<AgentMessage> streamFor(String agentId) =>
      const Stream.empty();
}

AgentInput _agentInput({
  String command = 'decris',
  Map<String, dynamic> params = const {},
}) {
  return AgentInput(
    command: command,
    params: params,
    source: InputSource.voice,
    timestamp: DateTime(2026, 1, 1),
  );
}

void main() {
  late KitaDescribePlugin agent;
  late MockSensorAccess mockSensors;
  late MockAIAccess mockAI;
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;
  late List<LogEntry> logEntries;

  setUp(() {
    agent = KitaDescribePlugin();
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

  Future<void> spawnAgent() async {
    final context = AgentContext(
      sensors: mockSensors,
      ai: mockAI,
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
    );
    await agent.onSpawn(context);
  }

  group('manifest', () {
    test('has correct id', () {
      expect(agent.manifest.id, 'com.kita.describe');
    });

    test('is onDemand type', () {
      expect(agent.manifest.agentType, AgentType.onDemand);
    });

    test('has standard priority', () {
      expect(agent.manifest.priority, AgentPriority.standard);
    });

    test('subscribes to cancelAll and interruptRequest', () {
      expect(agent.manifest.subscriptions,
          contains(AgentMessageType.cancelAll));
      expect(agent.manifest.subscriptions,
          contains(AgentMessageType.interruptRequest));
    });
  });

  group('onSpawn', () {
    test('onSpawn receives valid AgentContext', () async {
      await spawnAgent();

      // Agent is alive — no exception thrown
      expect(agent.state, DescribeState.idle);
    });

    test('onSpawn resets terminated flag', () async {
      await spawnAgent();
      await agent.onTerminate();

      // Re-spawn
      await spawnAgent();
      // Should be functional again
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      final result = await agent.handleInput(_agentInput());
      expect(result.isSuccess, isTrue);
    });
  });

  group('handleInput', () {
    setUp(() async {
      await spawnAgent();
    });

    test('describe pipeline: capture -> AI -> speak via context', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await agent.handleInput(_agentInput(command: 'decris'));

      expect(result.isSuccess, isTrue);

      // Speak was called via OutputHandle
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('salon'));
      expect(
          mockOutput.speakCalls.first.priority, OutputPriority.standard);
    });

    test('camera failure returns Result.failure', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result = await agent.handleInput(_agentInput(command: 'decris'));

      expect(result.isFailure, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
    });

    test('AI failure returns Result.failure', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const AIProviderFailure(
        userMessage: 'Service IA indisponible.',
        logMessage: 'AI vision timeout',
      );

      final result = await agent.handleInput(_agentInput(command: 'decris'));

      expect(result.isFailure, isTrue);
    });

    test('unknown command returns failure', () async {
      final result =
          await agent.handleInput(_agentInput(command: 'unknown'));

      expect(result.isFailure, isTrue);
    });

    test('merci calls output.complete()', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));

      final result = await agent.handleInput(_agentInput(command: 'merci'));

      expect(result.isSuccess, isTrue);
      expect(mockOutput.completeCalled, 1);
    });
  });

  group('silence timer', () {
    setUp(() async {
      await spawnAgent();
    });

    test('speechEvents.completed starts silence timer that calls complete',
        () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));

      // Simulate speech completed
      mockOutput.speechEventsController.add(SpeechEvent.completed);

      // Wait for microtask to process the stream event
      await Future<void>.delayed(Duration.zero);

      // Timer should be pending but not fired yet
      expect(mockOutput.completeCalled, 0);

      // Advance clock past silence timeout
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);

      // complete() should have been called
      expect(mockOutput.completeCalled, 1);
    });

    test('speechEvents.interrupted cancels silence timer', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));

      // Simulate speech completed (starts timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Simulate interruption (cancels timer)
      mockOutput.speechEventsController.add(SpeechEvent.interrupted);
      await Future<void>.delayed(Duration.zero);

      // Advance past timeout
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);

      // complete() should NOT have been called
      expect(mockOutput.completeCalled, 0);
    });

    test('interruptRequest bus message cancels silence timer', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));

      // Simulate speech completed (starts timer)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Deliver interrupt request via bus
      agent.onBusMessage(AgentMessage(
        fromAgent: 'system',
        type: AgentMessageType.interruptRequest,
        payload: const {},
        timestamp: DateTime(2026, 1, 1),
      ));

      // Advance past timeout
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);

      // complete() should NOT have been called
      expect(mockOutput.completeCalled, 0);
    });
  });

  group('onTerminate', () {
    setUp(() async {
      await spawnAgent();
    });

    test('cleans up timers and subscriptions', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));

      // Start silence timer
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Terminate
      await agent.onTerminate();

      // Advance past timeout — should not crash or call complete
      fakeClock.advance(KitaDescribePlugin.silenceTimeout);
      expect(mockOutput.completeCalled, 0);
    });

    test('resets state to idle', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();
      await agent.handleInput(_agentInput(command: 'decris'));
      expect(agent.state.phase, isNot(DescribePhase.idle));

      await agent.onTerminate();

      expect(agent.state.phase, DescribePhase.idle);
    });
  });
}
