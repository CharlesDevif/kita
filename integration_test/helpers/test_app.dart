/// Shared helpers for integration test journeys.
///
/// Provides [buildOnboardingTestApp] and mock implementations
/// reusable across all journey tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kita/features/orchestration/data/agent_bus_impl.dart';
import 'package:kita/features/orchestration/data/agent_supervisor.dart';
import 'package:kita/features/orchestration/data/input_router.dart';
import 'package:kita/features/orchestration/data/kita_orchestrator.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/stub_access.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/domain/shell_mode.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// Re-export orchestration types for test files that use OrchestratorTestHarness
export 'package:kita/features/orchestration/data/agent_bus_impl.dart';
export 'package:kita/features/orchestration/data/agent_supervisor.dart';
export 'package:kita/features/orchestration/data/input_router.dart';
export 'package:kita/features/orchestration/data/kita_orchestrator.dart';
export 'package:kita/features/orchestration/data/output_coordinator.dart';
export 'package:kita/features/orchestration/domain/clock.dart';
export 'package:kita/features/shell/domain/orb_state.dart';
export 'package:kita/features/shell/domain/shell_mode.dart';

// =============================================================================
// Mock TTS — ne parle pas en tests, capture les textes parlés
// =============================================================================

class IntegrationMockTTSService implements TTSService {
  final List<String> spokenTexts = [];
  String? get lastSpokenText => spokenTexts.isEmpty ? null : spokenTexts.last;
  bool _isSpeaking = false;

  final StreamController<TtsSpeechEvent> _controller =
      StreamController<TtsSpeechEvent>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _controller.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    _isSpeaking = true;
    scheduleMicrotask(() => _isSpeaking = false);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _isSpeaking = false;
    return const Result.success(null);
  }

  void dispose() => _controller.close();
}

// =============================================================================
// IntegrationMockHapticService — capture les patterns haptic déclenchés
// =============================================================================

class IntegrationMockHapticService implements HapticService {
  final List<HapticPattern> triggered = [];

  @override
  Future<Result<void>> trigger(HapticPattern p) async {
    triggered.add(p);
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

// =============================================================================
// IntegrationMockProfileAdapter — profil aveugle par défaut
// =============================================================================

class IntegrationMockProfileAdapter implements ProfileAdapter {
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

// =============================================================================
// Fake permission requester — accorde toujours
// =============================================================================

class FakePermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

// =============================================================================
// OrchestratorTestHarness — setup commun describe/alert journey tests
// =============================================================================

/// Encapsulates the full orchestrator stack for integration tests.
///
/// Eliminates code duplication between describe_journey_test.dart and
/// alert_journey_test.dart which both need identical setUp/tearDown.
class OrchestratorTestHarness {
  late AgentBusImpl bus;
  late PluginSandboxImpl sandbox;
  late FakeClock clock;
  late IntegrationMockTTSService tts;
  late IntegrationMockHapticService haptic;
  late AgentSupervisor supervisor;
  late OutputCoordinator coordinator;
  late InputRouter inputRouter;
  late KitaOrchestrator orchestrator;
  late List<OrbState> orbStates;
  late List<ShellMode> shellModes;

  void setUp() {
    bus = AgentBusImpl();
    sandbox = PluginSandboxImpl(
      sensorAccess: StubSensorAccess(),
      aiAccess: StubAIAccess(),
    );
    clock = FakeClock();
    tts = IntegrationMockTTSService();
    haptic = IntegrationMockHapticService();
    orbStates = [];
    shellModes = [];

    coordinator = OutputCoordinator(
      tts: tts,
      haptic: haptic,
      profileAdapter: IntegrationMockProfileAdapter(),
      clock: clock,
      bus: bus,
      onOrbStateChanged: orbStates.add,
      onShellModeChanged: shellModes.add,
    );
    supervisor = AgentSupervisor(
      bus: bus,
      sandbox: sandbox,
      clock: clock,
      ttsService: tts,
      hapticService: haptic,
      outputCoordinator: coordinator,
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
  }

  Future<void> tearDown() async {
    coordinator.dispose();
    tts.dispose();
    await supervisor.dispose();
    bus.dispose();
  }
}

// =============================================================================
// buildOnboardingTestApp — onboarding avec mocks
// =============================================================================

Widget buildOnboardingTestApp({
  required IntegrationMockTTSService mockTts,
  DetectedProfile detectedProfile = const DetectedProfile(
    profile: AccessibilityProfile.blind,
    screenReader: true,
    largeText: false,
    reduceMotion: false,
    boldText: false,
    highContrast: false,
  ),
}) {
  return ProviderScope(
    overrides: [
      detectedProfileProvider.overrideWith(
        (ref) => Stream.value(detectedProfile),
      ),
      ttsServiceProvider.overrideWithValue(mockTts),
      permissionRequesterProvider.overrideWithValue(FakePermissionRequester()),
    ],
    child: const MaterialApp(
      home: OnboardingScreen(),
    ),
  );
}

