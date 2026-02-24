import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/domain/audio_service.dart';
import 'package:kita/features/io/domain/camera_service.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/io/domain/stt_service.dart';
import 'package:kita/features/io/domain/tts_service.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('I/O domain interfaces', () {
    test('HapticPattern has 5 values', () {
      expect(HapticPattern.values, hasLength(5));
    });

    test('TTSPriority has 3 values', () {
      expect(TTSPriority.values, hasLength(3));
    });

    test('MotionState has 3 values', () {
      expect(MotionState.values, hasLength(3));
    });

    test('Position holds coordinates', () {
      const pos = Position(latitude: 48.8566, longitude: 2.3522);
      expect(pos.latitude, equals(48.8566));
      expect(pos.altitude, isNull);
    });

    test('GeoAddress holds address components', () {
      const addr = GeoAddress(city: 'Paris', country: 'France');
      expect(addr.city, equals('Paris'));
      expect(addr.street, isNull);
    });

    test('POI holds name and position', () {
      const poi = POI(
        name: 'Tour Eiffel',
        position: Position(latitude: 48.8584, longitude: 2.2945),
      );
      expect(poi.name, equals('Tour Eiffel'));
    });

    test('MockCameraService implements CameraService', () {
      final service = MockCameraService();
      expect(service, isA<CameraService>());
      expect(service.isAvailable, isTrue);
    });

    test('MockCameraService.capturePhoto returns ImageData', () async {
      final service = MockCameraService();
      final result = await service.capturePhoto();
      expect(result.isSuccess, isTrue);
    });

    test('MockSTTService implements STTService', () {
      final service = MockSTTService();
      expect(service, isA<STTService>());
      expect(service.isListening, isFalse);
    });

    test('MockTTSService implements TTSService', () {
      final service = MockTTSService();
      expect(service, isA<TTSService>());
      expect(service.isSpeaking, isFalse);
    });

    test('MockHapticService implements HapticService', () async {
      final service = MockHapticService();
      expect(service, isA<HapticService>());
      await service.info();
      expect(service.lastPattern, equals(HapticPattern.info));
    });

    test('MockAudioService implements AudioService', () {
      final service = MockAudioService();
      expect(service, isA<AudioService>());
      expect(service.isListening, isFalse);
    });

    test('MockLocationService implements LocationService', () async {
      final service = MockLocationService();
      expect(service, isA<LocationService>());
      final result = await service.getCurrentPosition();
      expect(result.isSuccess, isTrue);
    });

    test('MockMotionService implements MotionService', () {
      final service = MockMotionService();
      expect(service, isA<MotionService>());
      expect(service.currentState, equals(MotionState.immobile));
      service.simulateState(MotionState.walking);
      expect(service.currentState, equals(MotionState.walking));
    });
  });
}
