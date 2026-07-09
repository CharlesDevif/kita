import 'dart:async';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_router.dart';
import '../../ai/domain/tool_models.dart' as ai;
import '../../plugins/built_in/describe/describe_plugin.dart';
import '../domain/clock.dart';
import '../domain/conversation_engine.dart' as iface;
import '../domain/models/agent_ids.dart';
import '../domain/models/agent_input.dart';
import '../domain/progress_phase.dart';
import '../domain/tool_spec.dart' as orch;
import 'agent_supervisor.dart';
import 'kita_tools.dart';
import 'progress_reporter.dart';

/// Concrete implementation of [ConversationEngine] that routes user input
/// through an LLM with tool use.
///
/// Implements a tool-use loop:
/// 1. User says something (voice/text)
/// 2. Engine sends message + conversation history + available tools to LLM
/// 3. LLM either:
///    a) Responds with text -> returned to caller for TTS
///    b) Calls a tool -> execute tool -> feed result back to LLM -> goto 3
///    c) Both text + tool call -> handle both
/// 4. Maintain conversation history for context
class ConversationEngineImpl implements iface.ConversationEngine {
  ConversationEngineImpl({
    required AIRouter aiRouter,
    required AgentSupervisor supervisor,
    required Clock clock,
    List<orch.ToolSpec>? availableTools,
    ProgressReporter? progress,
  })  : _aiRouter = aiRouter,
        _supervisor = supervisor,
        _clock = clock,
        _progress = progress,
        _aiTools = _convertTools(availableTools ?? KitaTools.all);

  static final _log = KitaLogger('Orchestration.ConvEngine');

  final AIRouter _aiRouter;
  final AgentSupervisor _supervisor;
  final Clock _clock;
  final ProgressReporter? _progress;

  /// Tool specs converted to AI domain format (for AIRouter calls).
  final List<ai.ToolSpec> _aiTools;

  /// Conversation history for multi-turn context.
  final List<ai.ConversationMessage> _history = [];

  /// Maximum messages in history to avoid exceeding token limits.
  static const int _maxHistoryLength = 20;

  /// Maximum tool-use loop iterations to prevent infinite loops.
  static const int _maxToolLoopIterations = 5;

  /// Guard against concurrent processInput calls.
  bool _processing = false;

  bool _disposed = false;

  @override
  bool get isReady => !_disposed && _aiRouter.availableProviders.isNotEmpty;

  @override
  Future<Result<iface.ConversationResponse>> processInput(
    String input,
  ) async {
    if (_disposed) {
      return const Result.failure(UnexpectedFailure(
        logMessage: 'ConversationEngine is disposed',
      ));
    }

    if (input.isEmpty) {
      return const Result.success(
        iface.ConversationResponse(text: '', toolCalls: []),
      );
    }

    // Guard against concurrent calls (e.g., rapid voice inputs).
    if (_processing) {
      _log.debug('Already processing, ignoring concurrent input');
      return const Result.failure(UnexpectedFailure(
        logMessage: 'ConversationEngine busy',
      ));
    }
    _processing = true;

    try {
      return await _processInputInternal(input);
    } finally {
      _processing = false;
    }
  }

  @override
  Stream<String> processInputStream(String input) async* {
    // For now, wrap processInput in a single-element stream.
    // Streaming tool-use loops add complexity; revisit when streaming
    // providers are wired end-to-end.
    final result = await processInput(input);
    switch (result) {
      case Success(:final value):
        if (value.text.isNotEmpty) yield value.text;
      case Failure():
        // Caller handles failure via the non-stream API.
        break;
    }
  }

  Future<Result<iface.ConversationResponse>> _processInputInternal(
    String transcript,
  ) async {
    // Send to LLM with tools.
    // The transcript goes in AIRequest.prompt (provider adds it as last user
    // message). History contains only prior turns.
    final result = await _aiRouter.routeWithTools(
      AIRequest(prompt: transcript),
      tools: _aiTools,
      history: _history,
    );

    switch (result) {
      case Failure(:final failure):
        _log.warning('LLM unavailable: ${failure.logMessage}');
        return Result.failure(failure);

      case Success(:final value):
        // Record the user message in history now that the call succeeded.
        _addToHistory(ai.ConversationMessage.user(transcript));
        return _handleLLMResponse(value);
    }
  }

  /// Handle the LLM response, executing the tool-use loop if needed.
  ///
  /// The loop continues while the LLM returns tool calls. Each tool result
  /// is fed back to the LLM for further processing. The loop is bounded
  /// by [_maxToolLoopIterations] to prevent runaway tool calls.
  Future<Result<iface.ConversationResponse>> _handleLLMResponse(
    ai.AIToolResponse response,
  ) async {
    var currentResponse = response;
    var iterations = 0;
    final executedToolNames = <String>[];
    final spokenTexts = <String>[];

    while (currentResponse.hasToolCalls &&
        iterations < _maxToolLoopIterations &&
        !_disposed) {
      iterations++;
      _log.info(
        'Tool-use loop iteration $iterations: '
        '${currentResponse.toolCalls.length} tool calls',
      );

      // If the LLM returned text alongside tool calls, collect it.
      if (currentResponse.hasText) {
        _addToHistory(
          ai.ConversationMessage.assistant(currentResponse.text!),
        );
        spokenTexts.add(currentResponse.text!);
      }

      // Record tool calls in history.
      _addToHistory(
        ai.ConversationMessage.assistantToolCalls(
          currentResponse.toolCalls,
        ),
      );

      // Execute each tool call and collect results.
      for (final call in currentResponse.toolCalls) {
        if (_disposed) break;
        executedToolNames.add(call.name);
        // Un outil démarre (photo, analyse) : signale `working` pour que le
        // ProgressReporter dise « Je regarde. » et rafraîchisse le statut.
        _progress?.report(ProgressPhase.working);
        final toolResult = await _executeToolCall(call);
        if (_disposed) break;
        _addToHistory(ai.ConversationMessage.toolResult(
          callId: call.id,
          result: toolResult,
        ));
      }

      if (_disposed) break;

      // Les outils « auto-parlants » (describe, alert) ont déjà parlé via
      // leur agent : la conversation est terminée, pas de tour de
      // conclusion LLM (voir KitaTools.selfSpeakingTools).
      final allSelfSpeaking = currentResponse.toolCalls.every(
        (c) => KitaTools.selfSpeakingTools.contains(c.name),
      );
      if (allSelfSpeaking) {
        return Result.success(iface.ConversationResponse(
          text: spokenTexts.join(' '),
          toolCalls: executedToolNames,
        ));
      }

      // Send tool results back to the LLM for the next turn.
      final nextResult = await _aiRouter.routeWithTools(
        const AIRequest(prompt: ''),
        tools: _aiTools,
        history: _history,
      );

      switch (nextResult) {
        case Failure(:final failure):
          _log.warning('LLM failed during tool loop: ${failure.logMessage}');
          // Return what we have so far.
          return Result.success(iface.ConversationResponse(
            text: spokenTexts.isNotEmpty
                ? spokenTexts.join(' ')
                : 'J\'ai effectué l\'action demandée.',
            toolCalls: executedToolNames,
          ));

        case Success(:final value):
          currentResponse = value;
      }
    }

    if (iterations >= _maxToolLoopIterations) {
      _log.warning('Tool-use loop reached max iterations');
    }

    // Final response text.
    if (currentResponse.hasText) {
      _addToHistory(
        ai.ConversationMessage.assistant(currentResponse.text!),
      );
      spokenTexts.add(currentResponse.text!);
    }

    final finalText = spokenTexts.isNotEmpty ? spokenTexts.join(' ') : '';

    return Result.success(iface.ConversationResponse(
      text: finalText,
      toolCalls: executedToolNames,
    ));
  }

  /// Execute a single tool call and return the result as a string.
  Future<String> _executeToolCall(ai.ToolCall call) async {
    _log.info('Executing tool: ${call.name}');

    switch (call.name) {
      case KitaTools.toolDescribe:
        return _handleDescribeTool(call.arguments);
      case KitaTools.toolAlert:
        return _handleAlertTool(call.arguments);
      default:
        _log.warning('Unknown tool: ${call.name}');
        return 'Outil inconnu : ${call.name}';
    }
  }

  /// Handle the "describe" tool: spawn DescribeAgent and capture photo.
  Future<String> _handleDescribeTool(Map<String, dynamic> args) async {
    const describeId = AgentIds.describe;

    if (_supervisor.agents.containsKey(describeId)) {
      _log.info('DescribeAgent already active, re-routing');
      final agent = _supervisor.agents[describeId]!.agent;
      await agent.handleInput(AgentInput(
        command: KitaTools.commandDescribe,
        params: args,
        source: InputSource.voice,
        timestamp: _clock.now(),
      ));
      return 'Description en cours.';
    }

    final result = await _supervisor.spawn(KitaDescribePlugin());
    switch (result) {
      case Success():
        final agent = _supervisor.agents[describeId]?.agent;
        if (agent != null) {
          await agent.handleInput(AgentInput(
            command: KitaTools.commandDescribe,
            params: args,
            source: InputSource.voice,
            timestamp: _clock.now(),
          ));
        }
        return 'Description en cours.';

      case Failure(:final failure):
        _log.error('Failed to spawn DescribeAgent: ${failure.logMessage}');
        return 'Impossible de démarrer la description : ${failure.userMessage}';
    }
  }

  /// Handle the "alert" tool: activate/deactivate obstacle surveillance.
  Future<String> _handleAlertTool(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? 'start';
    const alertId = AgentIds.alert;

    switch (action) {
      case 'start':
        final entry = _supervisor.agents[alertId];
        if (entry != null && entry.state == AgentState.active) {
          return 'La surveillance est déjà active.';
        }
        if (entry != null && entry.state == AgentState.suspended) {
          final resumeResult = await _supervisor.resume(alertId);
          return resumeResult.isSuccess
              ? 'Surveillance d\'obstacles activée.'
              : 'Impossible d\'activer la surveillance.';
        }
        // Agent not registered — need to log that it should be spawned
        // by the orchestrator. The AlertAgent is persistent and should be
        // spawned during KitaOrchestrator.initialize(), not here.
        _log.warning('AlertAgent not found, orchestrator may not be initialized');
        return 'La surveillance n\'est pas disponible.';

      case 'stop':
        final entry = _supervisor.agents[alertId];
        if (entry != null && entry.state == AgentState.active) {
          final suspendResult = await _supervisor.suspend(alertId);
          return suspendResult.isSuccess
              ? 'Surveillance d\'obstacles désactivée.'
              : 'Impossible de désactiver la surveillance.';
        }
        return 'La surveillance n\'est pas active.';

      default:
        return 'Action non reconnue : $action';
    }
  }

  /// Add a message to conversation history, trimming if needed.
  void _addToHistory(ai.ConversationMessage message) {
    _history.add(message);
    while (_history.length > _maxHistoryLength) {
      _history.removeAt(0);
    }
  }

  /// Clear conversation history (e.g., on session reset).
  void resetHistory() => _history.clear();

  /// Read-only view of current conversation history (for testing).
  List<ai.ConversationMessage> get history => List.unmodifiable(_history);

  /// Dispose the engine and prevent further processing.
  void dispose() {
    _disposed = true;
    _history.clear();
  }

  /// Convert orchestration ToolSpecs to AI domain ToolSpecs.
  static List<ai.ToolSpec> _convertTools(List<orch.ToolSpec> tools) {
    return tools.map((t) {
      final properties = <String, dynamic>{};
      final required = <String>[];
      for (final entry in t.parameters.entries) {
        properties[entry.key] = {
          'type': entry.value.type,
          'description': entry.value.description,
          if (entry.value.enumValues != null &&
              entry.value.enumValues!.isNotEmpty)
            'enum': entry.value.enumValues,
        };
        if (entry.value.isRequired) {
          required.add(entry.key);
        }
      }
      return ai.ToolSpec(
        name: t.name,
        description: t.description,
        parameters: {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      );
    }).toList();
  }
}
