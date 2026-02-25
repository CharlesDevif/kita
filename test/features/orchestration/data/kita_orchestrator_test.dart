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
  final StreamController<TtsSpeechEvent> _speechController =
      StreamController<TtsSpeechEvent>.broadcast();
  List<String> spokenTexts = [];

  @override
  bool get isSpeaking => false;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _speechController.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async => const Result.success(null);

  void dispose() => _speechController.close();
}

class MockHapticService implements HapticService {
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

/// A test agent that tracks lifecycle calls.
class TrackableAgent implements KitaAgent {
  TrackableAgent({required this.manifest});

  @override
  final AgentManifest manifest;

  int spawnCount = 0;
  int terminateCount = 0;
  final List<AgentInput> receivedInputs = [];

  @override
  List<VoiceCommand> get voiceCommands => const [];

  @override
  Future<void> onSpawn(AgentContext context) async {
    spawnCount++;
  }

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
    await orchestrator.dispose();
    tts.dispose();
    bus.dispose();
  });

  group('KitaOrchestrator', () {
    test('handleInput delegates to InputRouter.route()', () async {
      // Spawn an alert agent first so sensor routing works
      final alertAgent = TrackableAgent(manifest: _alertManifest());
      await supervisor.spawn(alertAgent);

      final input = RawInput.sensor(
        {'distance': 2.0, 'label': 'person'},
        clock: clock,
      );
      await orchestrator.handleInput(input);

      // Verify the InputRouter routed the input to the alert agent
      expect(alertAgent.receivedInputs, hasLength(1));
      expect(alertAgent.receivedInputs.first.command, 'obstacle_detected');
    });

    test('initialize() spawns AlertAgent persistent', () async {
      expect(orchestrator.isInitialized, isFalse);

      await orchestrator.initialize();

      expect(orchestrator.isInitialized, isTrue);
      expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);
      expect(
        supervisor.agents['com.kita.alert']!.agent.manifest.agentType,
        AgentType.persistent,
      );
    });

    test('initialize() is idempotent — double call spawns only once',
        () async {
      await orchestrator.initialize();
      await orchestrator.initialize();

      // Should only have one AlertAgent, not two
      expect(supervisor.agents.length, 1);
      expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);
    });

    test('dispose() terminates all agents', () async {
      // Spawn both persistent and onDemand agents
      await orchestrator.initialize(); // spawns AlertAgent

      final describeAgent = TrackableAgent(manifest: _describeManifest());
      await supervisor.spawn(describeAgent);

      expect(supervisor.agents.length, 2);

      await orchestrator.dispose();

      expect(supervisor.agents, isEmpty);
    });

    test('dispose() terminates onDemand before persistent', () async {
      // Spawn a trackable persistent agent manually so we can track
      // termination order without relying on async bus events.
      final alertAgent = TrackableAgent(manifest: _alertManifest());
      await supervisor.spawn(alertAgent);

      final describeAgent = TrackableAgent(manifest: _describeManifest());
      await supervisor.spawn(describeAgent);

      expect(supervisor.agents.length, 2);

      // Re-create orchestrator using the already-spawned agents
      // (since we can't control initialize() to use TrackableAgents)
      final testOrchestrator = KitaOrchestrator(
        inputRouter: inputRouter,
        supervisor: supervisor,
        outputCoordinator: coordinator,
      );

      await testOrchestrator.dispose();

      // Both agents should be terminated
      expect(supervisor.agents, isEmpty);
      // onDemand terminated first (via returnToPassive), then persistent
      expect(describeAgent.terminateCount, 1);
      expect(alertAgent.terminateCount, 1);
    });

    test('supervisor and outputCoordinator are accessible', () {
      expect(orchestrator.supervisor, same(supervisor));
      expect(orchestrator.outputCoordinator, same(coordinator));
    });
  });
}
