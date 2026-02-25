import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/orchestration/data/agent_bus_impl.dart';
import 'package:kita/features/orchestration/data/agent_supervisor.dart';
import 'package:kita/features/orchestration/data/input_router.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/stub_access.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/models/raw_input.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// ==========================================================================
// Mocks
// ==========================================================================

class MockTTSService implements TTSService {
  bool stopCalled = false;
  int stopCallCount = 0;
  List<String> spokenTexts = [];
  bool _isSpeaking = false;
  final StreamController<TtsSpeechEvent> _speechController =
      StreamController<TtsSpeechEvent>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _speechController.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    _isSpeaking = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalled = true;
    stopCallCount++;
    _isSpeaking = false;
    return const Result.success(null);
  }

  void dispose() {
    _speechController.close();
  }
}

class MockHapticService implements HapticService {
  List<HapticPattern> triggeredPatterns = [];

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    triggeredPatterns.add(pattern);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);

  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);

  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);

  @override
  Future<Result<void>> presence() => trigger(HapticPattern.presence);
}

class MockProfileAdapter implements ProfileAdapter {
  @override
  String get activeProfile => 'aveugle';

  @override
  void feedback({
    void Function()? visual,
    void Function()? vocal,
    void Function()? haptic,
  }) {
    vocal?.call();
    haptic?.call();
  }
}

// Using StubSensorAccess and StubAIAccess from stub_access.dart
// They return proper failures instead of throwing.

/// A trackable mock agent for testing routing.
class TrackableAgent implements KitaAgent {
  TrackableAgent({required this.manifest});

  @override
  final AgentManifest manifest;

  final List<AgentInput> receivedInputs = [];
  AgentContext? lastContext;

  @override
  List<VoiceCommand> get voiceCommands => const [];

  @override
  Future<void> onSpawn(AgentContext context) async {
    lastContext = context;
  }

  @override
  Future<void> onSuspend() async {}

  @override
  Future<void> onResume() async {}

  @override
  Future<void> onTerminate() async {}

  @override
  Future<Result<AgentOutput>> handleInput(AgentInput input) async {
    receivedInputs.add(input);
    return const Result.success(AgentOutput.empty());
  }

  @override
  void onBusMessage(AgentMessage message) {}

  @override
  Widget? buildViewport(BuildContext context) => null;
}

AgentManifest _alertManifest() => const AgentManifest(
      id: 'com.kita.alert',
      name: 'Alert Agent',
      version: '1.0.0',
      description: 'Alert agent',
      trustLevel: TrustLevel.official,
      agentType: AgentType.persistent,
      priority: AgentPriority.critical,
      permissions: ['camera', 'haptic', 'tts'],
      subscriptions: {AgentMessageType.cancelAll, AgentMessageType.userCommand},
    );

AgentManifest _describeManifest() => const AgentManifest(
      id: 'com.kita.describe',
      name: 'Describe Agent',
      version: '1.0.0',
      description: 'Describe agent',
      trustLevel: TrustLevel.official,
      agentType: AgentType.onDemand,
      priority: AgentPriority.standard,
      permissions: ['camera', 'ai.vision', 'tts'],
      subscriptions: {
        AgentMessageType.cancelAll,
        AgentMessageType.interruptRequest,
        AgentMessageType.userCommand,
      },
    );

// ==========================================================================
// Tests
// ==========================================================================

void main() {
  late AgentBusImpl bus;
  late PluginSandboxImpl sandbox;
  late FakeClock clock;
  late MockTTSService tts;
  late MockHapticService haptic;
  late MockProfileAdapter profileAdapter;
  late AgentSupervisor supervisor;
  late OutputCoordinator coordinator;
  late InputRouter router;

  // Track bus messages for assertions
  late List<AgentMessage> busMessages;
  late StreamSubscription<AgentMessage> busSubscription;

  setUp(() {
    bus = AgentBusImpl();
    sandbox = PluginSandboxImpl(
      sensorAccess: StubSensorAccess(),
      aiAccess: StubAIAccess(),
    );
    clock = FakeClock();
    tts = MockTTSService();
    haptic = MockHapticService();
    profileAdapter = MockProfileAdapter();
    supervisor = AgentSupervisor(
      bus: bus,
      sandbox: sandbox,
      clock: clock,
      ttsService: tts,
      hapticService: haptic,
    );
    coordinator = OutputCoordinator(
      tts: tts,
      haptic: haptic,
      profileAdapter: profileAdapter,
      clock: clock,
      bus: bus,
      onOrbStateChanged: (_) {},
      onShellModeChanged: (_) {},
    );
    router = InputRouter(
      supervisor: supervisor,
      bus: bus,
      outputCoordinator: coordinator,
      clock: clock,
    );

    // Listen to bus messages for assertions
    busMessages = [];
    bus.subscribe('test-listener', {
      AgentMessageType.cancelAll,
      AgentMessageType.agentSpawned,
      AgentMessageType.agentTerminated,
    });
    busSubscription = bus.streamFor('test-listener').listen(busMessages.add);
  });

  tearDown(() async {
    await busSubscription.cancel();
    await supervisor.dispose();
    coordinator.dispose();
    tts.dispose();
    bus.dispose();
  });

  group('InputRouter', () {
    group('sensor input routing', () {
      test('routes sensor input to AlertAgent', () async {
        // Spawn a trackable alert agent
        final alertAgent = TrackableAgent(manifest: _alertManifest());
        await supervisor.spawn(alertAgent);

        // Route sensor input
        final input = RawInput.sensor(
          {'distance': 2.0, 'label': 'person'},
          clock: clock,
        );
        await router.route(input);

        // Verify AlertAgent received the input
        expect(alertAgent.receivedInputs, hasLength(1));
        expect(
          alertAgent.receivedInputs.first.command,
          'obstacle_detected',
        );
        expect(
          alertAgent.receivedInputs.first.source,
          InputSource.sensor,
        );
      });

      test('logs warning when AlertAgent not active for sensor input',
          () async {
        // No AlertAgent spawned
        final input = RawInput.sensor(
          {'distance': 2.0},
          clock: clock,
        );

        // Should not throw
        await router.route(input);
      });
    });

    group('voice command: stop', () {
      test('"stop" publishes cancelAll and calls coordinator cancelAll',
          () async {
        final input = RawInput.voice('stop', clock: clock);
        await router.route(input);

        // Verify cancelAll was published on bus
        final cancelMessages = busMessages
            .where((m) => m.type == AgentMessageType.cancelAll)
            .toList();
        expect(cancelMessages, isNotEmpty);

        // Verify TTS was stopped (coordinator.cancelAll calls tts.stop)
        expect(tts.stopCalled, isTrue);
      });

      test('"arrete" routes same as stop', () async {
        final input = RawInput.voice('arrete', clock: clock);
        await router.route(input);

        final cancelMessages = busMessages
            .where((m) => m.type == AgentMessageType.cancelAll)
            .toList();
        expect(cancelMessages, isNotEmpty);
        expect(tts.stopCalled, isTrue);
      });

      test('"stop" terminates onDemand agents', () async {
        // Spawn an onDemand agent
        final describeAgent = TrackableAgent(manifest: _describeManifest());
        await supervisor.spawn(describeAgent);
        expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);

        final input = RawInput.voice('stop', clock: clock);
        await router.route(input);

        // onDemand agent should be terminated
        expect(supervisor.agents.containsKey('com.kita.describe'), isFalse);
      });
    });

    group('voice command: describe', () {
      test('"decris" spawns DescribeAgent when not active', () async {
        final input = RawInput.voice('decris', clock: clock);
        await router.route(input);

        // Verify DescribeAgent was spawned
        expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);
      });

      test('"decris" re-routes to existing agent when already active',
          () async {
        // Pre-spawn a trackable describe agent
        final describeAgent = TrackableAgent(manifest: _describeManifest());
        await supervisor.spawn(describeAgent);

        // Say "decris" again
        final input = RawInput.voice('decris', clock: clock);
        await router.route(input);

        // Should NOT have double-spawned
        expect(supervisor.agents.length, 1);

        // Should have received the "decris" command
        expect(describeAgent.receivedInputs, hasLength(1));
        expect(describeAgent.receivedInputs.first.command, 'decris');
      });
    });

    group('voice command: focus agent routing', () {
      test('"plus de details" routes to focused agent', () async {
        // Spawn a describe agent and set it as focused
        final describeAgent = TrackableAgent(manifest: _describeManifest());
        await supervisor.spawn(describeAgent);

        // Simulate focus by enqueueing speech from this agent
        // (the coordinator tracks focusedAgentId when speech is enqueued)
        await coordinator.enqueueSpeech(
          'com.kita.describe',
          'Test speech',
          OutputPriority.standard,
        );

        final input = RawInput.voice('plus de details', clock: clock);
        await router.route(input);

        expect(describeAgent.receivedInputs, hasLength(1));
        expect(
          describeAgent.receivedInputs.first.command,
          'plus de details',
        );
      });

      test('"repete" routes to focused agent', () async {
        final describeAgent = TrackableAgent(manifest: _describeManifest());
        await supervisor.spawn(describeAgent);
        await coordinator.enqueueSpeech(
          'com.kita.describe',
          'Test speech',
          OutputPriority.standard,
        );

        final input = RawInput.voice('repete', clock: clock);
        await router.route(input);

        expect(describeAgent.receivedInputs, hasLength(1));
        expect(describeAgent.receivedInputs.first.command, 'repete');
      });

      test('"merci" routes to focused agent', () async {
        final describeAgent = TrackableAgent(manifest: _describeManifest());
        await supervisor.spawn(describeAgent);
        await coordinator.enqueueSpeech(
          'com.kita.describe',
          'Test speech',
          OutputPriority.standard,
        );

        final input = RawInput.voice('merci', clock: clock);
        await router.route(input);

        expect(describeAgent.receivedInputs, hasLength(1));
        expect(describeAgent.receivedInputs.first.command, 'merci');
      });

      test('focus command falls back when no agent at focus', () async {
        // No agent spawned, no focus
        final input = RawInput.voice('plus de details', clock: clock);

        // Should not throw — falls back to fallback
        await router.route(input);
      });
    });

    group('unknown command: fallback routing', () {
      test('unknown command routes to fallback without throwing', () async {
        final input = RawInput.voice('quelle heure est-il', clock: clock);
        await router.route(input);
        // Should not throw — logs and returns
      });

      test('empty transcript is ignored', () async {
        final input = RawInput.voice('', clock: clock);
        await router.route(input);
        // Should return immediately without routing
      });
    });

    group('VoiceCommandHandler integration', () {
      test('recognizes known voice commands', () async {
        // "aide" should be recognized as "help" and go to fallback
        final input = RawInput.voice('aide', clock: clock);
        await router.route(input);
        // Should not throw
      });

      test('text input uses VoiceCommandHandler too', () async {
        final input = RawInput.text('decris', clock: clock);
        await router.route(input);

        // Should spawn DescribeAgent via voice command recognition
        expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);
      });
    });
  });
}
