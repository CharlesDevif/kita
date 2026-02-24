import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/features/io/data/camera_service_impl.dart';
import 'package:kita/features/io/domain/camera_service.dart';

void main() {
  group('CameraServiceImpl', () {
    late CameraServiceImpl service;

    setUp(() {
      service = CameraServiceImpl();
    });

    test('implements CameraService interface', () {
      expect(service, isA<CameraService>());
    });

    test('isAvailable is false before initialization', () {
      expect(service.isAvailable, isFalse);
    });

    test('isStreaming is false initially', () {
      expect(service.isStreaming, isFalse);
    });

    test('streamFps defaults to 15', () {
      expect(service.streamFps, equals(15));
    });

    test('streamFps can be configured', () {
      final customService = CameraServiceImpl(streamFps: 30);
      expect(customService.streamFps, equals(30));
    });

    test('capturePhoto returns failure when no camera available', () async {
      // In test environment, availableCameras() throws MissingPluginException
      // because there is no platform channel registered.
      final result = await service.capturePhoto();
      expect(result.isFailure, isTrue);

      result.when(
        success: (_) => fail('Expected failure'),
        failure: (failure) {
          expect(failure, isA<KitaFailure>());
          expect(failure.logMessage, isNotEmpty);
        },
      );
    });

    test('startStream returns failure when no camera available', () async {
      final frames = <dynamic>[];
      final result = await service.startStream((frame) => frames.add(frame));

      expect(result.isFailure, isTrue);
      expect(frames, isEmpty);
    });

    test('stopStream succeeds when not streaming', () async {
      final result = await service.stopStream();
      expect(result.isSuccess, isTrue);
    });

    test('dispose can be called safely when not initialized', () async {
      await service.dispose();
      expect(service.isAvailable, isFalse);
    });

    test('dispose can be called multiple times safely', () async {
      await service.dispose();
      await service.dispose();
      expect(service.isAvailable, isFalse);
    });
  });

  group('CameraServiceImpl with MockCameraService contract', () {
    // Verify the implementation follows the same contract as the mock
    test('returns Result type from capturePhoto', () async {
      final service = CameraServiceImpl();
      final result = await service.capturePhoto();
      // Result is always returned, never throws
      expect(result.isSuccess || result.isFailure, isTrue);
    });

    test('returns Result type from startStream', () async {
      final service = CameraServiceImpl();
      final result = await service.startStream((_) {});
      expect(result.isSuccess || result.isFailure, isTrue);
    });

    test('returns Result type from stopStream', () async {
      final service = CameraServiceImpl();
      final result = await service.stopStream();
      expect(result.isSuccess || result.isFailure, isTrue);
    });
  });
}
