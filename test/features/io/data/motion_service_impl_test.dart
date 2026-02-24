import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/motion_service_impl.dart';
import 'package:kita/features/io/domain/motion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionServiceImpl', () {
    late MotionServiceImpl service;

    setUp(() {
      // Mock the sensors_plus method channel to prevent MissingPluginException.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
        (MethodCall methodCall) async {
          return null;
        },
      );
      service = MotionServiceImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
        null,
      );
    });

    test('implements MotionService interface', () {
      expect(service, isA<MotionService>());
    });

    test('starts with immobile state', () {
      expect(service.currentState, equals(MotionState.immobile));
    });

    test('thresholds have sensible defaults', () {
      expect(service.immobileThreshold, equals(1.5));
      expect(service.runningThreshold, equals(5.0));
      expect(service.sampleSize, equals(10));
    });

    test('thresholds are configurable', () {
      final custom = MotionServiceImpl(
        immobileThreshold: 2.0,
        runningThreshold: 8.0,
        sampleSize: 20,
      );
      expect(custom.immobileThreshold, equals(2.0));
      expect(custom.runningThreshold, equals(8.0));
      expect(custom.sampleSize, equals(20));
    });

    test('stopMonitoring succeeds when not monitoring', () async {
      final result = await service.stopMonitoring();
      expect(result.isSuccess, isTrue);
    });

    test('stopMonitoring can be called multiple times', () async {
      await service.stopMonitoring();
      final result = await service.stopMonitoring();
      expect(result.isSuccess, isTrue);
    });

    test('MotionState has 3 values', () {
      expect(MotionState.values, hasLength(3));
      expect(MotionState.values, contains(MotionState.immobile));
      expect(MotionState.values, contains(MotionState.walking));
      expect(MotionState.values, contains(MotionState.running));
    });

    test('MotionState enum ordering', () {
      expect(MotionState.immobile.index, equals(0));
      expect(MotionState.walking.index, equals(1));
      expect(MotionState.running.index, equals(2));
    });
  });
}
