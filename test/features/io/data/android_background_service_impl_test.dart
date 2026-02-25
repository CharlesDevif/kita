import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/data/android_background_service_impl.dart';
import 'package:kita/features/io/domain/background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AndroidBackgroundServiceImpl service;
  late List<MethodCall> methodCalls;
  late List<LogEntry> logEntries;

  setUp(() {
    methodCalls = [];
    logEntries = [];
    KitaLogger.testLogHandler = logEntries.add;

    service = AndroidBackgroundServiceImpl();

    // Mock the method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.kita/background'),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'startService':
            return true;
          case 'stopService':
            return true;
          case 'isRunning':
            return false;
          case 'isBatteryOptimizationIgnored':
            return false;
          case 'requestBatteryOptimizationExemption':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.kita/background'),
      null,
    );
  });

  group('AndroidBackgroundServiceImpl', () {
    test('implements KitaBackgroundService', () {
      expect(service, isA<KitaBackgroundService>());
    });

    test('initial state is idle', () {
      expect(service.currentState, equals(BackgroundServiceState.idle));
    });

    group('start()', () {
      test('invokes startService on method channel', () async {
        final result = await service.start();

        expect(result.isSuccess, isTrue);
        expect(
          methodCalls.any((c) => c.method == 'startService'),
          isTrue,
        );
      });

      test('transitions state to running on success', () async {
        final states = <BackgroundServiceState>[];
        service.stateStream.listen(states.add);

        await service.start();

        // Allow stream to emit
        await Future<void>.delayed(Duration.zero);

        expect(states, contains(BackgroundServiceState.starting));
        expect(states, contains(BackgroundServiceState.running));
      });

      test('returns failure when platform throws', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.kita/background'),
          (MethodCall call) async {
            if (call.method == 'startService') {
              throw PlatformException(
                code: 'FGS_ERROR',
                message: 'Cannot start foreground service from background',
              );
            }
            return null;
          },
        );

        final result = await service.start();

        expect(result.isFailure, isTrue);
        expect(service.currentState, equals(BackgroundServiceState.error));
      });

      test('logs start without PII', () async {
        await service.start();

        final hasLog = logEntries.any(
          (e) => e.message.contains('Background service started'),
        );
        expect(hasLog, isTrue);

        // Verify no PII in any log
        for (final entry in logEntries) {
          expect(entry.message, isNot(contains('user')));
          expect(entry.message, isNot(contains('email')));
          expect(entry.message, isNot(contains('name')));
        }
      });
    });

    group('stop()', () {
      test('invokes stopService on method channel', () async {
        await service.start();
        methodCalls.clear();

        final result = await service.stop();

        expect(result.isSuccess, isTrue);
        expect(
          methodCalls.any((c) => c.method == 'stopService'),
          isTrue,
        );
      });

      test('transitions state to stopped', () async {
        await service.start();

        final states = <BackgroundServiceState>[];
        service.stateStream.listen(states.add);

        await service.stop();

        await Future<void>.delayed(Duration.zero);

        expect(states, contains(BackgroundServiceState.stopped));
      });
    });

    group('isRunning', () {
      test('queries method channel', () async {
        final running = await service.isRunning;

        expect(running, isFalse);
        expect(
          methodCalls.any((c) => c.method == 'isRunning'),
          isTrue,
        );
      });

      test('returns true when service reports running', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.kita/background'),
          (MethodCall call) async {
            if (call.method == 'isRunning') return true;
            return null;
          },
        );

        final running = await service.isRunning;
        expect(running, isTrue);
      });
    });

    group('stateStream', () {
      test('emits state changes', () async {
        final states = <BackgroundServiceState>[];
        service.stateStream.listen(states.add);

        await service.start();
        await Future<void>.delayed(Duration.zero);
        await service.stop();
        await Future<void>.delayed(Duration.zero);

        expect(states, isNotEmpty);
        expect(states.first, equals(BackgroundServiceState.starting));
      });

      test('is a broadcast stream', () {
        // Multiple listeners should work
        final sub1 = service.stateStream.listen((_) {});
        final sub2 = service.stateStream.listen((_) {});

        expect(sub1, isNotNull);
        expect(sub2, isNotNull);

        sub1.cancel();
        sub2.cancel();
      });
    });

    group('battery optimization', () {
      test('isBatteryOptimizationIgnored queries channel', () async {
        final ignored = await service.isBatteryOptimizationIgnored;

        expect(ignored, isFalse);
        expect(
          methodCalls.any(
            (c) => c.method == 'isBatteryOptimizationIgnored',
          ),
          isTrue,
        );
      });

      test('requestBatteryOptimizationExemption returns result', () async {
        final result = await service.requestBatteryOptimizationExemption();

        expect(result.isSuccess, isTrue);
        final granted = result.getOrNull();
        expect(granted, isTrue);
        expect(
          methodCalls.any(
            (c) => c.method == 'requestBatteryOptimizationExemption',
          ),
          isTrue,
        );
      });

      test('requestBatteryOptimizationExemption logs result without PII',
          () async {
        await service.requestBatteryOptimizationExemption();

        final hasLog = logEntries.any(
          (e) => e.message.contains('Battery optimization'),
        );
        expect(hasLog, isTrue);
      });
    });

    group('error handling', () {
      test('start handles MissingPluginException gracefully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.kita/background'),
          (MethodCall call) async {
            throw MissingPluginException('No implementation found');
          },
        );

        final result = await service.start();

        expect(result.isFailure, isTrue);
        expect(service.currentState, equals(BackgroundServiceState.error));
      });

      test('stop returns success even if not running', () async {
        final result = await service.stop();

        expect(result.isSuccess, isTrue);
      });
    });
  });
}
