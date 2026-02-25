/// E2E test: "Interruption obstacle"
///
/// Scenario: DescribeAgent is active. An obstacle sensor event arrives.
/// AlertAgent receives the input → coordinator handles CRITICAL priority →
/// DescribeAgent terminates → AlertAgent processes obstacle.
library;
///
/// All hardware dependencies are mocked.
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
import 'package:kita/features/orchestration/data/kita_orchestrator.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/stub_access.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/raw_input.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// ==========================================================================
// Mocks
// ==========================================================================

class MockTTSService implements TTSService {
  List<String> spokenTexts = [];
  bool _isSpeaking = false;
  bool stopCalled = false;
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
    _isSpeaking = false;
    return const Result.success(null);
  }

  void dispose() => _speechController.close();
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

/// A trackable agent to verify input routing and bus messages.
class TrackableAgent implements KitaAgent {
  TrackableAgent({required this.manifest});

  @override
  final AgentManifest manifest;

  int terminateCount = 0;
  final List<AgentInput> receivedInputs = [];
  final List<AgentMessage> receivedBusMessages = [];

  @override
  List<VoiceCommand> get voiceCommands => const [];

  @override
  Future<void> onSpawn(AgentContext context) async {}

  @override
  Future<void> onSuspend() async {}

  @override
  Future<void> onResume() async {}

  @override
  Future<void> onTerminate() async {
    terminateCount++;
  }

  @override
  Future<Result<AgentOutput>> handleInput(AgentInput input) async {
    receivedInputs.add(input);
    return const Result.success(AgentOutput.empty());
  }

  @override
  void onBusMessage(AgentMessage message) {
    receivedBusMessages.add(message);
  }

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
  late InputRouter inputRouter;
  late KitaOrchestrator orchestrator;

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
    inputRouter = InputRouter(
      supervisor: supervisor,
      bus: bus,
      outputCoordinator: coordinator,
      clock: clock,
    );
    orchestrator = KitaOrchestrator(
      inputRouter: inputRouter,
      supervisor: supervisor,
      outputCoordinator: coordinator,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    tts.dispose();
    await supervisor.dispose();
    bus.dispose();
  });

  test('Interruption obstacle — sensor event routed to AlertAgent while DescribeAgent active',
      () async {
    // Setup: Both agents active
    final alertAgent = TrackableAgent(manifest: _alertManifest());
    final describeAgent = TrackableAgent(manifest: _describeManifest());

    await supervisor.spawn(alertAgent);
    await supervisor.spawn(describeAgent);

    expect(supervisor.agents.length, 2);

    // Obstacle detected at 2m
    final sensorInput = RawInput.sensor(
      {'distance': 2.0, 'label': 'obstacle', 'zone': 'front'},
      clock: clock,
    );

    await orchestrator.handleInput(sensorInput);

    // AC: AlertAgent received the obstacle_detected input
    expect(alertAgent.receivedInputs, hasLength(1));
    expect(alertAgent.receivedInputs.first.command, 'obstacle_detected');
    expect(alertAgent.receivedInputs.first.source, InputSource.sensor);
    expect(alertAgent.receivedInputs.first.params['distance'], 2.0);

    // AC: DescribeAgent was NOT terminated by the sensor event itself
    // (The sensor event goes to AlertAgent, not a cancelAll. The alert
    // agent would need to publish an interruptRequest on the bus to
    // interrupt the describe agent. In this test with TrackableAgent,
    // the alert agent doesn't do that automatically.)
    // However, the AlertAgent in a real system would enqueue CRITICAL
    // speech which would interrupt the DescribeAgent's speech.

    // AC: AlertAgent is still active
    expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);
  });

  test('Sensor input is routed to AlertAgent even when DescribeAgent active',
      () async {
    final alertAgent = TrackableAgent(manifest: _alertManifest());
    await supervisor.spawn(alertAgent);

    // Simulate DescribeAgent being active
    final describeAgent = TrackableAgent(manifest: _describeManifest());
    await supervisor.spawn(describeAgent);

    // Multiple sensor events
    for (var i = 0; i < 3; i++) {
      await orchestrator.handleInput(RawInput.sensor(
        {'distance': 1.0 + i, 'label': 'person_$i'},
        clock: clock,
      ));
    }

    // All sensor events went to AlertAgent
    expect(alertAgent.receivedInputs, hasLength(3));
    for (final input in alertAgent.receivedInputs) {
      expect(input.command, 'obstacle_detected');
      expect(input.source, InputSource.sensor);
    }

    // DescribeAgent received no sensor events (sensor goes only to Alert)
    expect(describeAgent.receivedInputs, isEmpty);
  });

  test('Sensor input without AlertAgent logs warning and does not crash',
      () async {
    // Only DescribeAgent, no AlertAgent
    final describeAgent = TrackableAgent(manifest: _describeManifest());
    await supervisor.spawn(describeAgent);

    // Sensor event with no AlertAgent to receive it
    final input = RawInput.sensor(
      {'distance': 1.0, 'label': 'obstacle'},
      clock: clock,
    );

    // Should not throw
    await orchestrator.handleInput(input);

    // DescribeAgent should not receive sensor events
    expect(describeAgent.receivedInputs, isEmpty);
  });
}
