import 'package:flutter/widgets.dart';

import '../../../core/errors/result.dart';
import '../../plugins/domain/ai_access.dart';
import '../../plugins/domain/memory_access.dart';
import '../../plugins/domain/sensor_access.dart';
import '../../plugins/domain/voice_command.dart';
import 'agent_bus.dart';
import 'clock.dart';
import 'models/agent_input.dart';
import 'models/agent_manifest.dart';
import 'models/agent_message.dart';
import 'models/agent_output.dart';
import 'output_handle.dart';

/// The sandboxed context injected into each agent at spawn time.
///
/// Contains all the tools an agent needs: sensor access, AI access,
/// optional memory, the inter-agent bus, output handle, and clock.
/// Built by the [AgentSupervisor] based on the agent's manifest permissions.
class AgentContext {
  /// Creates an [AgentContext].
  const AgentContext({
    required this.sensors,
    required this.ai,
    required this.bus,
    required this.output,
    required this.clock,
    this.memory,
  });

  /// Sandboxed access to device sensors (camera, GPS, motion).
  final SensorAccess sensors;

  /// Sandboxed access to AI providers (text, vision).
  final AIAccess ai;

  /// Sandboxed access to persistent memory.
  /// Null if the agent does not have memory permission.
  final MemoryAccess? memory;

  /// The inter-agent communication bus.
  final AgentBus bus;

  /// Handle for producing output (speech, haptic, viewport).
  final OutputHandle output;

  /// Injectable clock for timers and time queries.
  final Clock clock;
}

/// The core interface for all Kita agents.
///
/// Replaces the former [KitaPlugin] interface. Every module that wants
/// to participate in the Kita multi-agent system implements [KitaAgent].
///
/// Agents communicate exclusively through typed messages on the [AgentBus]
/// and produce output through their [OutputHandle]. They never call
/// TTS or HapticService directly.
///
/// ## Lifecycle
///
/// 1. [onSpawn] -- called by the Supervisor with a sandboxed [AgentContext]
/// 2. [handleInput] -- called by the InputRouter when input is routed here
/// 3. [onBusMessage] -- called when a subscribed bus message arrives
/// 4. [onSuspend] / [onResume] -- for battery optimization (persistent agents)
/// 5. [onTerminate] -- called for clean shutdown, release resources
abstract class KitaAgent {
  /// The manifest describing this agent's identity and capabilities.
  AgentManifest get manifest;

  /// Voice commands this agent recognizes.
  List<VoiceCommand> get voiceCommands;

  // === Lifecycle ===

  /// Called when the Supervisor spawns this agent.
  ///
  /// The [context] provides sandboxed access to sensors, AI, memory,
  /// the bus, output handle, and clock. Store it for later use.
  Future<void> onSpawn(AgentContext context);

  /// Called when the agent is suspended (battery saving, backgrounding).
  Future<void> onSuspend();

  /// Called when the agent resumes after suspension.
  Future<void> onResume();

  /// Called for clean shutdown. Release all resources, cancel timers.
  Future<void> onTerminate();

  // === Communication ===

  /// Handles an input routed by the InputRouter.
  ///
  /// Returns a [Result] containing the [AgentOutput] on success,
  /// or a [KitaFailure] on error. Never throws untyped exceptions.
  Future<Result<AgentOutput>> handleInput(AgentInput input);

  /// Called when a message from the bus arrives.
  ///
  /// Only messages whose [AgentMessageType] is in the agent's
  /// [AgentManifest.subscriptions] are delivered here.
  ///
  /// Default implementation is a no-op. Override to handle bus messages.
  // ignore: no-op
  void onBusMessage(AgentMessage message) {}

  // === UI ===

  /// Returns the widget for this agent's viewport in the Shell.
  ///
  /// Return null if this agent has no visual component.
  Widget? buildViewport(BuildContext context);
}
