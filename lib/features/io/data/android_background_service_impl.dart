import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/background_service.dart';

/// Android implementation of [KitaBackgroundService] using platform channels.
///
/// Communicates with the native Kotlin ForegroundService via
/// [MethodChannel] `com.kita/background`.
///
/// The native side manages:
/// - Foreground Service with persistent notification
/// - foregroundServiceType: camera|microphone|location
/// - Wake lock for CPU
/// - Service restart on kill
class AndroidBackgroundServiceImpl implements KitaBackgroundService {
  AndroidBackgroundServiceImpl({
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
      _log.info('Background service started');
      return const Result.success(null);
    } on PlatformException catch (e, stack) {
      _setState(BackgroundServiceState.error);
      _log.error('Background service start failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Foreground service start failed: ${e.code}',
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
          userMessage: 'Le service en arriere-plan n\'est pas disponible.',
          logMessage: 'Background service plugin not available',
          permission: 'foreground_service',
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
      _log.info('Background service stopped');
      return const Result.success(null);
    } on PlatformException catch (e, stack) {
      _log.error('Background service stop failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Foreground service stop failed: ${e.code}',
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
    try {
      final result =
          await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return result ?? false;
    } on PlatformException catch (e) {
      _log.warning('Failed to query battery optimization status', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Result<bool>> requestBatteryOptimizationExemption() async {
    try {
      final granted = await _channel
              .invokeMethod<bool>('requestBatteryOptimizationExemption') ??
          false;
      _log.info(
        'Battery optimization exemption ${granted ? "granted" : "denied"}',
      );
      return Result.success(granted);
    } on PlatformException catch (e, stack) {
      _log.error('Battery optimization request failed',
          error: e, stackTrace: stack);
      return Result.failure(
        PermissionFailure(
          userMessage:
              'Impossible de modifier les parametres de batterie.',
          logMessage: 'Battery optimization request failed: ${e.code}',
          permission: 'battery_optimization',
          cause: e,
          stackTrace: stack,
        ),
      );
    } on MissingPluginException catch (e, stack) {
      return Result.failure(
        PermissionFailure(
          userMessage:
              'Fonction non disponible sur cette plateforme.',
          logMessage: 'Battery optimization plugin not available',
          permission: 'battery_optimization',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
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
