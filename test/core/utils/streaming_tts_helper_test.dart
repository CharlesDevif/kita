import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/streaming_tts_helper.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';

void main() {
  group('streamToTTS', () {
    late _FakeTtsService fakeTts;

    setUp(() {
      fakeTts = _FakeTtsService();
    });

    test('speaks each sentence as it arrives', () async {
      final tokens = Stream.fromIterable([
        'Bonjour. ',
        'Je suis ',
        'Kita.',
      ]);

      final result = await streamToTTS(
        tokenStream: tokens,
        tts: fakeTts,
      );

      expect(result, 'Bonjour. Je suis Kita.');
      // "Bonjour." emitted as sentence, then "Je suis Kita." flushed
      expect(fakeTts.spokenTexts, ['Bonjour.', 'Je suis Kita.']);
    });

    test('returns full text even with single sentence', () async {
      final tokens = Stream.fromIterable(['Hello world']);

      final result = await streamToTTS(
        tokenStream: tokens,
        tts: fakeTts,
      );

      expect(result, 'Hello world');
      expect(fakeTts.spokenTexts, ['Hello world']);
    });

    test('handles empty stream', () async {
      final tokens = const Stream<String>.empty();

      final result = await streamToTTS(
        tokenStream: tokens,
        tts: fakeTts,
      );

      expect(result, '');
      expect(fakeTts.spokenTexts, isEmpty);
    });

    test('speaks multiple sentences across tokens', () async {
      final tokens = Stream.fromIterable([
        'Pre',
        'miere phrase. ',
        'Deuxieme! ',
        'Et la troisieme?',
      ]);

      final result = await streamToTTS(
        tokenStream: tokens,
        tts: fakeTts,
      );

      expect(result, 'Premiere phrase. Deuxieme! Et la troisieme?');
      expect(fakeTts.spokenTexts, [
        'Premiere phrase.',
        'Deuxieme!',
        'Et la troisieme?',
      ]);
    });
  });
}

class _FakeTtsService implements TTSService {
  final List<String> spokenTexts = [];

  @override
  bool get isSpeaking => false;

  @override
  Stream<TtsSpeechEvent> get speechEvents => const Stream.empty();

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    return const Result.success(null);
  }
}
