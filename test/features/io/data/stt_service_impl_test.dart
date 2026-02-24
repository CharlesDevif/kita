import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/features/io/data/stt_service_impl.dart';
import 'package:kita/features/io/domain/stt_service.dart';

void main() {
  group('STTServiceImpl', () {
    late STTServiceImpl service;

    setUp(() {
      service = STTServiceImpl();
    });

    test('implements STTService interface', () {
      expect(service, isA<STTService>());
    });

    test('isAvailable is false before initialization', () {
      expect(service.isAvailable, isFalse);
    });

    test('isListening is false initially', () {
      expect(service.isListening, isFalse);
    });

    test('localeId defaults to fr_FR', () {
      expect(service.localeId, equals('fr_FR'));
    });

    test('localeId can be configured', () {
      final customService = STTServiceImpl(localeId: 'en_US');
      expect(customService.localeId, equals('en_US'));
    });

    test('startRecognition returns failure when platform unavailable',
        () async {
      // In test environment, SpeechToText.initialize() fails due to missing plugin
      final result = await service.startRecognition(
        onResult: (transcript, isFinal) {},
      );
      expect(result.isFailure, isTrue);

      result.when(
        success: (_) => fail('Expected failure'),
        failure: (failure) {
          expect(failure, isA<KitaFailure>());
          expect(failure.logMessage, isNotEmpty);
        },
      );
    });

    test('stopRecognition succeeds when not listening', () async {
      final result = await service.stopRecognition();
      expect(result.isSuccess, isTrue);
    });

    test('returns Result type from all methods', () async {
      final startResult = await service.startRecognition(
        onResult: (_, __) {},
      );
      expect(startResult.isSuccess || startResult.isFailure, isTrue);

      final stopResult = await service.stopRecognition();
      expect(stopResult.isSuccess || stopResult.isFailure, isTrue);
    });
  });
}
