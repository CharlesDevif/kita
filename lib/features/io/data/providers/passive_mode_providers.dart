import 'dart:async' show unawaited;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/passive_mode.dart';
import '../adaptive_sensor_controller.dart';
import '../passive_mode_impl.dart';
import 'background_providers.dart';
import 'camera_providers.dart';
import 'motion_providers.dart';

/// Provides a [Battery] instance.
final batteryProvider = Provider<Battery>((ref) {
  return Battery();
});

/// Provides the current battery level as a stream (0-100).
final batteryLevelStreamProvider = StreamProvider<int>((ref) async* {
  final battery = ref.watch(batteryProvider);

  // Emit initial level
  yield await battery.batteryLevel;

  // Then listen for state changes and re-query level
  await for (final _ in battery.onBatteryStateChanged) {
    yield await battery.batteryLevel;
  }
});

/// Whether the battery is below the low threshold (20%).
final isLowBatteryProvider = Provider<bool>((ref) {
  final levelAsync = ref.watch(batteryLevelStreamProvider);
  return levelAsync.whenOrNull(data: (level) => level < 20) ?? false;
});

/// Provides the [PassiveModeManager] implementation.
final passiveModeProvider = Provider<PassiveModeManager>((ref) {
  final motion = ref.watch(motionServiceProvider);
  final background = ref.watch(backgroundServiceProvider);
  final camera = ref.watch(cameraServiceProvider);
  final battery = ref.watch(batteryProvider);

  final sensorController = AdaptiveSensorController(
    cameraService: camera,
  );

  final manager = PassiveModeManagerImpl(
    motionService: motion,
    backgroundService: background,
    sensorController: sensorController,
    getBatteryLevel: () => battery.batteryLevel,
    batteryStream: () => battery.onBatteryStateChanged.asyncMap(
      (_) => battery.batteryLevel,
    ),
  );

  ref.onDispose(() {
    unawaited(manager.deactivate());
    manager.dispose();
  });

  return manager;
});
