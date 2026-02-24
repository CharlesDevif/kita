import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/haptic_service_impl.dart';
import 'package:kita/features/io/domain/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticServiceImpl', () {
    late HapticServiceImpl service;
    late List<MethodCall> channelCalls;

    setUp(() {
      channelCalls = [];

      // Mock the com.kita/haptic channel.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.kita/haptic'),
        (MethodCall methodCall) async {
          channelCalls.add(methodCall);
          return null;
        },
      );

      service = HapticServiceImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.kita/haptic'),
        null,
      );
    });

    test('implements HapticService interface', () {
      expect(service, isA<HapticService>());
    });

    test('trigger info sends correct pattern', () async {
      final result = await service.trigger(HapticPattern.info);
      expect(result.isSuccess, isTrue);
      expect(channelCalls, hasLength(1));
      expect(channelCalls.first.method, equals('triggerPattern'));
      expect(channelCalls.first.arguments, equals({'pattern': 'info'}));
    });

    test('trigger warning sends correct pattern', () async {
      final result = await service.trigger(HapticPattern.warning);
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'warning'}));
    });

    test('trigger danger sends correct pattern', () async {
      final result = await service.trigger(HapticPattern.danger);
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'danger'}));
    });

    test('trigger confirmation sends correct pattern', () async {
      final result = await service.trigger(HapticPattern.confirmation);
      expect(result.isSuccess, isTrue);
      expect(
          channelCalls.first.arguments, equals({'pattern': 'confirmation'}));
    });

    test('trigger custom sends correct pattern', () async {
      final result = await service.trigger(HapticPattern.custom);
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'custom'}));
    });

    test('info() delegates to trigger(HapticPattern.info)', () async {
      final result = await service.info();
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'info'}));
    });

    test('warning() delegates to trigger(HapticPattern.warning)', () async {
      final result = await service.warning();
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'warning'}));
    });

    test('danger() delegates to trigger(HapticPattern.danger)', () async {
      final result = await service.danger();
      expect(result.isSuccess, isTrue);
      expect(channelCalls.first.arguments, equals({'pattern': 'danger'}));
    });

    test('all 3 patterns produce different channel arguments', () async {
      await service.info();
      await service.warning();
      await service.danger();

      expect(channelCalls, hasLength(3));
      final patterns =
          channelCalls.map((c) => (c.arguments as Map)['pattern']).toList();
      expect(patterns, equals(['info', 'warning', 'danger']));
    });
  });

  group('HapticServiceImpl fallback', () {
    test('falls back gracefully when channel unavailable', () async {
      // Don't register mock — will trigger MissingPluginException -> fallback
      final service = HapticServiceImpl();
      final result = await service.trigger(HapticPattern.info);
      // Fallback should still succeed (haptic is non-critical)
      expect(result.isSuccess, isTrue);
    });
  });
}
