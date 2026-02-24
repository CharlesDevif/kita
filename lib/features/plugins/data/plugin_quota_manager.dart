import '../../../core/constants/limits.dart';
import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';

/// Enforces per-plugin API call quotas using a sliding time window.
class PluginQuotaManager {
  PluginQuotaManager({
    this.maxCallsPerMinute = Limits.maxPluginApiCallsPerMinute,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxCallsPerMinute;
  final DateTime Function() _clock;

  static final _log = KitaLogger('Plugin.Quota');

  /// Plugin ID -> list of timestamps for recent calls.
  final Map<String, List<DateTime>> _callHistory = {};

  /// Checks whether the plugin can make an API call. Returns success if
  /// allowed, failure if quota exceeded.
  Result<void> checkQuota(String pluginId) {
    final now = _clock();
    final cutoff = now.subtract(const Duration(minutes: 1));

    final history = _callHistory[pluginId] ?? [];
    // Remove expired entries
    history.removeWhere((t) => t.isBefore(cutoff));
    _callHistory[pluginId] = history;

    if (history.length >= maxCallsPerMinute) {
      _log.warning('Quota exceeded for plugin $pluginId '
          '(${history.length}/$maxCallsPerMinute calls/min)');
      return Result.failure(PluginFailure(
        userMessage: 'Le plugin a depasse son quota de requetes.',
        logMessage: 'Quota exceeded for plugin $pluginId: '
            '${history.length}/$maxCallsPerMinute calls/min',
        pluginId: pluginId,
      ));
    }

    // Remove stale plugin entries with empty history to prevent memory leak.
    pruneInactivePlugins();

    return const Result.success(null);
  }

  /// Removes entries for plugins with no recent call history.
  ///
  /// Prevents memory leak when many plugins are registered but inactive.
  void pruneInactivePlugins() {
    _callHistory.removeWhere((_, timestamps) => timestamps.isEmpty);
  }

  /// Records a successful API call for quota tracking.
  void recordCall(String pluginId) {
    final now = _clock();
    _callHistory.putIfAbsent(pluginId, () => []).add(now);
  }

  /// Returns the number of remaining calls for a plugin in the current window.
  int remainingCalls(String pluginId) {
    final now = _clock();
    final cutoff = now.subtract(const Duration(minutes: 1));

    final history = _callHistory[pluginId] ?? [];
    history.removeWhere((t) => t.isBefore(cutoff));
    _callHistory[pluginId] = history;

    return (maxCallsPerMinute - history.length).clamp(0, maxCallsPerMinute);
  }

  /// Resets quota tracking for a specific plugin.
  void reset(String pluginId) {
    _callHistory.remove(pluginId);
  }

  /// Resets all quota tracking.
  void resetAll() {
    _callHistory.clear();
  }
}
