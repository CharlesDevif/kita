import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/ai_router.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_classifier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('AI domain interfaces', () {
    test('ProviderTier has 3 values', () {
      expect(ProviderTier.values, hasLength(3));
    });

    test('RequestPriority has 4 values', () {
      expect(RequestPriority.values, hasLength(4));
    });

    test('AIResponseStatus has 3 values', () {
      expect(AIResponseStatus.values, hasLength(3));
    });

    test('ImageData holds bytes and metadata', () {
      final data = ImageData(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 200,
      );
      expect(data.bytes, hasLength(3));
      expect(data.mimeType, equals('image/jpeg'));
      expect(data.width, equals(100));
    });

    test('AIRequest has required and optional fields', () {
      const request = AIRequest(prompt: 'Describe this');
      expect(request.prompt, equals('Describe this'));
      expect(request.priority, isNull);
      expect(request.imageData, isNull);
      expect(request.maxTokens, isNull);
    });

    test('AIResponse holds content and meta', () {
      const response = AIResponse(
        content: 'A park scene',
        meta: AIResponseMeta(
          providerId: 'claude',
          latency: Duration(milliseconds: 500),
          tier: ProviderTier.cloudPowerful,
        ),
        status: AIResponseStatus.success,
      );
      expect(response.content, equals('A park scene'));
      expect(response.meta.providerId, equals('claude'));
      expect(response.meta.cached, isFalse);
    });

    test('MockAIProvider implements AIProvider', () {
      final provider = MockAIProvider();
      expect(provider, isA<AIProvider>());
      expect(provider.id, isNotEmpty);
      expect(provider.isAvailable, isTrue);
    });

    test('MockAIProvider.complete returns success', () async {
      final provider = MockAIProvider();
      final result = await provider.complete(
        const AIRequest(prompt: 'Hello'),
      );
      expect(result.isSuccess, isTrue);
    });

    test('MockAIProvider.complete returns failure when configured', () async {
      final provider = MockAIProvider()..shouldFail = true;
      final result = await provider.complete(
        const AIRequest(prompt: 'Hello'),
      );
      expect(result.isFailure, isTrue);
    });

    test('MockAIRouter implements AIRouter', () {
      final router = MockAIRouter();
      expect(router, isA<AIRouter>());
    });

    test('MockRequestClassifier implements RequestClassifier', () {
      final classifier = MockRequestClassifier();
      expect(classifier, isA<RequestClassifier>());
      final result = classifier.classify('urgent help');
      expect(result.isSuccess, isTrue);
    });
  });
}
