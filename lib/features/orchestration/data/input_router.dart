import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/request_classifier.dart';
import '../../io/data/voice_command_handler.dart';
import '../../plugins/built_in/describe/describe_plugin.dart';
import '../domain/clock.dart';
import '../domain/conversation_engine.dart';
import '../domain/models/agent_input.dart';
import '../domain/models/agent_ids.dart';
import '../domain/models/output_priority.dart';
import '../domain/models/raw_input.dart';
import 'agent_supervisor.dart';
import 'kita_tools.dart';
import 'output_coordinator.dart';

/// Classifies and routes raw user/sensor inputs to the appropriate agent.
///
/// Routing logic (in order of priority):
/// 1. "stop" / "annule" -> cancelAll broadcast + coordinator.cancelAll() + feedback "OK"
///    (ALWAYS pattern-matched — safety critical, never depends on LLM)
/// 2. Sensor data -> route to AlertAgent.handleInput()
/// 3. If [ConversationEngine] is available and ready:
///    -> LLM processes input (may respond, call tools, or both)
/// 4. FALLBACK: If LLM unavailable or ConversationEngine fails:
///    -> VoiceCommandHandler pattern matching (preserves all command-based UX)
///
/// The transition from command-based to conversational is gradual:
/// users without API keys or with cold Gemma still get full command UX.
class InputRouter {
  InputRouter({
    required AgentSupervisor supervisor,
    required OutputCoordinator outputCoordinator,
    required Clock clock,
    RequestClassifier? classifier,
    ConversationEngine? conversationEngine,
  })  : _supervisor = supervisor,
        _outputCoordinator = outputCoordinator,
        _clock = clock,
        _classifier = classifier,
        _conversationEngine = conversationEngine;

  static final _log = KitaLogger('Orchestration.Router');

  final AgentSupervisor _supervisor;
  final OutputCoordinator _outputCoordinator;
  final Clock _clock;
  final RequestClassifier? _classifier;
  final ConversationEngine? _conversationEngine;

  /// Routes a [RawInput] to the appropriate handler or agent.
  ///
  /// This is the main entry point for all inputs. Classification happens
  /// in this order:
  /// 1. Sensor inputs -> AlertAgent directly
  /// 2. Critical safety commands ("stop") -> always pattern-matched
  /// 3. ConversationEngine (if available) -> LLM-based routing
  /// 4. VoiceCommandHandler fallback -> pattern matching
  Future<void> route(RawInput input) async {
    // 1. Sensor input -> route directly to AlertAgent
    if (input.source == InputSource.sensor) {
      _log.info('Routing sensor input to AlertAgent');
      return _routeToAlertAgent(input);
    }

    // 2. Voice/text input -> extract transcript
    final transcript = input.transcript ?? '';
    if (transcript.isEmpty) {
      _log.debug('Empty transcript, ignoring');
      return;
    }

    // 3. ALWAYS check critical safety commands first (pattern-matched, no LLM)
    //    "stop" must work even if the LLM is down — safety critical for
    //    blind users who need to immediately cancel all activity.
    final cmdResult = VoiceCommandHandler.recognize(transcript);
    if (cmdResult case Success(value: VoiceCommand.stop)) {
      _log.info('Safety command: stop (always pattern-matched)');
      return _handleCancel();
    }

    // 4. If ConversationEngine is available and ready, route through it
    if (_conversationEngine != null && _conversationEngine.isReady) {
      _log.info('Routing to ConversationEngine');
      final engineResult =
          await _conversationEngine.processInput(transcript);
      switch (engineResult) {
        case Success(:final value):
          if (!value.isEmpty) {
            _log.info('ConversationEngine responded');
            await _handleConversationResponse(value);
            return;
          }
          // Empty response — fall through to VoiceCommandHandler
          _log.debug('ConversationEngine returned empty, falling back');
        case Failure(:final failure):
          // LLM error — fall through to VoiceCommandHandler
          _log.warning(
              'ConversationEngine failed: ${failure.logMessage}, '
              'falling back to VoiceCommandHandler');
      }
    }

    // 5. FALLBACK: VoiceCommandHandler pattern matching
    //    This preserves all current functionality for users without LLM.
    _log.debug('Using VoiceCommandHandler fallback');
    await _routeViaVoiceCommands(transcript, cmdResult, input);
  }

  /// Handles the response from [ConversationEngine].
  ///
  /// The ConversationEngine already executes tool calls internally during
  /// its tool-use loop (spawning agents, calling handleInput). The
  /// [ConversationResponse.toolCalls] list is informational only — it
  /// records which tools were executed, NOT tools to re-execute.
  ///
  /// This method only speaks the text response via TTS.
  Future<void> _handleConversationResponse(
      ConversationResponse response) async {
    if (response.toolCalls.isNotEmpty) {
      _log.info(
        'ConversationEngine executed tools: ${response.toolCalls.join(", ")}',
      );
    }

    // Speak the text response
    if (response.text.isNotEmpty) {
      await _outputCoordinator.enqueueSpeech(
        AgentIds.system,
        response.text,
        OutputPriority.standard,
      );
    }
  }

  /// Routes input through VoiceCommandHandler pattern matching.
  ///
  /// This is the fallback path when ConversationEngine is unavailable.
  /// [cmdResult] is pre-computed from [VoiceCommandHandler.recognize] to
  /// avoid double-recognition (we already checked for "stop" above).
  Future<void> _routeViaVoiceCommands(
    String transcript,
    Result<VoiceCommand> cmdResult,
    RawInput input,
  ) async {
    switch (cmdResult) {
      // "stop" was already handled above, but for completeness:
      case Success(value: VoiceCommand.stop):
        return _handleCancel();

      case Success(value: VoiceCommand.describe):
        _log.info('Voice command: describe');
        return _handleDescribe();

      case Success(value: VoiceCommand.moreDetails):
        _log.info('Voice command: more details');
        return _routeToFocusAgent(input, 'plus de détails');

      case Success(value: VoiceCommand.repeat):
        _log.info('Voice command: repeat');
        return _routeToFocusAgent(input, 'répète');

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

  /// Handles "stop" / "annule": coordinator.cancelAll then terminate agents.
  ///
  /// The coordinator's cancelAll() already publishes a cancelAll message
  /// on the bus, so we do NOT publish one here to avoid double-publication.
  Future<void> _handleCancel() async {
    // Step 1: Coordinator stops TTS + clears queue + publishes cancelAll + feedback "OK"
    await _outputCoordinator.cancelAll();

    // Step 2: Terminate onDemand agents
    await _supervisor.returnToPassive();

    _log.info('Cancel all completed');
  }

  /// Handles "décris": spawn DescribeAgent or re-route if already active.
  ///
  /// **Pitfall #1**: If Marie says "décris" while DescribeAgent is already
  /// active, we re-route to the existing agent instead of double-spawning.
  Future<void> _handleDescribe() async {
    const describeId = AgentIds.describe;

    if (_supervisor.agents.containsKey(describeId)) {
      // Re-route to existing active agent
      _log.info('DescribeAgent already active, re-routing command');
      final agent = _supervisor.agents[describeId]!.agent;
      await agent.handleInput(AgentInput(
        command: KitaTools.commandDescribe,
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
              command: KitaTools.commandDescribe,
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
    const alertId = AgentIds.alert;
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

  /// Routes to the AI fallback (conversation générale).
  ///
  /// Uses [RequestClassifier] to determine priority, then delegates
  /// to AIRouter for general conversation. For the MVP, provides
  /// audio feedback so the user knows their input was received.
  Future<void> _routeToFallback(String transcript) async {
    if (_classifier != null) {
      final priority = _classifier.classify(transcript);
      _log.debug('Fallback: classified as ${priority.getOrNull()?.name}');
    }

    // For MVP: provide vocal feedback so the user (Marie, blind) knows
    // input was received. Silence = broken for a voice-first blind user.
    _log.info('Fallback: unrecognized command, providing feedback');
    await _outputCoordinator.enqueueSpeech(
      AgentIds.system,
      "Je n'ai pas compris. Dis décris pour décrire, ou stop pour arrêter.",
      OutputPriority.standard,
    );
  }
}
