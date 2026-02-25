import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/request_classifier.dart';
import '../../io/data/voice_command_handler.dart';
import '../../plugins/built_in/describe/describe_plugin.dart';
import '../domain/agent_bus.dart';
import '../domain/clock.dart';
import '../domain/models/agent_input.dart';
import '../domain/models/agent_message.dart';
import '../domain/models/raw_input.dart';
import 'agent_supervisor.dart';
import 'output_coordinator.dart';

/// Classifies and routes raw user/sensor inputs to the appropriate agent.
///
/// Routing logic (in order of priority):
/// 1. "stop" / "annule" -> cancelAll broadcast + coordinator.cancelAll() + feedback "OK"
/// 2. "decris" / "describe" -> spawn DescribeAgent (or re-route if already active)
/// 3. sensor data -> route to AlertAgent.handleInput()
/// 4. "plus de details" / "repete" / "merci" -> route to focused agent
/// 5. Unknown command -> route to fallback (RequestClassifier + AIRouter)
class InputRouter {
  InputRouter({
    required AgentSupervisor supervisor,
    required AgentBus bus,
    required OutputCoordinator outputCoordinator,
    required Clock clock,
    RequestClassifier? classifier,
  })  : _supervisor = supervisor,
        _bus = bus,
        _outputCoordinator = outputCoordinator,
        _clock = clock,
        _classifier = classifier;

  static final _log = KitaLogger('Orchestration.Router');

  final AgentSupervisor _supervisor;
  final AgentBus _bus;
  final OutputCoordinator _outputCoordinator;
  final Clock _clock;
  final RequestClassifier? _classifier;

  /// Routes a [RawInput] to the appropriate handler or agent.
  ///
  /// This is the main entry point for all inputs. Classification happens
  /// in this order:
  /// 1. Sensor inputs -> AlertAgent directly
  /// 2. Voice/text -> VoiceCommandHandler for known commands
  /// 3. Unrecognized -> RequestClassifier for priority, then fallback
  Future<void> route(RawInput input) async {
    // 1. Sensor input -> route directly to AlertAgent
    if (input.source == InputSource.sensor) {
      _log.info('Routing sensor input to AlertAgent');
      return _routeToAlertAgent(input);
    }

    // 2. Voice/text input -> try VoiceCommandHandler first
    final transcript = input.transcript ?? '';
    if (transcript.isEmpty) {
      _log.debug('Empty transcript, ignoring');
      return;
    }

    final cmdResult = VoiceCommandHandler.recognize(transcript);
    switch (cmdResult) {
      case Success(value: VoiceCommand.stop):
        _log.info('Voice command: stop');
        return _handleCancel();

      case Success(value: VoiceCommand.describe):
        _log.info('Voice command: describe');
        return _handleDescribe();

      case Success(value: VoiceCommand.moreDetails):
        _log.info('Voice command: more details');
        return _routeToFocusAgent(input, 'plus de details');

      case Success(value: VoiceCommand.repeat):
        _log.info('Voice command: repeat');
        return _routeToFocusAgent(input, 'repete');

      case Success(value: VoiceCommand.thanks):
        _log.info('Voice command: thanks');
        return _routeToFocusAgent(input, 'merci');

      case Success(value: VoiceCommand.help):
        _log.info('Voice command: help -> fallback');
        return _routeToFallback(transcript);

      case Success(value: VoiceCommand.read):
        _log.info('Voice command: read -> fallback');
        return _routeToFallback(transcript);

      case Failure():
        // Not a known command -> use RequestClassifier then fallback
        _log.debug('No voice command match, routing to fallback');
        return _routeToFallback(transcript);
    }
  }

  /// Handles "stop" / "annule": broadcast cancelAll then coordinator.cancelAll.
  ///
  /// **Sequence is critical** (see Pitfalls #2 in story file):
  /// 1. bus.publish(cancelAll) — agents receive and start cleanup
  /// 2. outputCoordinator.cancelAll() — stops TTS, clears queue
  /// 3. feedback "OK" is handled by the coordinator's cancelAll
  Future<void> _handleCancel() async {
    // Step 1: Broadcast cancelAll on the bus FIRST
    _bus.publish(AgentMessage(
      fromAgent: 'system',
      type: AgentMessageType.cancelAll,
      payload: const {},
      timestamp: _clock.now(),
    ));

    // Step 2: Coordinator stops TTS + clears queue + feedback "OK"
    await _outputCoordinator.cancelAll();

    // Step 3: Terminate onDemand agents
    await _supervisor.returnToPassive();

    _log.info('Cancel all completed');
  }

  /// Handles "decris": spawn DescribeAgent or re-route if already active.
  ///
  /// **Pitfall #1**: If Marie says "decris" while DescribeAgent is already
  /// active, we re-route to the existing agent instead of double-spawning.
  Future<void> _handleDescribe() async {
    const describeId = 'com.kita.describe';

    if (_supervisor.agents.containsKey(describeId)) {
      // Re-route to existing active agent
      _log.info('DescribeAgent already active, re-routing command');
      final agent = _supervisor.agents[describeId]!.agent;
      await agent.handleInput(AgentInput(
        command: 'decris',
        params: const {},
        source: InputSource.voice,
        timestamp: _clock.now(),
      ));
    } else {
      // Spawn new DescribeAgent
      _log.info('Spawning new DescribeAgent');
      final result = await _supervisor.spawn(KitaDescribePlugin());
      switch (result) {
        case Success():
          // Send the initial describe command
          final agent = _supervisor.agents[describeId]?.agent;
          if (agent != null) {
            await agent.handleInput(AgentInput(
              command: 'decris',
              params: const {},
              source: InputSource.voice,
              timestamp: _clock.now(),
            ));
          }
        case Failure(:final failure):
          _log.error('Failed to spawn DescribeAgent: ${failure.logMessage}');
      }
    }
  }

  /// Routes sensor data to the AlertAgent.
  ///
  /// AlertAgent is always active (persistent), so no spawn needed.
  Future<void> _routeToAlertAgent(RawInput input) async {
    const alertId = 'com.kita.alert';
    final entry = _supervisor.agents[alertId];
    if (entry != null) {
      await entry.agent.handleInput(AgentInput(
        command: 'obstacle_detected',
        params: input.sensorData ?? {},
        source: InputSource.sensor,
        timestamp: input.timestamp,
      ));
    } else {
      _log.warning('AlertAgent not active, cannot route sensor input');
    }
  }

  /// Routes a command to the agent currently at focus (last to have spoken).
  Future<void> _routeToFocusAgent(RawInput input, String command) async {
    final focusedId = _outputCoordinator.focusedAgentId;
    if (focusedId != null) {
      final entry = _supervisor.agents[focusedId];
      if (entry != null) {
        _log.info('Routing "$command" to focused agent $focusedId');
        await entry.agent.handleInput(AgentInput(
          command: command,
          params: const {},
          source: input.source,
          timestamp: input.timestamp,
        ));
        return;
      }
    }
    _log.debug('No focused agent, routing "$command" to fallback');
    await _routeToFallback(input.transcript ?? command);
  }

  /// Routes to the AI fallback (conversation generale).
  ///
  /// Uses [RequestClassifier] to determine priority, then delegates
  /// to AIRouter for general conversation. For the MVP, this logs
  /// and provides minimal feedback.
  Future<void> _routeToFallback(String transcript) async {
    if (_classifier != null) {
      final priority = _classifier.classify(transcript);
      _log.debug('Fallback: classified as ${priority.getOrNull()?.name}');
    }
    // For MVP: log the unrecognized command.
    // Future: route to AIRouter for general conversation.
    _log.info('Fallback: unrecognized command, no action taken');
  }
}
