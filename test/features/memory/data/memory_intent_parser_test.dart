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

  group(
    'MemoryIntentParser.parse — frontière de mot après le préfixe '
    '(revue a64e8bc, défaut 1)',
    () {
      test(
        '« quelque » ne doit plus tronquer le fait via « que » : '
        'le préfixe « retiens que » est rejeté (pas de frontière), '
        '« retiens » seul matche ensuite',
        () {
          final intent = MemoryIntentParser.parse(
            "Kita, retiens quelque chose d'important",
          );
          expect(intent, isA<RememberFact>());
          expect(
            (intent! as RememberFact).fact,
            equals("quelque chose d'important"),
          );
        },
      );

      test(
        '« note quelque chose ici » : « note que » rejeté (pas de '
        'frontière), aucun préfixe « note » seul n\'existe → null',
        () {
          expect(MemoryIntentParser.parse('note quelque chose ici'), isNull);
        },
      );

      test(
        '« souviens-toi quelque part que j\'ai des soucis » : '
        '« souviens-toi que » rejeté (pas de frontière) → null',
        () {
          expect(
            MemoryIntentParser.parse(
              "souviens-toi quelque part que j'ai des soucis",
            ),
            isNull,
          );
        },
      );

      test(
        '« Retiens-le, on doit y retourner » : le tiret suit « retiens » '
        'sans frontière → null, le fait n\'est pas tronqué en « -le, ... »',
        () {
          expect(
            MemoryIntentParser.parse('Retiens-le, on doit y retourner'),
            isNull,
          );
        },
      );

      test(
        '« retiens quelque chose d\'important » (sans vocatif) : fait '
        'intact, non tronqué',
        () {
          final intent = MemoryIntentParser.parse(
            "retiens quelque chose d'important",
          );
          expect(intent, isA<RememberFact>());
          expect(
            (intent! as RememberFact).fact,
            equals("quelque chose d'important"),
          );
        },
      );

      test(
        '« retiens quelque chose » : « retiens que » rejeté, « retiens » '
        'seul accepté avec la frontière espace',
        () {
          final intent = MemoryIntentParser.parse('retiens quelque chose');
          expect(intent, isA<RememberFact>());
          expect((intent! as RememberFact).fact, equals('quelque chose'));
        },
      );

      test(
        '« retiens, bof » : la virgule suit « retiens » sans frontière '
        'd\'espacement → null',
        () {
          expect(MemoryIntentParser.parse('retiens, bof'), isNull);
        },
      );
    },
  );

  group(
    'MemoryIntentParser.parse — fait sans alphanumérique rejeté '
    '(revue a64e8bc, défaut 2)',
    () {
      test('« retiens que ! » : fait réduit à de la ponctuation → null', () {
        expect(MemoryIntentParser.parse('retiens que !'), isNull);
      });

      test('« retiens ? » : fait réduit à de la ponctuation → null', () {
        expect(MemoryIntentParser.parse('retiens ?'), isNull);
      });
    },
  );

  group('MemoryIntentParser.parse — trous de couverture (revue a64e8bc)', () {
    test('transcript exactement « kita » : aucun préfixe ne suit → null', () {
      expect(MemoryIntentParser.parse('kita'), isNull);
    });

    test('vocatif tout en majuscules « KITA, retiens que ... »', () {
      final intent = MemoryIntentParser.parse(
        'KITA, retiens que je dois appeler ma mère',
      );
      expect(intent, isA<RememberFact>());
      expect(
        (intent! as RememberFact).fact,
        equals('je dois appeler ma mère'),
      );
    });

    test(
      'majuscule accentuée dans le fait : accent et casse préservés',
      () {
        final intent = MemoryIntentParser.parse(
          'retiens que Éric est mon voisin',
        );
        expect(intent, isA<RememberFact>());
        expect(
          (intent! as RememberFact).fact,
          equals('Éric est mon voisin'),
        );
      },
    );
  });
}
