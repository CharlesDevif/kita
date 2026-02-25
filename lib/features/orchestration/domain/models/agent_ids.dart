/// Well-known agent IDs used across the orchestration system.
///
/// Centralizes magic strings to avoid typos and enable refactoring.
abstract class AgentIds {
  /// The DescribeAgent — provides visual scene descriptions.
  static const describe = 'com.kita.describe';

  /// The AlertAgent — monitors obstacles and triggers safety alerts.
  static const alert = 'com.kita.alert';

  /// System-level messages (not from any specific agent).
  static const system = 'system';
}
