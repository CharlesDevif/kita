import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/plugins/built_in/alert/kita_alert_plugin.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';

// === Mock OutputHandle ===

class MockOutputHandle implements OutputHandle {
  MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];
  final List<({HapticPattern pattern, OutputPriority priority})> hapticCalls =
      [];
  int completeCalled = 0;

  final StreamController<SpeechEvent> _speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => _speechEventsController.stream;

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
    _speechEventsController.close();
  }
}

// === Mock AgentBus ===

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

// === Stubs ===

class StubSensorAccess implements SensorAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class StubAIAccess implements AIAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// === Helpers ===

AgentInput _agentInput({
  String command = 'obstacle_detected',
  Map<String, dynamic> params = const {},
}) {
  return AgentInput(
    command: command,
    params: params,
    source: InputSource.sensor,
    timestamp: DateTime(2026, 1, 1),
  );
}

AgentInput _obstacleInput({
  String type = 'voiture',
  double distance = 2.0,
  double confidence = 0.95,
}) {
  return _agentInput(
    command: 'obstacle_detected',
    params: {
      'type': type,
      'distance': distance,
      'confidence': confidence,
    },
  );
}

void main() {
  late KitaAlertPlugin agent;
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;

  setUp(() {
    agent = KitaAlertPlugin();
    mockOutput = MockOutputHandle(agentId: 'com.kita.alert');
    mockBus = MockAgentBus();
    fakeClock = FakeClock();
    KitaLogger.testLogHandler = (_) {};
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockOutput.dispose();
  });

  Future<void> spawnAgent() async {
    final context = AgentContext(
      sensors: StubSensorAccess(),
      ai: StubAIAccess(),
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
    );
    await agent.onSpawn(context);
  }

  group('manifest', () {
    test('has correct id', () {
      expect(agent.manifest.id, 'com.kita.alert');
    });

    test('is persistent type', () {
      expect(agent.manifest.agentType, AgentType.persistent);
    });

    test('has critical priority', () {
      expect(agent.manifest.priority, AgentPriority.critical);
    });

    test('subscribes to cancelAll and userCommand', () {
      expect(
          agent.manifest.subscriptions, contains(AgentMessageType.cancelAll));
      expect(
          agent.manifest.subscriptions, contains(AgentMessageType.userCommand));
    });
  });

  group('onSpawn', () {
    test('onSpawn receives valid AgentContext', () async {
      await spawnAgent();

      // Agent is alive — can handle requests
      final result = await agent.handleInput(
        _agentInput(command: 'ok'),
      );
      expect(result.isSuccess, isTrue);
    });
  });

  group('obstacle detection', () {
    setUp(() async {
      await spawnAgent();
    });

    test('immediate alert (< 3m) speaks CRITICAL and triggers danger haptic',
        () async {
      final result = await agent.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.0, confidence: 0.95),
      );

      expect(result.isSuccess, isTrue);

      // TTS via OutputHandle with critical priority
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('Attention'));
      expect(mockOutput.speakCalls.first.text, contains('voiture'));
      expect(mockOutput.speakCalls.first.text, contains('2 metres'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.critical);

      // Haptic danger via OutputHandle
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.danger);
      expect(mockOutput.hapticCalls.first.priority, OutputPriority.critical);
    });

    test('preventive alert (3-10m) speaks HIGH and triggers warning haptic',
        () async {
      final result = await agent.handleInput(
        _obstacleInput(type: 'travaux', distance: 8.0, confidence: 0.88),
      );

      expect(result.isSuccess, isTrue);

      // TTS via OutputHandle with high priority
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, isNot(contains('Attention')));
      expect(mockOutput.speakCalls.first.text, contains('travaux'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);

      // Haptic warning
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.warning);
    });

    test('distance > 10m is ignored', () async {
      final result = await agent.handleInput(
        _obstacleInput(distance: 15.0),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
      expect(mockOutput.hapticCalls, isEmpty);
    });

    test('confidence <= 0.80 is ignored', () async {
      final result = await agent.handleInput(
        _obstacleInput(confidence: 0.80),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
    });

    test('response type is alert', () async {
      final result = await agent.handleInput(_obstacleInput());

      result.when(
        success: (output) {
          expect(output.type, AgentOutputType.alert);
          expect(output.content, contains('voiture'));
          expect(output.metadata!['urgency'], 'immediate');
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  group('no direct service calls', () {
    setUp(() async {
      await spawnAgent();
    });

    test('speaks via output.speak, not direct TTS', () async {
      await agent.handleInput(_obstacleInput());

      // Output handle received the speak call
      expect(mockOutput.speakCalls.length, 1);
    });

    test('haptic via output.haptic, not direct HapticService', () async {
      await agent.handleInput(_obstacleInput());

      // Output handle received the haptic call
      expect(mockOutput.hapticCalls.length, 1);
    });
  });

  group('c est quoi', () {
    setUp(() async {
      await spawnAgent();
    });

    test('describes recent detection via output.speak', () async {
      await agent.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.5, confidence: 0.95),
      );
      mockOutput.speakCalls.clear();
      mockOutput.hapticCalls.clear();

      final result = await agent.handleInput(
        _agentInput(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('voiture'));
          expect(output.content, contains('95 pour cent'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // Spoke via output handle
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);
    });

    test('reports no obstacle when no recent detection', () async {
      final result = await agent.handleInput(
        _agentInput(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );

      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('Aucun obstacle'));
    });

    test('description expires after 10-second window', () async {
      await agent.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.0, confidence: 0.95),
      );
      mockOutput.speakCalls.clear();

      // Advance past 10 seconds
      fakeClock.advance(const Duration(seconds: 11));

      final result = await agent.handleInput(
        _agentInput(command: "c'est quoi"),
      );

      result.when(
        success: (output) {
          expect(output.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  group('lifecycle', () {
    test('handleInput fails when not spawned', () async {
      final result = await agent.handleInput(
        _agentInput(command: 'ok'),
      );

      expect(result.isFailure, isTrue);
    });

    test('onTerminate cleans up state', () async {
      await spawnAgent();
      await agent.handleInput(_obstacleInput());

      await agent.onTerminate();

      // buildViewport returns null after termination
      expect(agent.buildViewport(_FakeBuildContext()), isNull);
    });

    test('onSuspend dismisses active alert', () async {
      await spawnAgent();
      await agent.handleInput(_obstacleInput());
      expect(agent.buildViewport(_FakeBuildContext()), isNotNull);

      await agent.onSuspend();

      expect(agent.buildViewport(_FakeBuildContext()), isNull);
    });
  });

  group('bus messages', () {
    setUp(() async {
      await spawnAgent();
    });

    test('cancelAll dismisses alert', () async {
      await agent.handleInput(_obstacleInput());
      expect(agent.buildViewport(_FakeBuildContext()), isNotNull);

      agent.onBusMessage(AgentMessage(
        fromAgent: 'system',
        type: AgentMessageType.cancelAll,
        payload: const {},
        timestamp: DateTime(2026, 1, 1),
      ));

      expect(agent.buildViewport(_FakeBuildContext()), isNull);
    });
  });
}

class _FakeBuildContext extends Fake implements BuildContext {}
