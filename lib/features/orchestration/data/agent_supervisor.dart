import 'dart:async';

import '../../../core/constants/limits.dart';
import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../io/domain/haptic_service.dart';
import '../../io/domain/tts_service.dart';
import '../../plugins/data/plugin_sandbox_impl.dart';
import '../domain/agent_bus.dart';
import '../domain/clock.dart';
import '../domain/kita_agent.dart';
import '../domain/models/agent_ids.dart';
import '../domain/models/agent_manifest.dart';
import '../domain/models/agent_message.dart';
import 'output_coordinator.dart';
import 'output_handle_impl.dart';
import 'output_handle_stub.dart';

/// State of an agent managed by the [AgentSupervisor].
enum AgentState {
  /// Agent is running normally.
  active,

  /// Agent is suspended (e.g., battery saving).
  suspended,
}

/// Entry in the supervisor's agent registry.
class AgentEntry {
  const AgentEntry({
    required this.agent,
    required this.state,
    required this.context,
  });

  /// The agent instance.
  final KitaAgent agent;

  /// Current state of the agent.
  final AgentState state;

  /// The agent's context, for reference.
  final AgentContext context;

  /// Convenience accessor for the agent's ID.
  String get id => agent.manifest.id;

  /// Creates a copy with updated state.
  AgentEntry copyWith({AgentState? state}) {
    return AgentEntry(
      agent: agent,
      state: state ?? this.state,
      context: context,
    );
  }
}

/// Manages the lifecycle of all agents in the Kita system.
///
/// Responsibilities:
/// - Spawn agents with sandboxed [AgentContext]
/// - Suspend, resume, and terminate agents
/// - Enforce max agent limit ([Limits.maxActivePlugins])
/// - Crash isolation: one agent crashing does not affect others
/// - [returnToPassive]: terminate onDemand agents, keep persistent ones
class AgentSupervisor {
  AgentSupervisor({
    required AgentBus bus,
    required PluginSandboxImpl sandbox,
    required Clock clock,
    required TTSService ttsService,
    required HapticService hapticService,
    OutputCoordinator? outputCoordinator,
  })  : _bus = bus,
        _sandbox = sandbox,
        _clock = clock,
        _ttsService = ttsService,
        _hapticService = hapticService,
        _outputCoordinator = outputCoordinator;

  static final _log = KitaLogger('Orchestration.Supervisor');

  final AgentBus _bus;
  final PluginSandboxImpl _sandbox;
  final Clock _clock;
  final TTSService _ttsService;
  final HapticService _hapticService;
  final OutputCoordinator? _outputCoordinator;

  final Map<String, AgentEntry> _agents = {};
  final Map<String, StreamSubscription<AgentMessage>> _busSubscriptions = {};

  /// Returns a read-only view of all managed agents.
  Map<String, AgentEntry> get agents => Map.unmodifiable(_agents);

  /// Spawns an agent: builds context, calls onSpawn, registers on bus.
  ///
  /// Returns [Result.failure] if:
  /// - Max agent limit is reached
  /// - An agent with the same ID is already active
  /// - [onSpawn] throws an exception
  Future<Result<void>> spawn(KitaAgent agent) async {
    final agentId = agent.manifest.id;

    // Check if already registered
    if (_agents.containsKey(agentId)) {
      _log.warning('Agent $agentId already active');
      return Result.failure(PluginFailure(
        userMessage: "L'agent est deja actif.",
        logMessage: 'Agent $agentId already active',
        pluginId: agentId,
      ));
    }

    // Check max agents limit
    if (_agents.length >= Limits.maxActivePlugins) {
      _log.warning(
        'Cannot spawn $agentId: max active agents reached '
        '(${_agents.length}/${Limits.maxActivePlugins})',
      );
      return Result.failure(PluginFailure(
        userMessage: "Nombre maximum d'agents actifs atteint.",
        logMessage:
            'Max active agents reached: ${_agents.length}/${Limits.maxActivePlugins}',
        pluginId: agentId,
      ));
    }

    // Build OutputHandle: use real OutputHandleImpl when coordinator is
    // available (normal runtime), fall back to StubOutputHandle (legacy/tests).
    final outputHandle = _outputCoordinator != null
        ? OutputHandleImpl(
            agentId: agentId,
            coordinator: _outputCoordinator,
            agentType: agent.manifest.agentType,
          )
        : StubOutputHandle(
            agentId: agentId,
            ttsService: _ttsService,
            hapticService: _hapticService,
            onComplete: _onAgentComplete,
          );

    // Build sandboxed AgentContext
    final context = _sandbox.buildAgentContext(
      manifest: agent.manifest,
      bus: _bus,
      output: outputHandle,
      clock: _clock,
    );

    // Subscribe on bus BEFORE onSpawn (contract from AgentBus doc)
    _bus.subscribe(agentId, agent.manifest.subscriptions);
    _busSubscriptions[agentId] =
        _bus.streamFor(agentId).listen(agent.onBusMessage);

    // Call onSpawn with crash isolation
    try {
      await agent.onSpawn(context);
    } catch (e, stack) {
      _log.error('Agent $agentId crashed during spawn',
          error: e, stackTrace: stack);
      // Cleanup: unsubscribe and remove bus subscription
      _bus.unsubscribe(agentId);
      await _busSubscriptions.remove(agentId)?.cancel();
      return Result.failure(PluginFailure(
        userMessage: "L'agent n'a pas pu demarrer.",
        logMessage: 'Agent $agentId crashed during spawn: $e',
        pluginId: agentId,
        cause: e,
        stackTrace: stack,
      ));
    }

    // Register in the map
    _agents[agentId] = AgentEntry(
      agent: agent,
      state: AgentState.active,
      context: context,
    );

    // Publish spawned event
    _bus.publish(AgentMessage(
      fromAgent: AgentIds.system,
      type: AgentMessageType.agentSpawned,
      payload: {'agentId': agentId},
      timestamp: _clock.now(),
    ));

    _log.info('Agent $agentId spawned (${agent.manifest.agentType.name})');
    return const Result.success(null);
  }

  /// Suspends an active agent.
  Future<Result<void>> suspend(String agentId) async {
    final entry = _agents[agentId];
    if (entry == null) {
      return Result.failure(PluginFailure(
        userMessage: 'Agent introuvable.',
        logMessage: 'Cannot suspend: agent $agentId not found',
        pluginId: agentId,
      ));
    }

    if (entry.state != AgentState.active) {
      _log.info('Agent $agentId not active, cannot suspend');
      return const Result.success(null);
    }

    try {
      await entry.agent.onSuspend();
    } catch (e, stack) {
      _log.error('Agent $agentId crashed during suspend',
          error: e, stackTrace: stack);
      // Still mark as suspended despite crash
    }

    _agents[agentId] = entry.copyWith(state: AgentState.suspended);
    _log.info('Agent $agentId suspended');
    return const Result.success(null);
  }

  /// Resumes a suspended agent.
  Future<Result<void>> resume(String agentId) async {
    final entry = _agents[agentId];
    if (entry == null) {
      return Result.failure(PluginFailure(
        userMessage: 'Agent introuvable.',
        logMessage: 'Cannot resume: agent $agentId not found',
        pluginId: agentId,
      ));
    }

    if (entry.state != AgentState.suspended) {
      _log.info('Agent $agentId not suspended, cannot resume');
      return const Result.success(null);
    }

    try {
      await entry.agent.onResume();
    } catch (e, stack) {
      _log.error('Agent $agentId crashed during resume',
          error: e, stackTrace: stack);
      // Still mark as active despite crash
    }

    _agents[agentId] = entry.copyWith(state: AgentState.active);
    _log.info('Agent $agentId resumed');
    return const Result.success(null);
  }

  /// Terminates an agent and removes it from the registry.
  ///
  /// Calls [onTerminate] with crash isolation: the agent is always
  /// removed from the map even if onTerminate throws.
  Future<Result<void>> terminate(String agentId) async {
    final entry = _agents[agentId];
    if (entry == null) {
      return Result.failure(PluginFailure(
        userMessage: 'Agent introuvable.',
        logMessage: 'Cannot terminate: agent $agentId not found',
        pluginId: agentId,
      ));
    }

    // Call onTerminate with crash isolation
    try {
      await entry.agent.onTerminate();
    } catch (e, stack) {
      _log.error('Agent $agentId crashed during termination',
          error: e, stackTrace: stack);
      // Still remove the agent — same as PluginRegistryImpl behavior
    }

    // Remove from registry
    _agents.remove(agentId);

    // Unsubscribe from bus
    _bus.unsubscribe(agentId);
    await _busSubscriptions.remove(agentId)?.cancel();

    // Publish terminated event
    _bus.publish(AgentMessage(
      fromAgent: AgentIds.system,
      type: AgentMessageType.agentTerminated,
      payload: {'agentId': agentId},
      timestamp: _clock.now(),
    ));

    _log.info('Agent $agentId terminated');
    return const Result.success(null);
  }

  /// Terminates all onDemand agents. Persistent agents remain active.
  ///
  /// Used when the system returns to passive mode (e.g., user says "stop").
  Future<void> returnToPassive() async {
    // Collect IDs first to avoid modifying the map during iteration.
    final onDemandIds = _agents.entries
        .where((e) => e.value.agent.manifest.agentType == AgentType.onDemand)
        .map((e) => e.key)
        .toList();

    for (final id in onDemandIds) {
      await terminate(id);
    }

    _log.info('Returned to passive mode, terminated ${onDemandIds.length} '
        'onDemand agents');
  }

  /// Callback invoked by [StubOutputHandle.complete].
  void _onAgentComplete(String agentId) {
    _log.info('Agent $agentId signaled complete');
    // Schedule termination asynchronously to avoid re-entrant issues
    unawaited(terminate(agentId).catchError((Object e) {
      _log.error('Failed to terminate agent on complete', error: e);
      return const Result<void>.success(null);
    }));
  }

  /// Terminates all agents and cleans up resources.
  Future<void> dispose() async {
    final allIds = _agents.keys.toList();
    for (final id in allIds) {
      await terminate(id);
    }
    _log.info('AgentSupervisor disposed');
  }
}
