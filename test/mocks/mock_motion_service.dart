import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/motion_service.dart';

class MockMotionService implements MotionService {
  MotionState _state = MotionState.immobile;
  void Function(MotionState state)? _onStateChanged;

  @override
  MotionState get currentState => _state;

  @override
  Future<Result<void>> startMonitoring({
    void Function(MotionState state)? onStateChanged,
  }) async {
    _onStateChanged = onStateChanged;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopMonitoring() async {
    _onStateChanged = null;
    return const Result.success(null);
  }

  void simulateState(MotionState state) {
    _state = state;
    _onStateChanged?.call(state);
  }
}
