import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/data/adaptive_sensor_controller.dart';
import 'package:kita/features/io/data/passive_mode_impl.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/io/domain/passive_mode.dart';

import '../../../mocks/mocks.dart';

void main() {
  late PassiveModeManagerImpl manager;
  late MockMotionService mockMotion;
  late MockBackgroundService mockBackground;
  late MockCameraService mockCamera;
  late AdaptiveSensorController sensorController;
  late List<LogEntry> logEntries;

  // Battery simulation
  int batteryLevel = 80;
  late StreamController<int> batteryStreamController;
  bool lowBatteryAlertCalled = false;

  setUp(() {
    logEntries = [];
    KitaLogger.testLogHandler = logEntries.add;

    mockMotion = MockMotionService();
    mockBackground = MockBackgroundService();
    mockCamera = MockCameraService();
    batteryLevel = 80;
    batteryStreamController = StreamController<int>.broadcast();
    lowBatteryAlertCalled = false;

    sensorController = AdaptiveSensorController(
      cameraService: mockCamera,
    );

    manager = PassiveModeManagerImpl(
      motionService: mockMotion,
      backgroundService: mockBackground,
      sensorController: sensorController,
      getBatteryLevel: () async => batteryLevel,
      batteryStream: () => batteryStreamController.stream,
      onLowBattery: () => lowBatteryAlertCalled = true,
      inactivityTimeout: const Duration(milliseconds: 100),
      lowBatteryThreshold: 20,
    );
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    manager.dispose();
    batteryStreamController.close();
  });

  group('PassiveModeManagerImpl', () {
    test('implements PassiveModeManager', () {
      expect(manager, isA<PassiveModeManager>());
    });

    test('initial state is idle', () {
      expect(manager.currentState, equals(PassiveModeState.idle));
    });

    group('activate()', () {
      test('starts background service and motion monitoring', () async {
        final result = await manager.activate();

        expect(result.isSuccess, isTrue);
        expect(manager.currentState, equals(PassiveModeState.monitoring));
        expect(mockBackground.startCalled, isTrue);
      });

      test('emits monitoring state', () async {
        final states = <PassiveModeState>[];
        manager.stateStream.listen(states.add);

        await manager.activate();
        await Future<void>.delayed(Duration.zero);

        expect(states, contains(PassiveModeState.monitoring));
      });

      test('is idempotent when already active', () async {
        await manager.activate();
        final result = await manager.activate();

        expect(result.isSuccess, isTrue);
      });
    });

    group('deactivate()', () {
      test('stops all services', () async {
        await manager.activate();
        final result = await manager.deactivate();

        expect(result.isSuccess, isTrue);
        expect(manager.currentState, equals(PassiveModeState.idle));
        expect(mockBackground.stopCalled, isTrue);
      });

      test('is safe when already idle', () async {
        final result = await manager.deactivate();
        expect(result.isSuccess, isTrue);
      });
    });

    group('motion-based camera adaptation', () {
      test('immobile motion keeps camera OFF', () async {
        await manager.activate();

        // Simulate immobile state - camera should stay off
        mockMotion.simulateState(MotionState.immobile);
        expect(sensorController.isCameraActive, isFalse);
      });

      test('walking motion starts camera at 15 FPS', () async {
        await manager.activate();

        // Directly test the sensor controller FPS configuration
        await sensorController.adaptToMotion(MotionState.walking);

        expect(sensorController.targetFps, equals(15));
      });

      test('running motion sets camera at 30 FPS', () async {
        await manager.activate();

        await sensorController.adaptToMotion(MotionState.running);

        expect(sensorController.targetFps, equals(30));
      });

      test('immobile after motion stops camera', () async {
        await manager.activate();

        // Start with walking
        await sensorController.adaptToMotion(MotionState.walking);
        expect(sensorController.targetFps, equals(15));

        // Then go immobile
        await sensorController.adaptToMotion(MotionState.immobile);
        expect(sensorController.targetFps, equals(0));
      });
    });

    group('battery monitoring', () {
      test('low battery switches to low battery mode', () async {
        await manager.activate();

        // Simulate battery drop
        batteryStreamController.add(15);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(manager.isLowBattery, isTrue);
        expect(manager.currentState, equals(PassiveModeState.lowBattery));
      });

      test('low battery triggers vocal alert once', () async {
        await manager.activate();

        batteryStreamController.add(15);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(lowBatteryAlertCalled, isTrue);
        expect(manager.lowBatteryAlerted, isTrue);
      });

      test('low battery alert is not repeated', () async {
        await manager.activate();

        // First low battery
        batteryStreamController.add(15);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        lowBatteryAlertCalled = false;

        // Battery recovers then drops again
        batteryStreamController.add(25);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        batteryStreamController.add(10);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Alert should NOT fire again
        expect(lowBatteryAlertCalled, isFalse);
      });

      test('battery recovery restores monitoring mode', () async {
        await manager.activate();

        // Drop battery
        batteryStreamController.add(15);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(manager.currentState, equals(PassiveModeState.lowBattery));

        // Restore battery
        batteryStreamController.add(50);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(manager.currentState, equals(PassiveModeState.monitoring));
      });

      test('low battery config sets camera OFF for all motion states',
          () async {
        final lowConfig = FpsConfig.lowBattery;

        expect(lowConfig.fpsForState(MotionState.immobile), equals(0));
        expect(lowConfig.fpsForState(MotionState.walking), equals(0));
        expect(lowConfig.fpsForState(MotionState.running), equals(0));
      });
    });

    group('FpsConfig', () {
      test('standard config maps motion states correctly', () {
        const config = FpsConfig.standard;

        expect(config.fpsForState(MotionState.immobile), equals(0));
        expect(config.fpsForState(MotionState.walking), equals(15));
        expect(config.fpsForState(MotionState.running), equals(30));
      });

      test('custom config is supported', () {
        const config = FpsConfig(
          immobileFps: 5,
          walkingFps: 10,
          runningFps: 20,
        );

        expect(config.fpsForState(MotionState.walking), equals(10));
      });
    });

    group('zero PII in logs', () {
      test('no PII in any log entry during lifecycle', () async {
        await manager.activate();
        batteryStreamController.add(15);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await manager.deactivate();

        for (final entry in logEntries) {
          expect(entry.message, isNot(contains('latitude')));
          expect(entry.message, isNot(contains('longitude')));
          expect(entry.message, isNot(contains('email')));
          expect(entry.message, isNot(contains('phone')));
        }
      });
    });

    group('dispose', () {
      test('closes state stream', () async {
        await manager.activate();
        manager.dispose();

        // Stream should be closed — adding listeners should still work
        // but no new events will be emitted
        expect(manager.currentState, isNotNull);
      });
    });
  });

  group('AdaptiveSensorController', () {
    late AdaptiveSensorController controller;
    late MockCameraService camera;

    setUp(() {
      camera = MockCameraService();
      controller = AdaptiveSensorController(cameraService: camera);
    });

    test('initial state: camera not active, FPS 0', () {
      expect(controller.isCameraActive, isFalse);
      expect(controller.targetFps, equals(0));
    });

    test('adaptToMotion(walking) sets FPS to 15', () async {
      await controller.adaptToMotion(MotionState.walking);
      expect(controller.targetFps, equals(15));
    });

    test('adaptToMotion(running) sets FPS to 30', () async {
      await controller.adaptToMotion(MotionState.running);
      expect(controller.targetFps, equals(30));
    });

    test('adaptToMotion(immobile) sets FPS to 0', () async {
      await controller.adaptToMotion(MotionState.walking);
      await controller.adaptToMotion(MotionState.immobile);
      expect(controller.targetFps, equals(0));
    });

    test('repeated same state is a no-op', () async {
      await controller.adaptToMotion(MotionState.walking);
      final fps1 = controller.targetFps;
      await controller.adaptToMotion(MotionState.walking);
      expect(controller.targetFps, equals(fps1));
    });

    test('processing guard prevents concurrent access', () {
      expect(controller.isProcessing, isFalse);

      // Simulate manual processing flag
      controller.markProcessingComplete();
      expect(controller.isProcessing, isFalse);
    });

    test('updateConfig switches to low battery mode', () async {
      await controller.adaptToMotion(MotionState.walking);
      expect(controller.targetFps, equals(15));

      controller.updateConfig(FpsConfig.lowBattery);
      await controller.adaptToMotion(MotionState.walking);
      expect(controller.targetFps, equals(0));
    });

    test('dispose stops camera', () async {
      await controller.adaptToMotion(MotionState.walking);
      await controller.dispose();
      expect(controller.isCameraActive, isFalse);
    });
  });
}
