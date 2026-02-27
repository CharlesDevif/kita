import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/sentence_buffer.dart';

void main() {
  group('SentenceBuffer', () {
    late List<String> emitted;
    late SentenceBuffer buffer;

    setUp(() {
      emitted = [];
      buffer = SentenceBuffer(onSentence: emitted.add);
    });

    test('emits sentence on period followed by space', () {
      buffer.add('Bonjour. ');
      expect(emitted, ['Bonjour.']);
    });

    test('emits sentence on period at end of token', () {
      buffer.add('Bonjour.');
      buffer.add(' Comment');
      expect(emitted, ['Bonjour.']);
    });

    test('emits on exclamation mark', () {
      buffer.add('Attention! ');
      expect(emitted, ['Attention!']);
    });

    test('emits on question mark', () {
      buffer.add('Comment tu t\'appelles? ');
      expect(emitted, ['Comment tu t\'appelles?']);
    });

    test('emits on newline', () {
      buffer.add('Premiere ligne\nDeuxieme');
      expect(emitted, ['Premiere ligne']);
    });

    test('accumulates tokens before boundary', () {
      buffer.add('Bon');
      buffer.add('jour');
      buffer.add('. ');
      expect(emitted, ['Bonjour.']);
    });

    test('emits multiple sentences', () {
      buffer.add('Bonjour. Je suis Kita. ');
      expect(emitted, ['Bonjour.', 'Je suis Kita.']);
    });

    test('flush emits remaining text', () {
      buffer.add('Texte incomplet');
      expect(emitted, isEmpty);
      buffer.flush();
      expect(emitted, ['Texte incomplet']);
    });

    test('flush does nothing when buffer is empty', () {
      buffer.flush();
      expect(emitted, isEmpty);
    });

    test('flush does nothing after sentence was emitted cleanly', () {
      buffer.add('Bonjour. ');
      emitted.clear();
      buffer.flush();
      expect(emitted, isEmpty);
    });

    test('ignores empty tokens', () {
      buffer.add('');
      buffer.add('Hello.');
      buffer.add('');
      buffer.add(' ');
      expect(emitted, ['Hello.']);
    });

    test('handles M. abbreviation', () {
      buffer.add('M. Dupont est la. ');
      // Should NOT split on "M." — should split on "la."
      expect(emitted, ['M. Dupont est la.']);
    });

    test('handles Mme. abbreviation', () {
      buffer.add('Mme. Martin arrive. ');
      expect(emitted, ['Mme. Martin arrive.']);
    });

    test('handles Dr. abbreviation', () {
      buffer.add('Dr. Smith parle. ');
      expect(emitted, ['Dr. Smith parle.']);
    });

    test('handles etc. abbreviation', () {
      buffer.add('fruits, legumes, etc. sont frais. ');
      expect(emitted, ['fruits, legumes, etc. sont frais.']);
    });

    test('handles token-by-token streaming', () {
      // Simulates real LLM output: one token at a time
      for (final token in ['Bon', 'jour', ' !', ' Je', ' suis', ' Kita', '.']) {
        buffer.add(token);
      }
      buffer.flush();
      expect(emitted, ['Bonjour !', 'Je suis Kita.']);
    });
  });
}
