import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/motion_service.dart';

/// Implementation of [MotionService] using `sensors_plus` accelerometer.
///
/// Classifies motion state based on accelerometer magnitude:
/// - immobile: magnitude < 1.5 m/s^2
/// - walking: magnitude 1.5 - 5.0 m/s^2
/// - running: magnitude > 5.0 m/s^2
///
/// Uses a rolling average over the last 10 samples for stability.
class MotionServiceImpl implements MotionService {
  MotionServiceImpl({
    this.immobileThreshold = 1.5,
    this.runningThreshold = 5.0,
    this.sampleSize = 10,
  });

  static final _log = KitaLogger('IO');

  final double immobileThreshold;
  final double runningThreshold;
  final int sampleSize;

  MotionState _currentState = MotionState.immobile;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  void Function(MotionState state)? _onStateChanged;
  final List<double> _magnitudes = [];

  @override
  MotionState get currentState => _currentState;

  @override
  Future<Result<void>> startMonitoring({
    void Function(MotionState state)? onStateChanged,
  }) async {
    if (_subscription != null) {
      _log.warning('Motion monitoring already active');
      return const Result.success(null);
    }

    _onStateChanged = onStateChanged;

    try {
      final stream = userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      );

      _subscription = stream.listen(
        _onAccelerometerEvent,
        onError: (Object error) {
          _log.error('Accelerometer stream error', error: error);
        },
        cancelOnError: false,
      );

      _log.info('Motion monitoring started');
      return const Result.success(null);
    } on MissingPluginException catch (e, stack) {
      _log.warning('Accelerometer not available on this platform',
          error: e, stackTrace: stack);
      return Result.failure(
        PermissionFailure(
          userMessage: 'Capteur de mouvement non disponible.',
          logMessage: 'Accelerometer plugin not available: $e',
          permission: 'motion_sensor',
          cause: e,
          stackTrace: stack,
        ),
      );
    } catch (e, stack) {
      _log.error('Motion monitoring start failed',
          error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Motion monitoring start failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> stopMonitoring() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      _onStateChanged = null;
      _magnitudes.clear();
      _log.info('Motion monitoring stopped');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Motion monitoring stop failed',
          error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Motion monitoring stop failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudes.add(magnitude);
    if (_magnitudes.length > sampleSize) {
      _magnitudes.removeAt(0);
    }

    if (_magnitudes.length < sampleSize) return;

    final avgMagnitude =
        _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;

    final newState = _classifyMotion(avgMagnitude);
    if (newState != _currentState) {
      _currentState = newState;
      _log.debug('Motion state changed: ${newState.name}');
      _onStateChanged?.call(newState);
    }
  }

  MotionState _classifyMotion(double magnitude) {
    if (magnitude < immobileThreshold) {
      return MotionState.immobile;
    } else if (magnitude > runningThreshold) {
      return MotionState.running;
    } else {
      return MotionState.walking;
    }
  }
}
