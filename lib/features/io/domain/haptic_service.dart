import '../../../core/errors/result.dart';

enum HapticPattern { info, warning, danger, confirmation, presence, custom }

abstract interface class HapticService {
  Future<Result<void>> trigger(HapticPattern pattern);
  Future<Result<void>> info();
  Future<Result<void>> warning();
  Future<Result<void>> danger();

  /// Triple soft heartbeat pattern — "Kita is still here".
  ///
  /// Used after a CRITICAL interruption to reassure the user that
  /// Kita is still active and listening.
  Future<Result<void>> presence();
}
