import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';

/// Mock GemmaBridge for unit tests — no native dependencies needed.
class MockGemmaBridge implements GemmaBridge {
  GemmaModelStatus statusToReturn = GemmaModelStatus.error;
  GemmaCompletionResult? completionToReturn;
  GemmaVisionResult? visionToReturn;
  Exception? completionError;
  Exception? visionError;
  bool disposeCalled = false;
  int completeCallCount = 0;
  int completeStreamCallCount = 0;
  int describeCallCount = 0;
  String? lastPrompt;
  String? lastSystemPrompt;
  Uint8List? lastImageBytes;

  @override
  Future<GemmaModelStatus> checkStatus() async {
    return statusToReturn;
  }

  @override
  Future<GemmaCompletionResult> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    completeCallCount++;
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;

    if (completionError != null) throw completionError!;

    return completionToReturn ??
        const GemmaCompletionResult(text: '');
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async* {
    completeStreamCallCount++;
    lastPrompt = prompt;
    lastSystemPrompt = systemPrompt;

    if (completionError != null) throw completionError!;

    final text = completionToReturn?.text ?? '';
    if (text.isNotEmpty) {
      // Simulate token-by-token streaming by splitting on spaces.
      final words = text.split(' ');
      for (var i = 0; i < words.length; i++) {
        yield i == 0 ? words[i] : ' ${words[i]}';
      }
    }
  }

  @override
  Future<GemmaVisionResult> describeImage(
    Uint8List bytes, {
    String? prompt,
  }) async {
    describeCallCount++;
    lastImageBytes = bytes;
    lastPrompt = prompt;

    if (visionError != null) throw visionError!;

    return visionToReturn ??
        const GemmaVisionResult(description: '');
  }

  @override
  Stream<String> describeImageStream(
    Uint8List bytes, {
    String? prompt,
  }) async* {
    describeCallCount++;
    lastImageBytes = bytes;
    lastPrompt = prompt;

    if (visionError != null) throw visionError!;

    final description =
        (visionToReturn ?? const GemmaVisionResult(description: '')).description;
    if (description.isNotEmpty) {
      // Simulate token-by-token streaming by splitting on spaces.
      final words = description.split(' ');
      for (var i = 0; i < words.length; i++) {
        yield i == 0 ? words[i] : ' ${words[i]}';
      }
    }
  }

  @override
  Future<void> warmUp() async {
    // No-op in tests.
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}

void main() {
  group('GemmaModelStatus', () {
    test('has three values', () {
      expect(GemmaModelStatus.values, hasLength(3));
      expect(GemmaModelStatus.values, contains(GemmaModelStatus.ready));
      expect(GemmaModelStatus.values, contains(GemmaModelStatus.loading));
      expect(GemmaModelStatus.values, contains(GemmaModelStatus.error));
    });
  });

  group('GemmaCompletionResult', () {
    test('holds text', () {
      const result = GemmaCompletionResult(text: 'Hello world');
      expect(result.text, equals('Hello world'));
    });
  });

  group('GemmaVisionResult', () {
    test('holds description', () {
      const result = GemmaVisionResult(description: 'A cat sitting on a table');
      expect(result.description, equals('A cat sitting on a table'));
    });
  });

  group('MockGemmaBridge', () {
    late MockGemmaBridge mock;

    setUp(() {
      mock = MockGemmaBridge();
    });

    test('checkStatus returns configured status', () async {
      mock.statusToReturn = GemmaModelStatus.ready;
      expect(await mock.checkStatus(), equals(GemmaModelStatus.ready));
    });

    test('complete returns configured result', () async {
      mock.completionToReturn =
          const GemmaCompletionResult(text: 'Bonjour Marie');

      final result = await mock.complete('test prompt');
      expect(result.text, equals('Bonjour Marie'));
      expect(mock.completeCallCount, equals(1));
      expect(mock.lastPrompt, equals('test prompt'));
    });

    test('complete with system prompt', () async {
      mock.completionToReturn =
          const GemmaCompletionResult(text: '{"name": "Marie"}');

      await mock.complete(
        'user says hello',
        systemPrompt: 'Extract the name',
      );

      expect(mock.lastSystemPrompt, equals('Extract the name'));
    });

    test('complete throws configured error', () async {
      mock.completionError = Exception('Model crashed');

      expect(
        () => mock.complete('test'),
        throwsA(isA<Exception>()),
      );
    });

    test('describeImage returns configured result', () async {
      mock.visionToReturn = const GemmaVisionResult(
        description: 'Je vois une personne assise.',
      );

      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = await mock.describeImage(bytes, prompt: 'Decris');

      expect(result.description, contains('personne'));
      expect(mock.describeCallCount, equals(1));
      expect(mock.lastImageBytes, same(bytes));
      expect(mock.lastPrompt, equals('Decris'));
    });

    test('describeImage throws configured error', () async {
      mock.visionError = Exception('Vision failed');

      expect(
        () => mock.describeImage(Uint8List.fromList([1])),
        throwsA(isA<Exception>()),
      );
    });

    test('dispose sets flag', () async {
      await mock.dispose();
      expect(mock.disposeCalled, isTrue);
    });

    test('completeStream yields tokens from configured result', () async {
      mock.completionToReturn =
          const GemmaCompletionResult(text: 'Bonjour Marie');

      final tokens = await mock
          .completeStream('test prompt', systemPrompt: 'system')
          .toList();

      expect(tokens.join(), equals('Bonjour Marie'));
      expect(mock.completeStreamCallCount, equals(1));
      expect(mock.lastPrompt, equals('test prompt'));
      expect(mock.lastSystemPrompt, equals('system'));
    });

    test('completeStream throws configured error', () async {
      mock.completionError = Exception('Stream crashed');

      expect(
        () => mock.completeStream('test').toList(),
        throwsA(isA<Exception>()),
      );
    });

    test('completeStream yields nothing for empty result', () async {
      mock.completionToReturn = const GemmaCompletionResult(text: '');

      final tokens = await mock.completeStream('test').toList();
      expect(tokens, isEmpty);
    });
  });
}
