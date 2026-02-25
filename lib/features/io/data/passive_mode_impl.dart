import 'dart:async';

import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/background_service.dart';
import '../domain/motion_service.dart';
import '../domain/passive_mode.dart';
import 'adaptive_sensor_controller.dart';

/// Callback for querying current battery level (0-100).
typedef BatteryLevelProvider = Future<int> Function();

/// Callback for battery state change stream.
typedef BatteryStateStreamProvider = Stream<int> Function();

/// Callback for triggering a low battery vocal alert.
typedef LowBatteryAlertCallback = void Function();

/// Implementation of [PassiveModeManager] that orchestrates:
/// - Motion-based camera FPS adaptation
/// - Inactivity timer (camera OFF after 30s immobile)
/// - Battery monitoring with low battery mode
/// - Background service lifecycle
class PassiveModeManagerImpl implements PassiveModeManager {
  PassiveModeManagerImpl({
    required MotionService motionService,
    required KitaBackgroundService backgroundService,
    required AdaptiveSensorController sensorController,
    required BatteryLevelProvider getBatteryLevel,
    required BatteryStateStreamProvider batteryStream,
    LowBatteryAlertCallback? onLowBattery,
    Duration inactivityTimeout = const Duration(seconds: 30),
    int lowBatteryThreshold = 20,
  })  : _motion = motionService,
        _background = backgroundService,
        _sensor = sensorController,
        _getBatteryLevel = getBatteryLevel,
        _batteryStream = batteryStream,
        _onLowBattery = onLowBattery,
        _inactivityTimeout = inactivityTimeout,
        _lowBatteryThreshold = lowBatteryThreshold;

  static final _log = KitaLogger('PassiveMode');

  final MotionService _motion;
  final KitaBackgroundService _background;
  final AdaptiveSensorController _sensor;
  final BatteryLevelProvider _getBatteryLevel;
  final BatteryStateStreamProvider _batteryStream;
  final LowBatteryAlertCallback? _onLowBattery;
  final Duration _inactivityTimeout;
  final int _lowBatteryThreshold;

  final StreamController<PassiveModeState> _stateController =
      StreamController<PassiveModeState>.broadcast();

  PassiveModeState _currentState = PassiveModeState.idle;
  Timer? _inactivityTimer;
  StreamSubscription<int>? _batterySubscription;
  bool _lowBatteryAlerted = false;
  bool _isLowBattery = false;

  @override
  PassiveModeState get currentState => _currentState;

  @override
  Stream<PassiveModeState> get stateStream => _stateController.stream;

  /// Whether the low battery alert has been triggered (once per session).
  bool get lowBatteryAlerted => _lowBatteryAlerted;

  /// Whether we are in low battery mode.
  bool get isLowBattery => _isLowBattery;

  @override
  Future<Result<void>> activate() async {
    if (_currentState != PassiveModeState.idle) {
      _log.warning('Passive mode already active');
      return const Result.success(null);
    }

    // Start background service
    final bgResult = await _background.start();
    if (bgResult.isFailure) {
      _log.error('Background service start failed');
      return bgResult;
    }

    // Check initial battery level
    try {
      final level = await _getBatteryLevel();
      _handleBatteryLevel(level);
    } catch (e) {
      _log.warning('Initial battery check failed');
    }

    // Start motion monitoring
    final motionResult = await _motion.startMonitoring(
      onStateChanged: _onMotionChanged,
    );
    if (motionResult.isFailure) {
      _log.warning('Motion monitoring start failed, continuing without motion');
    }

    // Subscribe to battery changes
    _batterySubscription = _batteryStream().listen(
      _handleBatteryLevel,
      onError: (Object error) {
        _log.warning('Battery stream error');
      },
    );

    _setState(PassiveModeState.monitoring);
    _log.info('Passive mode activated');
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deactivate() async {
    if (_currentState == PassiveModeState.idle) {
      return const Result.success(null);
    }

    // Cancel subscriptions
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    await _batterySubscription?.cancel();
    _batterySubscription = null;

    // Stop sensor controller (camera)
    await _sensor.dispose();

    // Stop motion monitoring
    await _motion.stopMonitoring();

    // Stop background service
    await _background.stop();

    _lowBatteryAlerted = false;
    _isLowBattery = false;
    _setState(PassiveModeState.idle);
    _log.info('Passive mode deactivated');
    return const Result.success(null);
  }

  /// Dispose all resources. Call when the manager is no longer needed.
  void dispose() {
    _inactivityTimer?.cancel();
    _batterySubscription?.cancel();
    _stateController.close();
  }

  void _onMotionChanged(MotionState motion) {
    _log.debug('Motion state changed: ${motion.name}');

    // Cancel inactivity timer on any motion
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    if (_isLowBattery) {
      // In low battery mode: camera always OFF, only accelerometer
      _sensor.adaptToMotion(MotionState.immobile);
      return;
    }

    // Adapt camera FPS to motion
    _sensor.adaptToMotion(motion);

    // Start inactivity timer if immobile
    if (motion == MotionState.immobile) {
      _inactivityTimer = Timer(_inactivityTimeout, () {
        _log.info('Inactivity timeout reached, camera OFF');
        _sensor.adaptToMotion(MotionState.immobile);
      });
    }
  }

  void _handleBatteryLevel(int level) {
    final wasLow = _isLowBattery;
    _isLowBattery = level < _lowBatteryThreshold;

    if (_isLowBattery && !wasLow) {
      _log.info('Low battery mode activated');
      _sensor.updateConfig(FpsConfig.lowBattery);
      _sensor.adaptToMotion(MotionState.immobile);
      _setState(PassiveModeState.lowBattery);

      // Trigger vocal alert (once per session)
      if (!_lowBatteryAlerted) {
        _lowBatteryAlerted = true;
        _onLowBattery?.call();
      }
    } else if (!_isLowBattery && wasLow) {
      _log.info('Battery level restored above threshold');
      _sensor.updateConfig(FpsConfig.standard);
      _setState(PassiveModeState.monitoring);
      // Re-adapt to current motion
      _sensor.adaptToMotion(_motion.currentState);
    }
  }

  void _setState(PassiveModeState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
