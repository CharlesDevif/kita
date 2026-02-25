/// E2E test: "Stop total"
///
/// Scenario: AlertAgent (persistent) + DescribeAgent (onDemand) are both active.
/// Marie says "stop" → cancelAll broadcast → DescribeAgent terminated (onDemand)
/// → AlertAgent stays (persistent) → output queue cleared → feedback "OK".
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

/// A trackable agent for verifying bus message reception.
class TrackableAgent implements KitaAgent {
  TrackableAgent({required this.manifest});

  @override
  final AgentManifest manifest;

  int spawnCount = 0;
  int terminateCount = 0;
  final List<AgentMessage> receivedBusMessages = [];

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

  test(
      'Stop total — cancelAll → describe terminated, alert stays, feedback OK',
      () async {
    // Setup: Spawn persistent AlertAgent + onDemand DescribeAgent
    final alertAgent = TrackableAgent(manifest: _alertManifest());
    final describeAgent = TrackableAgent(manifest: _describeManifest());

    await supervisor.spawn(alertAgent);
    await supervisor.spawn(describeAgent);

    expect(supervisor.agents.length, 2);

    // Marie says "stop"
    await orchestrator.handleInput(RawInput.voice('stop', clock: clock));

    // AC: cancelAll published on bus — both agents received it
    // (alertAgent is subscribed to cancelAll)
    final alertCancelMessages = alertAgent.receivedBusMessages
        .where((m) => m.type == AgentMessageType.cancelAll)
        .toList();
    expect(alertCancelMessages, isNotEmpty,
        reason: 'AlertAgent should receive cancelAll');

    // AC: DescribeAgent (onDemand) terminated
    expect(supervisor.agents.containsKey('com.kita.describe'), isFalse,
        reason: 'onDemand DescribeAgent should be terminated');
    expect(describeAgent.terminateCount, 1);

    // AC: AlertAgent (persistent) stays active
    expect(supervisor.agents.containsKey('com.kita.alert'), isTrue,
        reason: 'persistent AlertAgent should remain');
    expect(alertAgent.terminateCount, 0);

    // AC: TTS was stopped (coordinator.cancelAll calls tts.stop)
    expect(tts.stopCalled, isTrue,
        reason: 'TTS should be stopped by cancelAll');

    // AC: Feedback "OK" was spoken
    expect(tts.spokenTexts, contains('OK'),
        reason: 'Feedback "OK" should be spoken after cancelAll');
  });

  test('Stop total — only onDemand agents are terminated, persistent remain',
      () async {
    // Spawn only persistent agent
    final alertAgent = TrackableAgent(manifest: _alertManifest());
    await supervisor.spawn(alertAgent);

    expect(supervisor.agents.length, 1);

    // "stop" with no onDemand agent
    await orchestrator.handleInput(RawInput.voice('stop', clock: clock));

    // AlertAgent should still be active
    expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);
    expect(alertAgent.terminateCount, 0);

    // Feedback "OK" still spoken
    expect(tts.spokenTexts, contains('OK'));
  });
}
