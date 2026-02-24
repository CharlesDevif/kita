import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

void main() {
  group('LocalProvider — Android (ML Kit)', () {
    late LocalProvider provider;

    setUp(() {
      provider = LocalProvider(platform: TargetPlatform.android);
    });

    test('has correct id and displayName for Android', () {
      expect(provider.id, equals('mlkit'));
      expect(provider.displayName, equals('ML Kit (Android)'));
    });

    test('tier is local', () {
      expect(provider.tier, equals(ProviderTier.local));
    });

    test('isAvailable is true on Android', () {
      expect(provider.isAvailable, isTrue);
    });

    test('complete returns degraded response', () async {
      final result = await provider.complete(
        const AIRequest(
          prompt: 'describe something',
          priority: RequestPriority.critical,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.status, equals(AIResponseStatus.degraded));
      expect(response.meta.providerId, equals('mlkit'));
      expect(response.meta.tier, equals(ProviderTier.local));
    });

    test('complete detects obstacle keywords', () async {
      final result = await provider.complete(
        const AIRequest(
          prompt: 'obstacle devant',
          priority: RequestPriority.critical,
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Attention'));
      expect(response.content, contains('Obstacle'));
    });

    test('complete detects text/read keywords', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'lis ce texte'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.content, contains('Texte'));
    });

    test('vision returns degraded response', () async {
      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'describe',
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.status, equals(AIResponseStatus.degraded));
      expect(response.meta.providerId, equals('mlkit'));
    });

    test('validateApiKey always succeeds (no key needed)', () async {
      final result = await provider.validateApiKey('anything');
      expect(result.isSuccess, isTrue);
    });
  });

  group('LocalProvider — iOS (CoreML)', () {
    late LocalProvider provider;

    setUp(() {
      provider = LocalProvider(platform: TargetPlatform.iOS);
    });

    test('has correct id and displayName for iOS', () {
      expect(provider.id, equals('coreml'));
      expect(provider.displayName, equals('CoreML (iOS)'));
    });

    test('isAvailable is true on iOS', () {
      expect(provider.isAvailable, isTrue);
    });

    test('complete works on iOS', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'test'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIResponse>).value;
      expect(response.meta.providerId, equals('coreml'));
    });
  });

  group('LocalProvider — unsupported platform', () {
    late LocalProvider provider;

    setUp(() {
      provider = LocalProvider(platform: TargetPlatform.linux);
    });

    test('has fallback id on unsupported platform', () {
      expect(provider.id, equals('local-fallback'));
    });

    test('isAvailable is false on unsupported platform', () {
      expect(provider.isAvailable, isFalse);
    });

    test('complete returns failure on unsupported platform', () async {
      final result = await provider.complete(
        const AIRequest(prompt: 'test'),
      );

      expect(result.isFailure, isTrue);
    });

    test('vision returns failure on unsupported platform', () async {
      final result = await provider.vision(
        ImageData(bytes: Uint8List.fromList([1, 2, 3])),
        'test',
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('performance', () {
    test('complete returns in < 50ms', () async {
      final provider = LocalProvider(platform: TargetPlatform.android);
      final sw = Stopwatch()..start();
      await provider.complete(
        const AIRequest(
          prompt: 'obstacle devant',
          priority: RequestPriority.critical,
        ),
      );
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });
}
