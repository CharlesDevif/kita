import '../../../plugins/domain/trust_level.dart';
import 'agent_message.dart';

/// The lifecycle type of an agent.
enum AgentType {
  /// Runs as long as Kita is active. Survives mode changes.
  /// Example: AlertAgent.
  persistent,

  /// Spawned on demand, terminated when its task is done.
  /// Example: DescribeAgent.
  onDemand,

  /// Runs in the background at low priority. Can be suspended.
  /// Reserved for post-MVP.
  background,
}

/// Priority level of an agent, used by the Supervisor and OutputCoordinator
/// to determine scheduling and output arbitration.
///
/// Lower [level] = higher priority.
enum AgentPriority implements Comparable<AgentPriority> {
  /// Critical agents (e.g., obstacle alerts < 3m). Interrupts TTS immediately.
  critical(0),

  /// High-priority agents (e.g., obstacle alerts 3-5m). Waits for phrase end.
  high(1),

  /// Standard agents (descriptions, conversation). FIFO queue.
  standard(2),

  /// Low-priority agents (background, cleanup). FIFO with timeout.
  low(3);

  const AgentPriority(this.level);

  /// Numeric level where lower = higher priority.
  final int level;

  /// Returns true if this priority is higher than [other].
  bool operator >(AgentPriority other) => level < other.level;

  /// Returns true if this priority is lower than [other].
  bool operator <(AgentPriority other) => level > other.level;

  /// Returns true if this priority is higher than or equal to [other].
  bool operator >=(AgentPriority other) => level <= other.level;

  /// Returns true if this priority is lower than or equal to [other].
  bool operator <=(AgentPriority other) => level >= other.level;

  @override
  int compareTo(AgentPriority other) => level.compareTo(other.level);
}

/// Manifest describing an agent's identity, capabilities, and subscriptions.
///
/// Extends the concepts from [PluginManifest] with agent-specific fields:
/// [agentType], [priority], and [subscriptions].
///
/// Note: This class does NOT inherit from [PluginManifest] to avoid
/// cross-feature coupling. It duplicates the same fields intentionally.
class AgentManifest {
  /// Creates an [AgentManifest].
  const AgentManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.trustLevel,
    required this.agentType,
    required this.priority,
    this.permissions = const [],
    this.capabilities = const [],
    this.compatibleProfiles = const [],
    this.subscriptions = const {},
  });

  /// Unique identifier in reverse-domain format (e.g., "com.kita.describe").
  final String id;

  /// Human-readable name of the agent.
  final String name;

  /// Semantic version string (e.g., "1.0.0").
  final String version;

  /// Short description of what the agent does.
  final String description;

  /// Trust level determining sandbox restrictions.
  final TrustLevel trustLevel;

  /// Permissions required by this agent (e.g., "camera", "microphone").
  final List<String> permissions;

  /// Capabilities this agent provides (e.g., "vision", "detection").
  final List<String> capabilities;

  /// User profiles this agent is compatible with.
  final List<String> compatibleProfiles;

  /// The lifecycle type of this agent.
  final AgentType agentType;

  /// The priority level of this agent for output arbitration.
  final AgentPriority priority;

  /// The set of [AgentMessageType]s this agent subscribes to on the bus.
  final Set<AgentMessageType> subscriptions;

  @override
  String toString() => 'AgentManifest(id: $id, type: $agentType, '
      'priority: $priority)';
}
