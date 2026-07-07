import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/background_service.dart';

/// iOS implementation of [KitaBackgroundService] using platform channels.
///
/// Communicates with the native Swift BackgroundChannel via
/// [MethodChannel] `com.kita/background`.
///
/// iOS strategy for keeping the app alive in background:
/// - **Background Audio** — AVAudioSession with `.playback` + `.mixWithOthers`
///   keeps the app active even with silent audio.
/// - **Background Location** — CLLocationManager with `always` authorization
///   reactivates the app on significant location changes.
///
/// Note: Camera is NOT available in background on iOS (hardware locked to
/// foreground app). Only accelerometer and location work in background.
class IosBackgroundServiceImpl implements KitaBackgroundService {
  IosBackgroundServiceImpl({
    MethodChannel? methodChannel,
  }) : _channel = methodChannel ?? const MethodChannel('com.kita/background');

  static final _log = KitaLogger('BackgroundService');

  final MethodChannel _channel;
  final StreamController<BackgroundServiceState> _stateController =
      StreamController<BackgroundServiceState>.broadcast();

  BackgroundServiceState _currentState = BackgroundServiceState.idle;

  @override
  BackgroundServiceState get currentState => _currentState;

  @override
  Stream<BackgroundServiceState> get stateStream => _stateController.stream;

  @override
  Future<bool> get isRunning async {
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      _log.warning('Failed to query service state', error: e);
      return false;
    } on MissingPluginException {
      _log.warning('Background service plugin not available');
      return false;
    }
  }

  @override
  Future<Result<void>> start() async {
    _setState(BackgroundServiceState.starting);

    try {
      await _channel.invokeMethod<bool>('startService');
      _setState(BackgroundServiceState.running);
      _log.info('Background service started (iOS audio + location)');
      return const Result.success(null);
    } on PlatformException catch (e, stack) {
      _setState(BackgroundServiceState.error);
      _log.error('Background service start failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'iOS background service start failed: ${e.code}',
          cause: e,
          stackTrace: stack,
        ),
      );
    } on MissingPluginException catch (e, stack) {
      _setState(BackgroundServiceState.error);
      _log.error('Background service plugin not available',
          error: e, stackTrace: stack);
      return Result.failure(
        PermissionFailure(
          userMessage: 'Le service en arrière-plan n\'est pas disponible.',
          logMessage: 'iOS background service plugin not available',
          permission: 'background_audio',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> stop() async {
    if (_currentState == BackgroundServiceState.idle ||
        _currentState == BackgroundServiceState.stopped) {
      return const Result.success(null);
    }

    try {
      await _channel.invokeMethod<bool>('stopService');
      _setState(BackgroundServiceState.stopped);
      _log.info('Background service stopped (iOS)');
      return const Result.success(null);
    } on PlatformException catch (e, stack) {
      _log.error('Background service stop failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'iOS background service stop failed: ${e.code}',
          cause: e,
          stackTrace: stack,
        ),
      );
    } on MissingPluginException {
      _setState(BackgroundServiceState.stopped);
      return const Result.success(null);
    }
  }

  @override
  Future<bool> get isBatteryOptimizationIgnored async {
    // iOS does not have a battery optimization exemption system.
    // Low Power Mode is user-controlled and cannot be overridden.
    return true;
  }

  @override
  Future<Result<bool>> requestBatteryOptimizationExemption() async {
    // No battery optimization exemption on iOS.
    _log.info('Battery optimization exemption not applicable on iOS');
    return const Result.success(true);
  }

  /// Dispose the service and close the state stream.
  void dispose() {
    _stateController.close();
  }

  void _setState(BackgroundServiceState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
