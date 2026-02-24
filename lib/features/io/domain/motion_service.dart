import '../../../core/errors/result.dart';

enum MotionState { immobile, walking, running }

abstract interface class MotionService {
  MotionState get currentState;
  Future<Result<void>> startMonitoring({
    void Function(MotionState state)? onStateChanged,
  });
  Future<Result<void>> stopMonitoring();
}
