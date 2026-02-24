import 'dart:async';

import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import 'daos/episode_dao.dart';

final _log = KitaLogger('Memory');

/// Default retention period for episodic data.
const Duration defaultRetentionPeriod = Duration(days: 30);

/// Default interval between automatic cleanups.
const Duration defaultCleanupInterval = Duration(hours: 24);

/// Service that automatically cleans up expired episodic data.
///
/// - Episodes older than [retentionPeriod] are deleted
/// - Episodes marked as pinned (important) are preserved indefinitely
/// - Runs once at startup, then every [cleanupInterval]
class AutoCleanupService {
  AutoCleanupService({
    required this.episodeDao,
    this.retentionPeriod = defaultRetentionPeriod,
    this.cleanupInterval = defaultCleanupInterval,
  });

  final EpisodeDao episodeDao;
  final Duration retentionPeriod;
  final Duration cleanupInterval;

  Timer? _timer;
  bool _isRunning = false;

  /// Whether the periodic timer is active.
  bool get isRunning => _isRunning;

  /// Starts the auto-cleanup: runs immediately, then periodically.
  Future<Result<int>> start() async {
    final result = await runCleanup();
    _schedulePeriodicCleanup();
    return result;
  }

  /// Stops the periodic cleanup timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _log.info('Auto-cleanup stopped');
  }

  /// Runs a single cleanup pass. Returns the number of deleted episodes.
  Future<Result<int>> runCleanup() async {
    final cutoff = DateTime.now().subtract(retentionPeriod);
    _log.info('Running auto-cleanup (cutoff: $cutoff)');

    final result = await episodeDao.deleteExpiredBefore(cutoff);
    result.when(
      success: (count) {
        if (count > 0) {
          _log.info('Auto-cleanup removed $count expired episode(s)');
        } else {
          _log.debug('Auto-cleanup: nothing to clean');
        }
      },
      failure: (failure) {
        _log.error('Auto-cleanup failed: ${failure.logMessage}');
      },
    );
    return result;
  }

  void _schedulePeriodicCleanup() {
    _timer?.cancel();
    _timer = Timer.periodic(cleanupInterval, (_) {
      runCleanup();
    });
    _isRunning = true;
    _log.info('Auto-cleanup scheduled every ${cleanupInterval.inHours}h');
  }

  /// Disposes the service and cancels the timer.
  void dispose() {
    stop();
  }
}
