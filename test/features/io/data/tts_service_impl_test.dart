import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/features/io/data/tts_service_impl.dart';
import 'package:kita/features/io/domain/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TTSServiceImpl', () {
    late TTSServiceImpl service;

    setUp(() {
      // Register a fake handler for flutter_tts method channel
      // to prevent MissingPluginException errors.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'setLanguage':
            case 'setSpeechRate':
            case 'setVolume':
            case 'awaitSpeakCompletion':
            case 'stop':
            case 'setEngine':
              return 1;
            case 'speak':
              return 1;
            case 'getDefaultEngine':
              return 'com.google.android.tts';
            case 'getEngines':
              return <String>['com.google.android.tts'];
            default:
              return null;
          }
        },
      );
      service = TTSServiceImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        null,
      );
    });

    test('implements TTSService interface', () {
      expect(service, isA<TTSService>());
    });

    test('isSpeaking is false initially', () {
      expect(service.isSpeaking, isFalse);
    });

    test('currentPriority is null when not speaking', () {
      expect(service.currentPriority, isNull);
    });

    test('language defaults to fr-FR', () {
      expect(service.language, equals('fr-FR'));
    });

    test('language can be configured', () {
      final custom = TTSServiceImpl(language: 'en-US');
      expect(custom.language, equals('en-US'));
    });

    test('speak initializes and queues message', () async {
      final result = await service.speak('Bonjour');
      expect(result.isSuccess, isTrue);
    });

    test('stop succeeds when not speaking', () async {
      final result = await service.stop();
      expect(result.isSuccess, isTrue);
    });

    test('TTSPriority order is critical < urgent < standard', () {
      expect(TTSPriority.critical.index, lessThan(TTSPriority.urgent.index));
      expect(TTSPriority.urgent.index, lessThan(TTSPriority.standard.index));
    });

    test('speak with priority parameter accepted', () async {
      final result = await service.speak(
        'Alerte critique',
        priority: TTSPriority.critical,
      );
      expect(result.isSuccess, isTrue);
    });

    test('returns Result types from all methods', () async {
      final speakResult = await service.speak('test');
      expect(speakResult.isSuccess || speakResult.isFailure, isTrue);

      final stopResult = await service.stop();
      expect(stopResult.isSuccess || stopResult.isFailure, isTrue);
    });

    test('lastSpeechCompletedAt is null initially', () {
      expect(service.lastSpeechCompletedAt, isNull);
    });
  });
}
