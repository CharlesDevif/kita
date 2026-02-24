import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/audio_service_impl.dart';
import 'package:kita/features/io/domain/audio_service.dart';

import '../../../mocks/mock_stt_service.dart';

void main() {
  group('AudioMultiplexerImpl', () {
    late AudioMultiplexerImpl multiplexer;
    late MockSTTService mockSTT;

    setUp(() {
      mockSTT = MockSTTService();
      multiplexer = AudioMultiplexerImpl(sttService: mockSTT);
    });

    test('implements AudioService interface', () {
      expect(multiplexer, isA<AudioService>());
    });

    test('starts in idle mode', () {
      expect(multiplexer.currentMode, equals(AudioMode.idle));
      expect(multiplexer.isListening, isFalse);
    });

    test('startSTT switches to STT mode', () async {
      final result =
          await multiplexer.startSTT(onResult: (transcript, isFinal) {});
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.stt));
      expect(multiplexer.isListening, isTrue);
    });

    test('stopSTT returns to idle mode', () async {
      await multiplexer.startSTT(onResult: (transcript, isFinal) {});
      final result = await multiplexer.stopSTT();
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.idle));
    });

    test('startListening switches to ambient mode', () async {
      final result = await multiplexer.startListening();
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.ambient));
      expect(multiplexer.isListening, isTrue);
    });

    test('stopListening returns to idle mode', () async {
      await multiplexer.startListening();
      final result = await multiplexer.stopListening();
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.idle));
      expect(multiplexer.isListening, isFalse);
    });

    test('STT has priority over ambient', () async {
      // Start ambient first
      await multiplexer.startListening(onData: (_) {});
      expect(multiplexer.currentMode, equals(AudioMode.ambient));

      // Start STT — should preempt ambient
      final result =
          await multiplexer.startSTT(onResult: (transcript, isFinal) {});
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.stt));
    });

    test('ambient is queued when STT is active', () async {
      // Start STT first
      await multiplexer.startSTT(onResult: (transcript, isFinal) {});

      // Try to start ambient — should be queued
      final result = await multiplexer.startListening(onData: (_) {});
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.stt));
    });

    test('ambient resumes after STT stops', () async {
      // Start STT
      await multiplexer.startSTT(onResult: (transcript, isFinal) {});

      // Queue ambient
      await multiplexer.startListening(onData: (_) {});
      expect(multiplexer.currentMode, equals(AudioMode.stt));

      // Stop STT — ambient should resume
      await multiplexer.stopSTT();
      expect(multiplexer.currentMode, equals(AudioMode.ambient));
    });

    test('duplicate startSTT is ignored', () async {
      await multiplexer.startSTT(onResult: (transcript, isFinal) {});
      final result =
          await multiplexer.startSTT(onResult: (transcript, isFinal) {});
      expect(result.isSuccess, isTrue);
      expect(multiplexer.currentMode, equals(AudioMode.stt));
    });

    test('stopSTT when not in STT mode is safe', () async {
      final result = await multiplexer.stopSTT();
      expect(result.isSuccess, isTrue);
    });

    test('stopListening when not listening is safe', () async {
      final result = await multiplexer.stopListening();
      expect(result.isSuccess, isTrue);
    });
  });
}
