import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/data/adaptive_sensor_controller.dart';
import 'package:kita/features/io/data/passive_mode_impl.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/io/domain/passive_mode.dart';

import '../mocks/mock_background_service.dart';
import '../mocks/mock_camera_service.dart';
import '../mocks/mock_motion_service.dart';

/// Phase 4 Integration Gate — AC3: Passive mode stability (simulated 1h)
///
/// Simulates 1 hour of passive mode operation:
/// - Advances through 12 x 5-minute increments
/// - Varies motion state (immobile / walking / running)
/// - Varies battery level (including low battery episodes)
/// - Verifies: 0 exceptions, no memory leaks (lists/maps don't grow unbounded),
///   subscriptions are properly managed.
///
/// NOTE: RAM < 200 MB is a device-only metric, not measurable in unit tests.
void main() {
  late PassiveModeManagerImpl manager;
  late MockMotionService mockMotion;
  late MockBackgroundService mockBackground;
  late MockCameraService mockCamera;
  late AdaptiveSensorController sensorController;
  late StreamController<int> batteryStreamController;
  late List<LogEntry> logEntries;
  late List<PassiveModeState> stateHistory;

  int batteryLevel = 80;
  int lowBatteryAlertCount = 0;

  setUp(() {
    logEntries = [];
    stateHistory = [];
    lowBatteryAlertCount = 0;
    batteryLevel = 80;
    KitaLogger.testLogHandler = logEntries.add;

    mockMotion = MockMotionService();
    mockBackground = MockBackgroundService();
    mockCamera = MockCameraService();
    batteryStreamController = StreamController<int>.broadcast();

    sensorController = AdaptiveSensorController(
      cameraService: mockCamera,
    );

    manager = PassiveModeManagerImpl(
      motionService: mockMotion,
      backgroundService: mockBackground,
      sensorController: sensorController,
      getBatteryLevel: () async => batteryLevel,
      batteryStream: () => batteryStreamController.stream,
      onLowBattery: () => lowBatteryAlertCount++,
      inactivityTimeout: const Duration(seconds: 30),
      lowBatteryThreshold: 20,
    );

    // Track state changes
    manager.stateStream.listen(stateHistory.add);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    manager.dispose();
    batteryStreamController.close();
  });

  group('Phase 4 Gate — AC3: Passive mode stability (simulated 1h)', () {
    test('activation starts successfully', () async {
      final result = await manager.activate();
      expect(result.isSuccess, isTrue);
      expect(manager.currentState, PassiveModeState.monitoring);
    });

    test('simulated 1h with motion cycles — 0 exceptions', () async {
      // Activate passive mode
      final activateResult = await manager.activate();
      expect(activateResult.isSuccess, isTrue);

      int exceptionCount = 0;

      // Simulate 12 x 5-minute cycles (= 1 hour)
      for (var cycle = 0; cycle < 12; cycle++) {
        try {
          // Each 5-minute cycle: vary motion state
          final motionSequence = [
            MotionState.immobile,
            MotionState.walking,
            MotionState.running,
            MotionState.walking,
            MotionState.immobile,
          ];

          for (final motion in motionSequence) {
            // Simulate motion through the manager (not directly on sensor controller)
            mockMotion.simulateState(motion);

            // Let microtasks settle (manager uses unawaited futures)
            await Future<void>.delayed(Duration.zero);
          }

          // Vary battery level realistically over the hour
          if (cycle < 6) {
            // First 30 min: battery draining normally
            batteryLevel = 80 - (cycle * 5);
            batteryStreamController.add(batteryLevel);
          } else if (cycle == 6) {
            // 30 min mark: battery hits low threshold
            batteryLevel = 18;
            batteryStreamController.add(batteryLevel);
          } else if (cycle == 8) {
            // 40 min mark: plugged in, battery recovering
            batteryLevel = 25;
            batteryStreamController.add(batteryLevel);
          } else {
            // Remaining cycles: battery stable
            batteryLevel = 30 + (cycle - 8) * 5;
            batteryStreamController.add(batteryLevel);
          }

          await Future<void>.delayed(Duration.zero);
        } catch (e) {
          exceptionCount++;
        }
      }

      expect(exceptionCount, 0,
          reason: '0 exceptions during 1h simulation');

      // Verify manager is still in a valid state
      expect(
        manager.currentState,
        anyOf(PassiveModeState.monitoring, PassiveModeState.lowBattery),
      );
    });

    test('no unbounded list/map growth (memory leak check)', () async {
      await manager.activate();

      // Record initial state
      final initialLogCount = logEntries.length;
      final initialStateCount = stateHistory.length;

      // Run 20 rapid motion cycles through the manager
      for (var i = 0; i < 20; i++) {
        mockMotion.simulateState(MotionState.walking);
        await Future<void>.delayed(Duration.zero);

        mockMotion.simulateState(MotionState.immobile);
        await Future<void>.delayed(Duration.zero);
      }

      // Verify logs grow linearly (not exponentially)
      // Each cycle generates ~4 log entries (start camera, fps changed,
      // stop camera, fps changed). Total should be bounded.
      final logGrowth = logEntries.length - initialLogCount;
      expect(logGrowth, lessThan(200),
          reason: 'Log growth should be bounded and linear');

      // State history should not grow unboundedly
      // Only unique state transitions should be recorded
      final stateGrowth = stateHistory.length - initialStateCount;
      expect(stateGrowth, lessThan(100),
          reason: 'State history should be bounded');
    });

    test('subscriptions properly managed after deactivate', () async {
      await manager.activate();

      // Verify active state
      expect(manager.currentState, PassiveModeState.monitoring);

      // Deactivate
      final deactivateResult = await manager.deactivate();
      expect(deactivateResult.isSuccess, isTrue);
      expect(manager.currentState, PassiveModeState.idle);

      // Flush any pending microtasks from deactivation
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateCountBefore = stateHistory.length;

      // After deactivation, battery events should not cause state changes
      batteryStreamController.add(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No new state changes after deactivation
      // The subscription was cancelled, so battery events are ignored
      expect(stateHistory.length, stateCountBefore,
          reason: 'No state changes after deactivation');
    });

    test('low battery alert fires once per session', () async {
      await manager.activate();

      // Drop battery below threshold
      batteryStreamController.add(15);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(lowBatteryAlertCount, 1);

      // Battery recovers
      batteryStreamController.add(25);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Drop again — alert should NOT fire again
      batteryStreamController.add(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(lowBatteryAlertCount, 1,
          reason: 'Alert fires only once per session');
    });

    test('reactivation after deactivation works cleanly', () async {
      // First activation
      await manager.activate();
      expect(manager.currentState, PassiveModeState.monitoring);

      // Deactivation
      await manager.deactivate();
      expect(manager.currentState, PassiveModeState.idle);

      // Re-create manager for clean state (simulates app restart)
      manager.dispose();
      batteryStreamController.close();
      batteryStreamController = StreamController<int>.broadcast();
      batteryLevel = 75;

      sensorController = AdaptiveSensorController(
        cameraService: mockCamera,
      );

      manager = PassiveModeManagerImpl(
        motionService: mockMotion,
        backgroundService: mockBackground,
        sensorController: sensorController,
        getBatteryLevel: () async => batteryLevel,
        batteryStream: () => batteryStreamController.stream,
        onLowBattery: () => lowBatteryAlertCount++,
        inactivityTimeout: const Duration(seconds: 30),
        lowBatteryThreshold: 20,
      );

      // Second activation should work
      final result = await manager.activate();
      expect(result.isSuccess, isTrue);
      expect(manager.currentState, PassiveModeState.monitoring);
    });

    test('rapid motion transitions do not cause race conditions', () async {
      await manager.activate();

      // Rapid fire motion transitions through the manager
      // (simulates jitter in accelerometer)
      for (var i = 0; i < 50; i++) {
        final motions = [
          MotionState.immobile,
          MotionState.walking,
          MotionState.running,
        ];
        final motion = motions[i % 3];
        mockMotion.simulateState(motion);
        await Future<void>.delayed(Duration.zero);
      }

      // Manager should still be in a valid state
      expect(
        manager.currentState,
        anyOf(
          PassiveModeState.monitoring,
          PassiveModeState.lowBattery,
        ),
      );

      // Sensor controller should be consistent
      expect(sensorController.targetFps, isNonNegative);
    });

    test('zero PII in all log entries during full lifecycle', () async {
      await manager.activate();

      // Simulate various states
      batteryStreamController.add(15);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      batteryStreamController.add(50);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      mockMotion.simulateState(MotionState.walking);
      await Future<void>.delayed(Duration.zero);
      mockMotion.simulateState(MotionState.immobile);
      await Future<void>.delayed(Duration.zero);

      await manager.deactivate();

      // Check all log entries for PII
      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('phone')));
        expect(entry.message, isNot(contains('name')),
            reason: 'No user names in logs: ${entry.message}');
      }
    });
  });
}
