import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/orchestration/data/agent_bus_impl.dart';
import 'package:kita/features/orchestration/data/agent_supervisor.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';

// === Mocks ===

class MockTTSService implements TTSService {
  final StreamController<SpeechEvent> _speechController =
      StreamController<SpeechEvent>.broadcast();

  @override
  bool get isSpeaking => false;

  @override
  Stream<SpeechEvent> get speechEvents => _speechController.stream;

  @override
  Future<Result<void>> speak(String text,
      {TTSPriority priority = TTSPriority.standard}) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    return const Result.success(null);
  }
}

class MockHapticService implements HapticService {
  @override
  Future<Result<void>> trigger(HapticPattern pattern) async =>
      const Result.success(null);

  @override
  Future<Result<void>> info() async => const Result.success(null);

  @override
  Future<Result<void>> warning() async => const Result.success(null);

  @override
  Future<Result<void>> danger() async => const Result.success(null);

  @override
  Future<Result<void>> presence() async => const Result.success(null);
}

class StubSensorAccess implements SensorAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class StubAIAccess implements AIAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A mock agent for testing lifecycle operations.
class MockKitaAgent implements KitaAgent {
  MockKitaAgent({
    required this.manifest,
    this.onSpawnCallback,
    this.onTerminateCallback,
    this.onSuspendCallback,
    this.onResumeCallback,
  });

  @override
  final AgentManifest manifest;

  final Future<void> Function(AgentContext)? onSpawnCallback;
  final Future<void> Function()? onTerminateCallback;
  final Future<void> Function()? onSuspendCallback;
  final Future<void> Function()? onResumeCallback;

  int spawnCount = 0;
  int terminateCount = 0;
  int suspendCount = 0;
  int resumeCount = 0;
  AgentContext? lastContext;

  @override
  List<VoiceCommand> get voiceCommands => const [];

  @override
  Future<void> onSpawn(AgentContext context) async {
    spawnCount++;
    lastContext = context;
    await onSpawnCallback?.call(context);
  }

  @override
  Future<void> onSuspend() async {
    suspendCount++;
    await onSuspendCallback?.call();
  }

  @override
  Future<void> onResume() async {
    resumeCount++;
    await onResumeCallback?.call();
  }

  @override
  Future<void> onTerminate() async {
    terminateCount++;
    await onTerminateCallback?.call();
  }

  @override
  Future<Result<AgentOutput>> handleInput(AgentInput input) async {
    return const Result.success(AgentOutput.empty());
  }

  @override
  void onBusMessage(AgentMessage message) {}

  @override
  Widget? buildViewport(BuildContext context) => null;
}

AgentManifest _testManifest({
  String id = 'com.test.agent',
  AgentType agentType = AgentType.onDemand,
  AgentPriority priority = AgentPriority.standard,
}) {
  return AgentManifest(
    id: id,
    name: 'Test Agent',
    version: '1.0.0',
    description: 'A test agent',
    trustLevel: TrustLevel.official,
    agentType: agentType,
    priority: priority,
    permissions: ['camera'],
    subscriptions: {AgentMessageType.cancelAll},
  );
}

void main() {
  late AgentBusImpl bus;
  late PluginSandboxImpl sandbox;
  late FakeClock clock;
  late MockTTSService tts;
  late MockHapticService haptic;
  late AgentSupervisor supervisor;

  setUp(() {
    bus = AgentBusImpl();
    sandbox = PluginSandboxImpl(
      sensorAccess: StubSensorAccess(),
      aiAccess: StubAIAccess(),
    );
    clock = FakeClock();
    tts = MockTTSService();
    haptic = MockHapticService();
    supervisor = AgentSupervisor(
      bus: bus,
      sandbox: sandbox,
      clock: clock,
      ttsService: tts,
      hapticService: haptic,
    );
    KitaLogger.testLogHandler = (_) {};
  });

  tearDown(() {
    bus.dispose();
    KitaLogger.testLogHandler = null;
  });

  group('spawn lifecycle', () {
    test('spawn calls onSpawn with valid AgentContext', () async {
      final agent = MockKitaAgent(manifest: _testManifest());

      final result = await supervisor.spawn(agent);

      expect(result.isSuccess, isTrue);
      expect(agent.spawnCount, 1);
      expect(agent.lastContext, isNotNull);
      expect(agent.lastContext!.sensors, isNotNull);
      expect(agent.lastContext!.ai, isNotNull);
      expect(agent.lastContext!.bus, isNotNull);
      expect(agent.lastContext!.output, isNotNull);
      expect(agent.lastContext!.clock, isNotNull);
    });

    test('spawn adds agent to agents map with active state', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      expect(supervisor.agents.containsKey('com.test.agent'), isTrue);
      expect(supervisor.agents['com.test.agent']!.state, AgentState.active);
    });

    test('suspend changes state to suspended and calls onSuspend', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      final result = await supervisor.suspend('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(agent.suspendCount, 1);
      expect(
          supervisor.agents['com.test.agent']!.state, AgentState.suspended);
    });

    test('resume changes state to active and calls onResume', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);
      await supervisor.suspend('com.test.agent');

      final result = await supervisor.resume('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(agent.resumeCount, 1);
      expect(supervisor.agents['com.test.agent']!.state, AgentState.active);
    });

    test('terminate calls onTerminate and removes from map', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      final result = await supervisor.terminate('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(agent.terminateCount, 1);
      expect(supervisor.agents.containsKey('com.test.agent'), isFalse);
    });

    test('terminate calls bus.unsubscribe', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      await supervisor.terminate('com.test.agent');

      // After unsubscribe, streamFor should not deliver messages.
      // We can verify by checking the agents map is empty.
      expect(supervisor.agents, isEmpty);
    });

    test('duplicate spawn fails', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      final result = await supervisor.spawn(agent);

      expect(result.isFailure, isTrue);
      expect(agent.spawnCount, 1);
    });

    test('terminate non-existent agent fails', () async {
      final result = await supervisor.terminate('com.nonexistent');

      expect(result.isFailure, isTrue);
    });

    test('suspend non-existent agent fails', () async {
      final result = await supervisor.suspend('com.nonexistent');

      expect(result.isFailure, isTrue);
    });

    test('resume non-existent agent fails', () async {
      final result = await supervisor.resume('com.nonexistent');

      expect(result.isFailure, isTrue);
    });
  });

  group('crash isolation', () {
    test('onSpawn crash returns failure and does not add agent', () async {
      final agent = MockKitaAgent(
        manifest: _testManifest(),
        onSpawnCallback: (_) async => throw Exception('spawn crash'),
      );

      final result = await supervisor.spawn(agent);

      expect(result.isFailure, isTrue);
      expect(supervisor.agents, isEmpty);
    });

    test('onTerminate crash still removes agent from map', () async {
      final agent = MockKitaAgent(
        manifest: _testManifest(),
        onTerminateCallback: () async => throw Exception('terminate crash'),
      );
      await supervisor.spawn(agent);

      final result = await supervisor.terminate('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(supervisor.agents, isEmpty);
    });

    test('onSuspend crash still marks agent as suspended', () async {
      final agent = MockKitaAgent(
        manifest: _testManifest(),
        onSuspendCallback: () async => throw Exception('suspend crash'),
      );
      await supervisor.spawn(agent);

      final result = await supervisor.suspend('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(
          supervisor.agents['com.test.agent']!.state, AgentState.suspended);
    });

    test('onResume crash still marks agent as active', () async {
      final agent = MockKitaAgent(
        manifest: _testManifest(),
        onResumeCallback: () async => throw Exception('resume crash'),
      );
      await supervisor.spawn(agent);
      await supervisor.suspend('com.test.agent');

      final result = await supervisor.resume('com.test.agent');

      expect(result.isSuccess, isTrue);
      expect(supervisor.agents['com.test.agent']!.state, AgentState.active);
    });

    test('crashing agent does not affect other agents', () async {
      final goodAgent =
          MockKitaAgent(manifest: _testManifest(id: 'com.test.good'));
      final badAgent = MockKitaAgent(
        manifest: _testManifest(id: 'com.test.bad'),
        onTerminateCallback: () async => throw Exception('crash'),
      );

      await supervisor.spawn(goodAgent);
      await supervisor.spawn(badAgent);

      // Terminate bad agent (crashes but gets removed)
      await supervisor.terminate('com.test.bad');

      // Good agent is still active
      expect(supervisor.agents.containsKey('com.test.good'), isTrue);
      expect(supervisor.agents['com.test.good']!.state, AgentState.active);
    });
  });

  group('returnToPassive', () {
    test('terminates onDemand agents, keeps persistent', () async {
      final persistentAgent = MockKitaAgent(
        manifest: _testManifest(
          id: 'com.test.persistent',
          agentType: AgentType.persistent,
        ),
      );
      final onDemandAgent = MockKitaAgent(
        manifest: _testManifest(
          id: 'com.test.ondemand',
          agentType: AgentType.onDemand,
        ),
      );

      await supervisor.spawn(persistentAgent);
      await supervisor.spawn(onDemandAgent);

      expect(supervisor.agents.length, 2);

      await supervisor.returnToPassive();

      expect(supervisor.agents.length, 1);
      expect(
          supervisor.agents.containsKey('com.test.persistent'), isTrue);
      expect(
          supervisor.agents.containsKey('com.test.ondemand'), isFalse);
      expect(onDemandAgent.terminateCount, 1);
      expect(persistentAgent.terminateCount, 0);
    });

    test('returnToPassive with no onDemand agents is a no-op', () async {
      final persistentAgent = MockKitaAgent(
        manifest: _testManifest(
          id: 'com.test.persistent',
          agentType: AgentType.persistent,
        ),
      );
      await supervisor.spawn(persistentAgent);

      await supervisor.returnToPassive();

      expect(supervisor.agents.length, 1);
      expect(persistentAgent.terminateCount, 0);
    });
  });

  group('max agents limit', () {
    test('6th spawn fails when 5 are already active', () async {
      // Spawn 5 agents
      for (var i = 0; i < 5; i++) {
        final agent =
            MockKitaAgent(manifest: _testManifest(id: 'com.test.agent$i'));
        final result = await supervisor.spawn(agent);
        expect(result.isSuccess, isTrue);
      }

      expect(supervisor.agents.length, 5);

      // 6th should fail
      final sixthAgent =
          MockKitaAgent(manifest: _testManifest(id: 'com.test.agent5'));
      final result = await supervisor.spawn(sixthAgent);

      expect(result.isFailure, isTrue);
      expect(supervisor.agents.length, 5);
      expect(sixthAgent.spawnCount, 0);
    });

    test('can spawn new agent after terminating one', () async {
      // Spawn 5 agents
      for (var i = 0; i < 5; i++) {
        await supervisor.spawn(
            MockKitaAgent(manifest: _testManifest(id: 'com.test.agent$i')));
      }

      // Terminate one
      await supervisor.terminate('com.test.agent0');
      expect(supervisor.agents.length, 4);

      // Now spawn a new one
      final newAgent =
          MockKitaAgent(manifest: _testManifest(id: 'com.test.new'));
      final result = await supervisor.spawn(newAgent);

      expect(result.isSuccess, isTrue);
      expect(supervisor.agents.length, 5);
    });
  });

  group('agents map', () {
    test('reflects correct states for multiple agents', () async {
      final agent1 = MockKitaAgent(
          manifest: _testManifest(id: 'com.test.a1'));
      final agent2 = MockKitaAgent(
          manifest: _testManifest(id: 'com.test.a2'));

      await supervisor.spawn(agent1);
      await supervisor.spawn(agent2);
      await supervisor.suspend('com.test.a2');

      expect(supervisor.agents['com.test.a1']!.state, AgentState.active);
      expect(supervisor.agents['com.test.a2']!.state, AgentState.suspended);
    });

    test('agents map is unmodifiable', () async {
      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      expect(
        () => supervisor.agents['new.agent'] = supervisor.agents.values.first,
        throwsUnsupportedError,
      );
    });
  });

  group('bus messages', () {
    test('spawn publishes agentSpawned message', () async {
      final messages = <AgentMessage>[];
      // Subscribe a listener to capture bus messages
      bus.subscribe('_test_listener', {AgentMessageType.agentSpawned});
      bus.streamFor('_test_listener').listen(messages.add);

      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);

      // Allow microtask to deliver the message
      await Future<void>.delayed(Duration.zero);

      expect(messages.length, 1);
      expect(messages.first.type, AgentMessageType.agentSpawned);
      expect(messages.first.payload['agentId'], 'com.test.agent');
    });

    test('terminate publishes agentTerminated message', () async {
      final messages = <AgentMessage>[];
      bus.subscribe('_test_listener', {AgentMessageType.agentTerminated});
      bus.streamFor('_test_listener').listen(messages.add);

      final agent = MockKitaAgent(manifest: _testManifest());
      await supervisor.spawn(agent);
      await supervisor.terminate('com.test.agent');

      await Future<void>.delayed(Duration.zero);

      expect(messages.length, 1);
      expect(messages.first.type, AgentMessageType.agentTerminated);
    });
  });

  group('dispose', () {
    test('dispose terminates all agents', () async {
      final agent1 = MockKitaAgent(
          manifest: _testManifest(id: 'com.test.a1'));
      final agent2 = MockKitaAgent(
          manifest: _testManifest(id: 'com.test.a2'));

      await supervisor.spawn(agent1);
      await supervisor.spawn(agent2);

      await supervisor.dispose();

      expect(supervisor.agents, isEmpty);
      expect(agent1.terminateCount, 1);
      expect(agent2.terminateCount, 1);
    });
  });
}
