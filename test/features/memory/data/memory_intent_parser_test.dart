import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/memory/data/memory_intent_parser.dart';
import 'package:kita/features/memory/domain/memory_intent.dart';

void main() {
  group('normalizeForMatch', () {
    test('préserve la longueur, caractère par caractère', () {
      const samples = [
        'Retiens que mon frère s\'appelle Paul',
        'ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ',
        'àâäçéèêëîïôöùûüÿ',
        'Ça déménage, où ?',
        'qu’est-ce que j’ai vu',
      ];
      for (final s in samples) {
        expect(normalizeForMatch(s).length, equals(s.length), reason: s);
      }
    });

    test('retire les accents et met en minuscules', () {
      expect(normalizeForMatch('Frère'), equals('frere'));
    });

    test(
      'mappe l\'apostrophe typographique (U+2019) sur l\'apostrophe droite',
      () {
        expect(normalizeForMatch('qu’est-ce'), equals("qu'est-ce"));
      },
    );
  });

  group('normalizeLoose', () {
    test('retire apostrophes et traits d\'union, réduit les espaces', () {
      expect(
        normalizeLoose("qu'est-ce que j'ai vu"),
        equals('quest ce que jai vu'),
      );
      expect(
        normalizeLoose('que sais-tu de moi'),
        equals('que sais tu de moi'),
      );
    });

    test('gère aussi l\'apostrophe typographique, via normalizeForMatch', () {
      expect(
        normalizeLoose('qu’est-ce que j’ai vu'),
        equals('quest ce que jai vu'),
      );
    });
  });

  group('MemoryIntentParser.parse — RememberFact', () {
    test('extrait le fait après « retiens que », accents préservés', () {
      final intent = MemoryIntentParser.parse(
        "Retiens que mon frère s'appelle Paul",
      );
      expect(intent, isA<RememberFact>());
      expect(
        (intent! as RememberFact).fact,
        equals("mon frère s'appelle Paul"),
      );
    });

    test('reconnaît « souviens-toi que » et « rappelle-toi que »', () {
      expect(
        (MemoryIntentParser.parse('souviens-toi que je prends le bus à 8h')!
                as RememberFact)
            .fact,
        equals('je prends le bus à 8h'),
      );
      expect(
        (MemoryIntentParser.parse('Rappelle-toi que j\'aime le café')!
                as RememberFact)
            .fact,
        equals("j'aime le café"),
      );
    });

    test('« retiens » seul, sans « que »', () {
      expect(
        (MemoryIntentParser.parse('retiens mon code postal : 75011')!
                as RememberFact)
            .fact,
        equals('mon code postal : 75011'),
      );
    });

    test('un fait vide n\'est pas une intention', () {
      expect(MemoryIntentParser.parse('retiens que'), isNull);
      expect(MemoryIntentParser.parse('retiens'), isNull);
    });

    test(
      'reconnaît le vocatif « Kita, » en tête et extrait le fait, accents préservés',
      () {
        final intent = MemoryIntentParser.parse(
          "Kita, retiens que mon frère s'appelle Paul",
        );
        expect(intent, isA<RememberFact>());
        expect(
          (intent! as RememberFact).fact,
          equals("mon frère s'appelle Paul"),
        );
      },
    );

    test('reconnaît le vocatif « kita » sans virgule, juste un espace', () {
      final intent = MemoryIntentParser.parse(
        "kita retiens que ma fille s'appelle Lina",
      );
      expect(intent, isA<RememberFact>());
      expect((intent! as RememberFact).fact, equals("ma fille s'appelle Lina"));
    });

    test('un préambule qui n\'est pas le vocatif « kita » ne déclenche plus '
        'rien : le préfixe doit être en tête (après vocatif optionnel)', () {
      expect(
        MemoryIntentParser.parse(
          "Dis donc, RETIENS QUE ma fille s'appelle Lina",
        ),
        isNull,
      );
    });

    test(
      'apostrophe typographique dans le fait : reconnu, apostrophe d\'origine préservée',
      () {
        final intent = MemoryIntentParser.parse(
          'retiens que mon fils s’appelle Léo',
        );
        expect(intent, isA<RememberFact>());
        expect(
          (intent! as RememberFact).fact,
          equals('mon fils s’appelle Léo'),
        );
      },
    );
  });

  group('MemoryIntentParser.parse — Recall', () {
    test('« qu\'est-ce que tu sais de moi » → RecallFacts', () {
      expect(
        MemoryIntentParser.parse('Qu\'est-ce que tu sais de moi ?'),
        isA<RecallFacts>(),
      );
      expect(
        MemoryIntentParser.parse('que sais-tu de moi'),
        isA<RecallFacts>(),
      );
      expect(
        MemoryIntentParser.parse('Que sais-tu de moi ?'),
        isA<RecallFacts>(),
      );
    });

    test('motifs de rappel de faits sans apostrophe → RecallFacts', () {
      expect(
        MemoryIntentParser.parse('quest ce que tu sais de moi'),
        isA<RecallFacts>(),
      );
    });

    test('« qu\'est-ce que j\'ai vu » → RecallEpisodes', () {
      expect(
        MemoryIntentParser.parse('qu\'est-ce que j\'ai vu aujourd\'hui ?'),
        isA<RecallEpisodes>(),
      );
      expect(
        MemoryIntentParser.parse('tu te souviens de ce que j\'ai vu'),
        isA<RecallEpisodes>(),
      );
    });

    test('apostrophe typographique → RecallEpisodes', () {
      expect(
        MemoryIntentParser.parse('qu’est-ce que j’ai vu aujourd’hui ?'),
        isA<RecallEpisodes>(),
      );
    });
  });

  group('MemoryIntentParser.parse — aucune intention', () {
    test('une phrase ordinaire ne déclenche rien', () {
      expect(MemoryIntentParser.parse('bonjour, comment vas-tu ?'), isNull);
      expect(MemoryIntentParser.parse('décris ce que tu vois'), isNull);
    });

    test('transcript vide', () {
      expect(MemoryIntentParser.parse('   '), isNull);
    });
  });

  group('MemoryIntentParser.parse — faux positif corrigé (défaut 1)', () {
    test(
      '« je retiens mon souffle avant de plonger » n\'est plus capté : '
      '« retiens » n\'est plus en tête d\'énoncé (après vocatif optionnel)',
      () {
        expect(
          MemoryIntentParser.parse('je retiens mon souffle avant de plonger'),
          isNull,
        );
      },
    );
  });
}
