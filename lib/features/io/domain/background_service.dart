import '../../../core/errors/result.dart';

/// State of the background service lifecycle.
enum BackgroundServiceState { idle, starting, running, stopped, error }

/// Abstract interface for platform-specific background service management.
///
/// On Android, this wraps a Foreground Service with persistent notification.
/// On iOS, this wraps Background Audio + Location sessions.
abstract interface class KitaBackgroundService {
  /// Current state of the background service.
  BackgroundServiceState get currentState;

  /// Stream of state changes for the background service.
  Stream<BackgroundServiceState> get stateStream;

  /// Whether the background service is currently running.
  Future<bool> get isRunning;

  /// Start the background service.
  ///
  /// On Android: creates a Foreground Service with notification.
  /// Must be called while the app is in the foreground (Android 12+ restriction).
  Future<Result<void>> start();

  /// Stop the background service and release all resources.
  Future<Result<void>> stop();

  /// Check if battery optimization is disabled for this app.
  Future<bool> get isBatteryOptimizationIgnored;

  /// Request the user to disable battery optimization.
  ///
  /// Returns true if the user granted the exemption.
  Future<Result<bool>> requestBatteryOptimizationExemption();
}
