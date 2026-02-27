import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/ai_router_impl.dart';
import '../../ai/data/providers/gemma_bridge.dart';
import '../../ai/data/providers/local_provider.dart';
import '../../ai/data/request_classifier_impl.dart';
import '../../ai/domain/ai_router.dart';
import '../../ai/domain/request_classifier.dart';
import '../../io/data/providers/camera_providers.dart';
import '../../io/data/providers/haptic_providers.dart';
import '../../io/data/providers/location_providers.dart';
import '../../io/data/providers/motion_providers.dart';
import '../../io/data/providers/tts_providers.dart';
import '../../io/domain/speech_event.dart';
import '../../plugins/data/plugin_sandbox_impl.dart';
import '../../shell/di/orb_providers.dart';
import '../../shell/di/shell_mode_providers.dart';
import '../../shell/domain/orb_state.dart';
import '../../shell/domain/shell_mode.dart';
import '../../../shared/multi_modal/profile_adapter_provider.dart';
import '../data/agent_bus_impl.dart';
import '../data/agent_supervisor.dart';
import '../data/input_router.dart';
import '../data/kita_orchestrator.dart';
import '../data/output_coordinator.dart';
import '../data/real_access.dart';
import '../domain/agent_bus.dart';
import '../domain/clock.dart';
import '../data/conversation_engine.dart';
import '../domain/conversation_engine.dart';
import '../domain/models/agent_manifest.dart';

// =============================================================================
// Orchestration providers — all keepAlive: true
//
// These are the core providers for the orchestration system.
// They are created as manual providers (not code-gen) because they need
// keepAlive behavior and cross-feature dependencies that are simpler
// to manage without code generation.
// =============================================================================

/// Injectable [Clock]. Override in tests with [FakeClock].
final clockProvider = Provider<Clock>((ref) {
  return SystemClock();
});

/// The [AgentBus] for inter-agent communication.
///
/// keepAlive — persists for the entire app lifecycle.
final agentBusProvider = Provider<AgentBus>((ref) {
  final bus = AgentBusImpl();
  ref.onDispose(bus.dispose);
  return bus;
});

/// The [GemmaBridge] for on-device LLM inference.
///
/// Provides text completion and vision via Gemma3n E2B bundled model.
final gemmaBridgeProvider = Provider<GemmaBridge>((ref) {
  final bridge = GemmaBridgeImpl();
  // Fire-and-forget warmup: loads model + runs dummy inference so
  // subsequent real calls skip GPU pipeline compilation (~4s saved).
  unawaited(bridge.warmUp());
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// The [AIRouter] for routing AI requests through the fallback chain.
///
/// Starts with [LocalProvider] (always available, works offline).
/// Gemma provides LLM text + vision; ML Kit provides OCR + label fallback.
/// Cloud providers (Claude, OpenAI) are added when API keys are configured.
final aiRouterProvider = Provider<AIRouter>((ref) {
  final classifier = ref.watch(requestClassifierProvider);
  final gemmaBridge = ref.watch(gemmaBridgeProvider);
  return AIRouterImpl(
    classifier: classifier,
    providers: [LocalProvider(gemmaBridge: gemmaBridge)],
  );
});

/// The [PluginSandboxImpl] for building sandboxed [AgentContext]s.
///
/// Wired to real sensor services (camera, location, motion) and
/// the AI router for full plugin functionality.
final pluginSandboxProvider = Provider<PluginSandboxImpl>((ref) {
  final camera = ref.watch(cameraServiceProvider);
  final location = ref.watch(locationServiceProvider);
  final motion = ref.watch(motionServiceProvider);
  final aiRouter = ref.watch(aiRouterProvider);

  return PluginSandboxImpl(
    sensorAccess: RealSensorAccess(
      cameraService: camera,
      locationService: location,
      motionService: motion,
    ),
    aiAccess: RealAIAccess(aiRouter: aiRouter),
  );
});

/// The [AgentSupervisor] for agent lifecycle management.
///
/// keepAlive — persists for the entire app lifecycle.
final agentSupervisorProvider = Provider<AgentSupervisor>((ref) {
  final bus = ref.watch(agentBusProvider);
  final sandbox = ref.watch(pluginSandboxProvider);
  final clock = ref.watch(clockProvider);
  final tts = ref.watch(ttsServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final supervisor = AgentSupervisor(
    bus: bus,
    sandbox: sandbox,
    clock: clock,
    ttsService: tts,
    hapticService: haptic,
    outputCoordinator: coordinator,
  );
  ref.onDispose(() async {
    await supervisor.dispose();
  });
  return supervisor;
});

/// The [OutputCoordinator] for output arbitration.
///
/// keepAlive — persists for the entire app lifecycle.
/// Bridges shell state changes via Riverpod notifiers.
final outputCoordinatorProvider = Provider<OutputCoordinator>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final adapter = ref.watch(profileAdapterProvider);
  final clock = ref.watch(clockProvider);
  final bus = ref.watch(agentBusProvider);

  final coordinator = OutputCoordinator(
    tts: tts,
    haptic: haptic,
    profileAdapter: adapter,
    clock: clock,
    bus: bus,
    onOrbStateChanged: (OrbState state) {
      // Bridge to OrbStateNotifier via ref.read
      // This is called from the coordinator's internal logic
      ref.read(orbStateProvider.notifier).setState(state);
    },
    onShellModeChanged: (ShellMode mode) {
      // Bridge to ShellModeNotifier via ref.read
      ref.read(shellModeProvider.notifier).setMode(mode);
    },
  );

  // Bridge TTS speech events to the OutputCoordinator so it can advance
  // its queue when speech completes. Without this, the coordinator's
  // _speechCompleter is never completed by real TTS events and falls
  // back to the 30-second timeout, making the app feel unresponsive.
  final speechSub = tts.speechEvents.listen((event) {
    switch (event.type) {
      case TtsSpeechEventType.started:
        coordinator.onSpeechStart();
      case TtsSpeechEventType.completed:
        coordinator.onSpeechComplete();
      case TtsSpeechEventType.interrupted:
        coordinator.onSpeechCancelled();
    }
  });

  ref.onDispose(() {
    speechSub.cancel();
    coordinator.dispose();
  });
  return coordinator;
});

/// The [RequestClassifier] for fallback routing.
final requestClassifierProvider = Provider<RequestClassifier>((ref) {
  return RequestClassifierImpl();
});

/// The [ConversationEngine] for LLM-based conversational routing.
///
/// Uses [ConversationEngineImpl] which implements the tool-use loop:
/// user message -> LLM -> (tool call -> execute -> feed back) -> response.
///
/// When the LLM is unavailable (no providers), [isReady] returns false
/// and [InputRouter] falls back to VoiceCommandHandler pattern matching.
final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  final aiRouter = ref.watch(aiRouterProvider);
  final supervisor = ref.watch(agentSupervisorProvider);
  final clock = ref.watch(clockProvider);
  final engine = ConversationEngineImpl(
    aiRouter: aiRouter,
    supervisor: supervisor,
    clock: clock,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// The [InputRouter] for input classification and routing.
///
/// keepAlive — persists for the entire app lifecycle.
/// Injects [ConversationEngine] when available for LLM-based routing,
/// with automatic fallback to VoiceCommandHandler pattern matching.
final inputRouterProvider = Provider<InputRouter>((ref) {
  final supervisor = ref.watch(agentSupervisorProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final clock = ref.watch(clockProvider);
  final classifier = ref.watch(requestClassifierProvider);
  final conversationEngine = ref.watch(conversationEngineProvider);
  return InputRouter(
    supervisor: supervisor,
    outputCoordinator: coordinator,
    clock: clock,
    classifier: classifier,
    conversationEngine: conversationEngine,
  );
});

/// The [KitaOrchestrator] facade — single entry point for the Shell.
///
/// keepAlive — persists for the entire app lifecycle.
final kitaOrchestratorProvider = Provider<KitaOrchestrator>((ref) {
  final router = ref.watch(inputRouterProvider);
  final supervisor = ref.watch(agentSupervisorProvider);
  final coordinator = ref.watch(outputCoordinatorProvider);
  final orchestrator = KitaOrchestrator(
    inputRouter: router,
    supervisor: supervisor,
    outputCoordinator: coordinator,
  );
  ref.onDispose(() async {
    await orchestrator.dispose();
  });
  return orchestrator;
});

// =============================================================================
// Derived providers for Shell wiring
// =============================================================================

/// Whether any onDemand agent is currently active.
///
/// Used by the Shell to toggle between passive/active mode.
/// Only changes value when the boolean flips (not on every agent change),
/// preventing excessive Shell rebuilds (Pitfall #5).
final hasActiveOnDemandProvider = Provider<bool>((ref) {
  final supervisor = ref.watch(agentSupervisorProvider);
  return supervisor.agents.values.any(
    (e) =>
        e.agent.manifest.agentType == AgentType.onDemand &&
        e.state == AgentState.active,
  );
});

/// The widget from the currently focused agent's viewport.
///
/// Returns null if no agent has focus or the focused agent has no viewport.
/// Used by [PluginViewport] in the Shell.
// Note: This provider is intentionally simple for MVP. It returns null
// because viewport management requires BuildContext which is not available
// in a pure Riverpod provider. The Shell widget handles this directly.
