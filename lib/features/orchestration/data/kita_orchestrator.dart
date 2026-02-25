import '../../../core/utils/logger.dart';
import '../../plugins/built_in/alert/kita_alert_plugin.dart';
import '../domain/models/raw_input.dart';
import 'agent_supervisor.dart';
import 'input_router.dart';
import 'output_coordinator.dart';

/// Facade providing a single entry point for the Shell to interact
/// with the orchestration system.
///
/// The KitaOrchestrator owns no logic itself. It delegates:
/// - Input handling to [InputRouter]
/// - Agent lifecycle to [AgentSupervisor]
/// - Output arbitration to [OutputCoordinator]
///
/// ## Lifecycle
///
/// 1. [initialize] — called after onboarding, spawns persistent agents
/// 2. [handleInput] — called for every user/sensor input
/// 3. [dispose] — called on app shutdown or reset
class KitaOrchestrator {
  KitaOrchestrator({
    required InputRouter inputRouter,
    required AgentSupervisor supervisor,
    required OutputCoordinator outputCoordinator,
  })  : _inputRouter = inputRouter,
        _supervisor = supervisor,
        _outputCoordinator = outputCoordinator;

  static final _log = KitaLogger('Orchestration');

  final InputRouter _inputRouter;
  final AgentSupervisor _supervisor;
  final OutputCoordinator _outputCoordinator;

  bool _initialized = false;

  /// Whether the orchestrator has been initialized.
  bool get isInitialized => _initialized;

  /// The supervisor, exposed for Shell state observation.
  AgentSupervisor get supervisor => _supervisor;

  /// The output coordinator, exposed for Shell state observation.
  OutputCoordinator get outputCoordinator => _outputCoordinator;

  /// Main entry point for all inputs. Delegates to [InputRouter.route].
  Future<void> handleInput(RawInput input) async {
    _log.info('Handling input: ${input.source.name}');
    await _inputRouter.route(input);
  }

  /// Initializes the orchestrator after onboarding.
  ///
  /// Spawns persistent agents (AlertAgent). This method is idempotent:
  /// calling it multiple times has no effect after the first call.
  Future<void> initialize() async {
    if (_initialized) {
      _log.debug('Already initialized, skipping');
      return;
    }

    _log.info('Initializing orchestrator');

    // Spawn persistent agents
    final result = await _supervisor.spawn(KitaAlertPlugin());
    result.when(
      success: (_) {
        _log.info('AlertAgent spawned successfully');
      },
      failure: (failure) {
        _log.error('Failed to spawn AlertAgent: ${failure.logMessage}');
      },
    );

    _initialized = true;
    _log.info('Orchestrator initialized');
  }

  /// Disposes the orchestrator and terminates all agents.
  ///
  /// **Order is critical** (Pitfall #6 in story file):
  /// 1. Terminate onDemand agents first (via returnToPassive)
  /// 2. Terminate persistent agents
  /// 3. Dispose coordinator (stops TTS)
  ///
  /// The bus is NOT disposed here — it is owned by its own provider.
  Future<void> dispose() async {
    _log.info('Disposing orchestrator');

    // Step 1: Terminate onDemand agents
    await _supervisor.returnToPassive();

    // Step 2: Terminate persistent agents
    final persistentIds = _supervisor.agents.keys.toList();
    for (final id in persistentIds) {
      await _supervisor.terminate(id);
    }

    // Step 3: Dispose coordinator
    _outputCoordinator.dispose();

    _initialized = false;
    _log.info('Orchestrator disposed');
  }
}
