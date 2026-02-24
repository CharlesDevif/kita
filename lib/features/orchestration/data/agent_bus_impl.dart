import 'dart:async';

import '../domain/agent_bus.dart';
import '../domain/models/agent_message.dart';

/// Implementation of [AgentBus] using a broadcast [StreamController].
///
/// Messages are published to a single broadcast stream and filtered
/// per-agent based on their subscriptions. This is efficient because
/// `Stream.where()` is lazy -- non-matching events don't trigger
/// any processing.
///
/// **Important:** Broadcast streams do not buffer messages. If a message
/// is published before an agent subscribes, it is lost. The
/// [AgentSupervisor] must subscribe and start listening BEFORE
/// calling `agent.onSpawn()`.
class AgentBusImpl implements AgentBus {
  final StreamController<AgentMessage> _controller =
      StreamController<AgentMessage>.broadcast();

  final Map<String, Set<AgentMessageType>> _subscriptions = {};

  @override
  void publish(AgentMessage message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }

  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {
    _subscriptions[agentId] = types;
  }

  @override
  void unsubscribe(String agentId) {
    _subscriptions.remove(agentId);
  }

  @override
  Stream<AgentMessage> streamFor(String agentId) {
    return _controller.stream.where((message) {
      // Agent must be subscribed to the message type.
      final subs = _subscriptions[agentId];
      if (subs == null || !subs.contains(message.type)) return false;

      // If toAgent is specified, only deliver to that specific agent.
      if (message.toAgent != null && message.toAgent != agentId) return false;

      return true;
    });
  }

  /// Closes the underlying stream controller.
  ///
  /// Called by the [KitaOrchestrator] during shutdown. After this,
  /// no more messages can be published or received.
  void dispose() {
    _controller.close();
  }
}
