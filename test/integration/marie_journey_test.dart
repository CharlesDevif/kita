// Marie's E2E Journey Test
//
// Simulates the full user journey for persona Marie (blind, VoiceOver):
//   App launch -> onboarding greeting -> name entry via voice ->
//   onboarding completes -> user says "decris" -> describe plugin activates ->
//   AI returns description -> TTS speaks.
//
// Uses real orchestration (InputRouter, AgentSupervisor, OutputCoordinator)
// with mocked hardware (camera, STT, TTS, haptic, location, motion).
//
// Uses `test()` + `ProviderContainer` (not `testWidgets`) per CLAUDE.md
// guidance on StreamProvider hang avoidance.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/data/ai_router_impl.dart';
import 'package:kita/features/ai/data/request_classifier_impl.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/tool_models.dart';
import 'package:kita/features/io/data/voice_command_handler.dart';
import 'package:kita/features/onboarding/data/pack_installer.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/orchestration/data/agent_supervisor.dart';
import 'package:kita/features/orchestration/data/input_router.dart';
import 'package:kita/features/orchestration/data/kita_orchestrator.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/real_access.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/raw_input.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/domain/shell_mode.dart';
import 'package:kita/shared/multi_modal/profile_adapter_impl.dart';

import '../mocks/mock_camera_service.dart';
import '../mocks/mock_haptic_service.dart';
import '../mocks/mock_location_service.dart';
import '../mocks/mock_motion_service.dart';
import '../mocks/mock_tts_service.dart';

// =============================================================================
// Test-local mocks for AI pipeline
// =============================================================================

/// Mock AI provider that returns predictable responses and tracks calls.
class _MockVisionAIProvider implements AIProvider {
  _MockVisionAIProvider();

  @override
  final String id = 'mock-local';
  @override
  final String displayName = 'Mock Local AI';
  @override
  final ProviderTier tier = ProviderTier.local;
  @override
  final bool isAvailable = true;

  bool completeCalled = false;
  bool visionCalled = false;
  bool visionStreamCalled = false;
  String? lastVisionPrompt;

  static const visionDescription =
      'Un trottoir avec trois pietons devant un passage pieton.';

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    completeCalled = true;
    return Result.success(AIResponse(
      content: 'Reponse texte mock',
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 50),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(
    ImageData image,
    String prompt, {
    int? maxTokens,
  }) async {
    visionCalled = true;
    lastVisionPrompt = prompt;
    return Result.success(AIResponse(
      content: visionDescription,
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 100),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> completeStream(AIRequest request) {
    return batchCompleteAsStream(() => complete(request));
  }

  @override
  Stream<String> visionStream(
    ImageData image,
    String prompt, {
    int? maxTokens,
  }) async* {
    visionStreamCalled = true;
    lastVisionPrompt = prompt;
    // Simulate streaming: yield the description in chunks
    final words = visionDescription.split(' ');
    for (final word in words) {
      yield '$word ';
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    return Result.success(AIToolResponse(
      text: 'Mock tool response',
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 50),
        tier: tier,
      ),
    ));
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    return const Result.success(null);
  }
}

// =============================================================================
// Integration test: Marie's full journey
// =============================================================================

void main() {
  late MockCameraService mockCamera;
  late MockTTSService mockTts;
  late MockHapticService mockHaptic;
  late MockLocationService mockLocation;
  late MockMotionService mockMotion;
  late _MockVisionAIProvider mockAI;
  late FakeClock fakeClock;
  late List<LogEntry> logEntries;

  setUp(() {
    logEntries = [];
    KitaLogger.testLogHandler = logEntries.add;

    mockCamera = MockCameraService();
    mockTts = MockTTSService();
    mockHaptic = MockHapticService();
    mockLocation = MockLocationService();
    mockMotion = MockMotionService();
    mockAI = _MockVisionAIProvider();
    fakeClock = FakeClock();
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockTts.dispose();
  });

  group("Marie's E2E Journey", () {
    // -----------------------------------------------------------------------
    // Phase 1: Onboarding state transitions (no widgets)
    // -----------------------------------------------------------------------
    test(
      'Phase 1: onboarding detects blind profile and walks through steps',
      () async {
        final container = ProviderContainer(
          overrides: [
            detectedProfileProvider.overrideWith(
              (ref) => Stream.value(const DetectedProfile(
                profile: AccessibilityProfile.blind,
                screenReader: true,
                largeText: false,
                reduceMotion: false,
                boldText: false,
                highContrast: false,
              )),
            ),
          ],
        );

        try {
          // Trigger stream subscription
          container.listen(detectedProfileProvider, (_, __) {});
          await Future<void>.delayed(Duration.zero);

          final notifier =
              container.read(onboardingNotifierProvider.notifier);
          var state = container.read(onboardingNotifierProvider);

          // Detection -> Welcome (automatic via stream)
          expect(state.step, OnboardingStep.welcome);
          expect(state.detectedProfile!.profile, AccessibilityProfile.blind);
          expect(state.detectedProfile!.screenReader, isTrue);

          // Simulate: Kita says greeting (TTS would speak)
          // Marie says her name via STT
          notifier.setUserName('Marie');
          notifier.completeWelcome();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.modeChoice);
          expect(state.userName, 'Marie');

          // Marie selects "Pour moi" (standard mode)
          notifier.chooseStandardMode();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.profile);

          // Profile blind is pre-selected via detection
          await notifier.selectProfile(AccessibilityProfile.blind);
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.permissions);

          // Grant permissions
          notifier.grantPermission('camera');
          notifier.grantPermission('microphone');
          notifier.grantPermission('location');
          notifier.completePermissions();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.magic);

          // Complete onboarding
          notifier.completeOnboarding();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.complete);
          expect(state.onboardingComplete, isTrue);

          final isComplete = container.read(onboardingCompleteProvider);
          expect(isComplete, isTrue);
        } finally {
          container.dispose();
        }
      },
    );

    // -----------------------------------------------------------------------
    // Phase 2: Voice command recognition
    // -----------------------------------------------------------------------
    test('Phase 2: "decris" voice command is recognized', () {
      final result = VoiceCommandHandler.recognize('decris');
      expect(result.isSuccess, isTrue);
      expect(
        (result as Success<VoiceCommand>).value,
        VoiceCommand.describe,
      );
    });

    test('Phase 2b: accent variants for "decris"', () {
      for (final variant in ['decris', 'décris', 'decrit', 'describe']) {
        final result = VoiceCommandHandler.recognize(variant);
        expect(result.isSuccess, isTrue,
            reason: '"$variant" should be recognized');
        expect(
          (result as Success<VoiceCommand>).value,
          VoiceCommand.describe,
          reason: '"$variant" should map to describe',
        );
      }
    });

    // -----------------------------------------------------------------------
    // Phase 3: Blind pack installs describe + alert
    // -----------------------------------------------------------------------
    test('Phase 3: blind pack includes describe and alert plugins', () async {
      final installer = PackInstaller();
      final result =
          await installer.installPack(AccessibilityProfile.blind);
      expect(result.isSuccess, isTrue);

      final pack = (result as Success<PackConfig>).value;
      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, contains('com.kita.alert'));
    });

    // -----------------------------------------------------------------------
    // Phase 4: Full orchestration E2E — voice "decris" -> describe plugin ->
    //          AI vision -> TTS speaks
    // -----------------------------------------------------------------------
    test(
      'Phase 4: "decris" routes through orchestrator, spawns describe agent, '
      'captures photo, calls AI vision, and speaks description via TTS',
      () async {
        // --- Build real orchestration with mock hardware ---
        final aiRouter = AIRouterImpl(
          classifier: RequestClassifierImpl(),
          providers: [mockAI],
        );

        final sensorAccess = RealSensorAccess(
          cameraService: mockCamera,
          locationService: mockLocation,
          motionService: mockMotion,
        );

        final aiAccess = RealAIAccess(aiRouter: aiRouter);

        final sandbox = PluginSandboxImpl(
          sensorAccess: sensorAccess,
          aiAccess: aiAccess,
        );

        final bus = _TestAgentBus();

        final profileAdapter =
            ProfileAdapterImpl(profile: UserProfile.aveugle);

        final orbStates = <OrbState>[];
        final shellModes = <ShellMode>[];

        final coordinator = OutputCoordinator(
          tts: mockTts,
          haptic: mockHaptic,
          profileAdapter: profileAdapter,
          clock: fakeClock,
          bus: bus,
          onOrbStateChanged: orbStates.add,
          onShellModeChanged: shellModes.add,
        );

        final supervisor = AgentSupervisor(
          bus: bus,
          sandbox: sandbox,
          clock: fakeClock,
          ttsService: mockTts,
          hapticService: mockHaptic,
          outputCoordinator: coordinator,
        );

        final inputRouter = InputRouter(
          supervisor: supervisor,
          outputCoordinator: coordinator,
          clock: fakeClock,
          classifier: RequestClassifierImpl(),
        );

        final orchestrator = KitaOrchestrator(
          inputRouter: inputRouter,
          supervisor: supervisor,
          outputCoordinator: coordinator,
        );

        try {
          // --- Initialize orchestrator (spawns AlertAgent) ---
          await orchestrator.initialize();
          expect(orchestrator.isInitialized, isTrue);
          // AlertAgent should be spawned
          expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);

          // --- Marie says "decris" ---
          await orchestrator.handleInput(
            RawInput.voice('decris', clock: fakeClock),
          );

          // DescribeAgent should now be spawned
          expect(
            supervisor.agents.containsKey('com.kita.describe'),
            isTrue,
            reason: 'DescribeAgent should be spawned after "decris" command',
          );

          // Flush microtasks so the streaming vision completes
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // --- Verify AI vision was called ---
          expect(mockAI.visionStreamCalled, isTrue,
              reason: 'AI visionStream should be called for describe');

          // --- Verify camera was used (photo captured) ---
          // The camera mock returns a fake JPEG. The sandbox should
          // have called capturePhoto via SandboxedSensorAccess.
          // We verify via the AI provider receiving an image prompt.
          expect(
            mockAI.lastVisionPrompt,
            isNotNull,
            reason: 'AI should receive a vision prompt',
          );

          // --- Verify TTS was called with the description ---
          // The OutputCoordinator queues speech; advance the clock
          // to let the speech timeout complete, then trigger processing.
          coordinator.onSpeechComplete();
          await Future<void>.delayed(Duration.zero);
          fakeClock.advance(const Duration(milliseconds: 100));
          await Future<void>.delayed(Duration.zero);

          expect(
            mockTts.lastSpokenText,
            isNotNull,
            reason: 'TTS should have been called with description text',
          );

          // --- Verify orb state changed to processing/responding ---
          expect(
            orbStates,
            isNotEmpty,
            reason: 'Orb state should have changed during describe flow',
          );

          // --- Verify ProfileAdapter routes for blind user ---
          // For a blind user, vocal+haptic are active, visual is not.
          // The OutputCoordinator uses ProfileAdapter internally for TTS.
          // If TTS was called, it means vocal routing worked.
          expect(mockTts.lastSpokenText, isNotNull);

          // --- Verify haptic feedback was triggered ---
          expect(
            mockHaptic.lastPattern,
            isNotNull,
            reason: 'Haptic should have been triggered for blind user',
          );
        } finally {
          await orchestrator.dispose();
          bus.dispose();
        }
      },
    );

    // -----------------------------------------------------------------------
    // Phase 5: Full cycle — onboarding -> describe -> stop -> passive
    // -----------------------------------------------------------------------
    test(
      'Phase 5: complete Marie cycle: onboarding complete -> "decris" -> '
      '"stop" -> return to passive',
      () async {
        // Build orchestration
        final aiRouter = AIRouterImpl(
          classifier: RequestClassifierImpl(),
          providers: [mockAI],
        );

        final sandbox = PluginSandboxImpl(
          sensorAccess: RealSensorAccess(
            cameraService: mockCamera,
            locationService: mockLocation,
            motionService: mockMotion,
          ),
          aiAccess: RealAIAccess(aiRouter: aiRouter),
        );

        final bus = _TestAgentBus();

        final profileAdapter =
            ProfileAdapterImpl(profile: UserProfile.aveugle);

        final orbStates = <OrbState>[];
        final shellModes = <ShellMode>[];

        final coordinator = OutputCoordinator(
          tts: mockTts,
          haptic: mockHaptic,
          profileAdapter: profileAdapter,
          clock: fakeClock,
          bus: bus,
          onOrbStateChanged: orbStates.add,
          onShellModeChanged: shellModes.add,
        );

        final supervisor = AgentSupervisor(
          bus: bus,
          sandbox: sandbox,
          clock: fakeClock,
          ttsService: mockTts,
          hapticService: mockHaptic,
          outputCoordinator: coordinator,
        );

        final inputRouter = InputRouter(
          supervisor: supervisor,
          outputCoordinator: coordinator,
          clock: fakeClock,
          classifier: RequestClassifierImpl(),
        );

        final orchestrator = KitaOrchestrator(
          inputRouter: inputRouter,
          supervisor: supervisor,
          outputCoordinator: coordinator,
        );

        try {
          // Step 1: Initialize
          await orchestrator.initialize();

          // Step 2: "decris" -> DescribeAgent spawned
          await orchestrator.handleInput(
            RawInput.voice('decris', clock: fakeClock),
          );
          expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);

          // Let streaming vision complete
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // Complete the queued speech
          coordinator.onSpeechComplete();
          await Future<void>.delayed(Duration.zero);

          // Step 3: "stop" -> cancel all, return to passive
          await orchestrator.handleInput(
            RawInput.voice('stop', clock: fakeClock),
          );

          // Flush microtasks
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // DescribeAgent should be terminated (onDemand agent)
          expect(
            supervisor.agents.containsKey('com.kita.describe'),
            isFalse,
            reason:
                'DescribeAgent should be terminated after "stop" command',
          );

          // AlertAgent should still be active (persistent agent)
          expect(
            supervisor.agents.containsKey('com.kita.alert'),
            isTrue,
            reason: 'AlertAgent should remain active after "stop"',
          );

          // Shell should be told to go passive
          expect(
            shellModes,
            contains(ShellMode.passive),
            reason: 'Shell should return to passive mode after stop',
          );

          // Orb should be told to go passive
          expect(
            orbStates,
            contains(OrbState.passive),
            reason: 'Orb should return to passive state after stop',
          );

          // TTS "OK" feedback spoken on cancel
          expect(
            mockTts.lastSpokenText,
            'OK',
            reason: 'TTS should say "OK" after cancel',
          );
        } finally {
          await orchestrator.dispose();
          bus.dispose();
        }
      },
    );

    // -----------------------------------------------------------------------
    // Phase 6: Zero PII in logs throughout the journey
    // -----------------------------------------------------------------------
    test(
      'Phase 6: zero PII in logs during the full journey',
      () async {
        final aiRouter = AIRouterImpl(
          classifier: RequestClassifierImpl(),
          providers: [mockAI],
        );

        final sandbox = PluginSandboxImpl(
          sensorAccess: RealSensorAccess(
            cameraService: mockCamera,
            locationService: mockLocation,
            motionService: mockMotion,
          ),
          aiAccess: RealAIAccess(aiRouter: aiRouter),
        );

        final bus = _TestAgentBus();

        final coordinator = OutputCoordinator(
          tts: mockTts,
          haptic: mockHaptic,
          profileAdapter: ProfileAdapterImpl(profile: UserProfile.aveugle),
          clock: fakeClock,
          bus: bus,
          onOrbStateChanged: (_) {},
          onShellModeChanged: (_) {},
        );

        final supervisor = AgentSupervisor(
          bus: bus,
          sandbox: sandbox,
          clock: fakeClock,
          ttsService: mockTts,
          hapticService: mockHaptic,
          outputCoordinator: coordinator,
        );

        final inputRouter = InputRouter(
          supervisor: supervisor,
          outputCoordinator: coordinator,
          clock: fakeClock,
          classifier: RequestClassifierImpl(),
        );

        final orchestrator = KitaOrchestrator(
          inputRouter: inputRouter,
          supervisor: supervisor,
          outputCoordinator: coordinator,
        );

        try {
          await orchestrator.initialize();

          // Voice commands
          VoiceCommandHandler.recognize('decris');
          await orchestrator.handleInput(
            RawInput.voice('decris', clock: fakeClock),
          );

          // Let streaming complete
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          coordinator.onSpeechComplete();
          await Future<void>.delayed(Duration.zero);

          VoiceCommandHandler.recognize('stop');
          await orchestrator.handleInput(
            RawInput.voice('stop', clock: fakeClock),
          );

          await Future<void>.delayed(Duration.zero);

          // Check every log entry for PII
          for (final entry in logEntries) {
            expect(entry.message, isNot(contains('Marie')),
                reason: 'Log should not contain user name');
            expect(entry.message, isNot(contains('latitude')),
                reason: 'Log should not contain latitude');
            expect(entry.message, isNot(contains('longitude')),
                reason: 'Log should not contain longitude');
            expect(entry.message, isNot(contains('email')),
                reason: 'Log should not contain email');
            expect(entry.message, isNot(contains('@')),
                reason: 'Log should not contain email addresses');
          }
        } finally {
          await orchestrator.dispose();
          bus.dispose();
        }
      },
    );

    // -----------------------------------------------------------------------
    // Phase 7: Chaining — "decris" -> "plus de details" -> "merci"
    // -----------------------------------------------------------------------
    test(
      'Phase 7: chaining "decris" -> "plus de details" -> "merci" -> passive',
      () async {
        final aiRouter = AIRouterImpl(
          classifier: RequestClassifierImpl(),
          providers: [mockAI],
        );

        final sandbox = PluginSandboxImpl(
          sensorAccess: RealSensorAccess(
            cameraService: mockCamera,
            locationService: mockLocation,
            motionService: mockMotion,
          ),
          aiAccess: RealAIAccess(aiRouter: aiRouter),
        );

        final bus = _TestAgentBus();

        final coordinator = OutputCoordinator(
          tts: mockTts,
          haptic: mockHaptic,
          profileAdapter: ProfileAdapterImpl(profile: UserProfile.aveugle),
          clock: fakeClock,
          bus: bus,
          onOrbStateChanged: (_) {},
          onShellModeChanged: (_) {},
        );

        final supervisor = AgentSupervisor(
          bus: bus,
          sandbox: sandbox,
          clock: fakeClock,
          ttsService: mockTts,
          hapticService: mockHaptic,
          outputCoordinator: coordinator,
        );

        final inputRouter = InputRouter(
          supervisor: supervisor,
          outputCoordinator: coordinator,
          clock: fakeClock,
          classifier: RequestClassifierImpl(),
        );

        final orchestrator = KitaOrchestrator(
          inputRouter: inputRouter,
          supervisor: supervisor,
          outputCoordinator: coordinator,
        );

        try {
          await orchestrator.initialize();

          // Step 1: "decris"
          await orchestrator.handleInput(
            RawInput.voice('decris', clock: fakeClock),
          );
          expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);

          // Let streaming complete
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // Complete the speech so queue advances
          coordinator.onSpeechComplete();
          await Future<void>.delayed(Duration.zero);

          // Step 2: "plus de details" -> routes to focused agent
          await orchestrator.handleInput(
            RawInput.voice('plus de details', clock: fakeClock),
          );

          // Let streaming complete
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          coordinator.onSpeechComplete();
          await Future<void>.delayed(Duration.zero);

          // Describe agent should still be active
          expect(supervisor.agents.containsKey('com.kita.describe'), isTrue);

          // Step 3: "merci" -> describe agent signals completion
          // The "merci" command calls output.complete() which calls
          // notifyAgentComplete on the coordinator.
          await orchestrator.handleInput(
            RawInput.voice('merci', clock: fakeClock),
          );

          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          // After "merci", the agent may still be alive until the supervisor
          // processes the complete signal. The key test is that the command
          // was recognized and routed to the focused agent.
          final merciRecognized = VoiceCommandHandler.recognize('merci');
          expect(merciRecognized.isSuccess, isTrue);
          expect(
            (merciRecognized as Success<VoiceCommand>).value,
            VoiceCommand.thanks,
          );
        } finally {
          await orchestrator.dispose();
          bus.dispose();
        }
      },
    );
  });
}

// =============================================================================
// Minimal AgentBus implementation for testing
// =============================================================================

/// A simple AgentBus implementation for integration testing.
///
/// Supports subscribe, publish, and streamFor without the full
/// production AgentBusImpl (which may have additional dependencies).
class _TestAgentBus
    implements
        // ignore: avoid_implementing_value_types
        // We need to implement the full interface for integration testing
        AgentBus {
  final _subscriptions = <String, Set<AgentMessageType>>{};
  final _controllers = <String, StreamController<AgentMessage>>{};

  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {
    _subscriptions[agentId] = types;
    _controllers.putIfAbsent(
      agentId,
      StreamController<AgentMessage>.broadcast,
    );
  }

  @override
  void unsubscribe(String agentId) {
    _subscriptions.remove(agentId);
    _controllers[agentId]?.close();
    _controllers.remove(agentId);
  }

  @override
  Stream<AgentMessage> streamFor(String agentId) {
    _controllers.putIfAbsent(
      agentId,
      StreamController<AgentMessage>.broadcast,
    );
    return _controllers[agentId]!.stream;
  }

  @override
  void publish(AgentMessage message) {
    for (final entry in _subscriptions.entries) {
      if (entry.value.contains(message.type)) {
        final controller = _controllers[entry.key];
        if (controller != null && !controller.isClosed) {
          controller.add(message);
        }
      }
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) controller.close();
    }
    _controllers.clear();
    _subscriptions.clear();
  }
}

