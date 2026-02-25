import 'dart:async';

import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/background_service.dart';

class MockBackgroundService implements KitaBackgroundService {
  BackgroundServiceState _state = BackgroundServiceState.idle;
  final StreamController<BackgroundServiceState> _controller =
      StreamController<BackgroundServiceState>.broadcast();

  bool startCalled = false;
  bool stopCalled = false;

  @override
  BackgroundServiceState get currentState => _state;

  @override
  Stream<BackgroundServiceState> get stateStream => _controller.stream;

  @override
  Future<bool> get isRunning async =>
      _state == BackgroundServiceState.running;

  @override
  Future<Result<void>> start() async {
    startCalled = true;
    _state = BackgroundServiceState.running;
    _controller.add(_state);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalled = true;
    _state = BackgroundServiceState.stopped;
    _controller.add(_state);
    return const Result.success(null);
  }

  @override
  Future<bool> get isBatteryOptimizationIgnored async => true;

  @override
  Future<Result<bool>> requestBatteryOptimizationExemption() async =>
      const Result.success(true);

  void simulateState(BackgroundServiceState state) {
    _state = state;
    _controller.add(state);
  }

  void dispose() {
    _controller.close();
  }
}
