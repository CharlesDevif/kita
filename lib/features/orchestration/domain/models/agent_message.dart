/// Types of messages exchanged between agents via the [AgentBus].
///
/// Agents subscribe to specific message types through their
/// [AgentManifest.subscriptions]. Only subscribed types are delivered.
enum AgentMessageType {
  // -- Lifecycle --

  /// Broadcast when a new agent is spawned by the Supervisor.
  agentSpawned,

  /// Broadcast when an agent is terminated by the Supervisor.
  agentTerminated,

  // -- Interruption --

  /// Sent when a higher-priority agent needs to interrupt the current speaker.
  interruptRequest,

  /// Acknowledgement from an interrupted agent that it has yielded.
  interruptAck,

  // -- Data sharing --

  /// Contextual update (e.g., user location changed).
  contextUpdate,

  /// A detection event from sensors (e.g., obstacle detected at 2m).
  detectionEvent,

  /// Notification that a description task is complete.
  descriptionComplete,

  // -- User intent --

  /// User said "stop" -- all agents should cease output.
  cancelAll,

  /// A new user command has been received.
  userCommand,
}

/// A typed message exchanged between agents via the [AgentBus].
///
/// Messages are filtered by the bus: only agents subscribed to [type]
/// receive them. If [toAgent] is specified, only that specific agent
/// receives the message (provided it is subscribed to the type).
class AgentMessage {
  /// Creates an [AgentMessage].
  ///
  /// [fromAgent] identifies the sender (e.g., "alert", "describe", "system").
  /// [toAgent] is null for broadcast to all subscribers of [type].
  const AgentMessage({
    required this.fromAgent,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.toAgent,
  });

  /// ID of the agent that sent this message.
  final String fromAgent;

  /// ID of the intended recipient. Null means broadcast to all
  /// agents subscribed to [type].
  final String? toAgent;

  /// The type of this message, used for subscription filtering.
  final AgentMessageType type;

  /// Arbitrary data associated with this message.
  final Map<String, dynamic> payload;

  /// When this message was created.
  final DateTime timestamp;

  @override
  String toString() =>
      'AgentMessage(from: $fromAgent, to: $toAgent, type: $type)';
}
