import 'models/agent_message.dart';

/// Interface for the inter-agent communication bus.
///
/// The bus delivers typed [AgentMessage]s to agents based on their
/// subscriptions. An agent only receives messages whose [AgentMessageType]
/// is in its subscription set.
///
/// ## Contract: subscription ordering
///
/// The [AgentSupervisor] MUST call [subscribe] and start listening on
/// [streamFor] BEFORE calling `agent.onSpawn()`. This ensures the agent
/// does not miss any messages published during its initialization:
///
/// ```
/// 1. bus.subscribe(agentId, manifest.subscriptions)
/// 2. listener = bus.streamFor(agentId).listen(agent.onBusMessage)
/// 3. agent.onSpawn(context)
/// ```
abstract class AgentBus {
  /// Publishes a [message] to the bus.
  ///
  /// The message is delivered to all agents subscribed to [message.type].
  /// If [message.toAgent] is specified, only that specific agent receives
  /// it (provided it is subscribed to the type).
  void publish(AgentMessage message);

  /// Subscribes an agent to receive messages of the given [types].
  ///
  /// Replaces any previous subscription for [agentId].
  void subscribe(String agentId, Set<AgentMessageType> types);

  /// Removes the subscription for [agentId].
  ///
  /// The agent will no longer receive any messages after this call.
  /// Called automatically by the Supervisor on agent termination.
  void unsubscribe(String agentId);

  /// Returns a filtered stream of messages for [agentId].
  ///
  /// Only messages matching the agent's subscriptions are included.
  /// If a message has a specific [toAgent] that differs from [agentId],
  /// it is excluded.
  Stream<AgentMessage> streamFor(String agentId);
}
