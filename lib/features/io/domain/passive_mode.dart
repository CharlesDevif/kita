import '../../../core/errors/result.dart';

/// State of the passive monitoring mode.
enum PassiveModeState {
  /// Mode passif not active.
  idle,

  /// Monitoring with minimal sensors (accelerometer + ambient mic).
  monitoring,

  /// Actively alerting (obstacle detected, camera active).
  alerting,

  /// Battery < 20%, reduced sensor usage.
  lowBattery,
}

/// Abstract interface for the intelligent passive monitoring mode.
///
/// Manages sensor adaptation based on motion state and battery level:
/// - Immobile: accelerometer only (5Hz), camera OFF
/// - Walking: accelerometer 15Hz, camera 15 FPS
/// - Running: accelerometer 50Hz, camera 30 FPS
/// - Low battery (<20%): accelerometer 5Hz, camera OFF, vocal alert
abstract interface class PassiveModeManager {
  /// Current state of the passive mode.
  PassiveModeState get currentState;

  /// Stream of state changes.
  Stream<PassiveModeState> get stateStream;

  /// Activate the intelligent passive mode.
  Future<Result<void>> activate();

  /// Deactivate the passive mode and release all resources.
  Future<Result<void>> deactivate();
}
