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
      ];
      for (final s in samples) {
        expect(normalizeForMatch(s).length, equals(s.length), reason: s);
      }
    });

    test('retire les accents et met en minuscules', () {
      expect(normalizeForMatch('Frère'), equals('frere'));
    });
  });

  group('MemoryIntentParser.parse — RememberFact', () {
    test('extrait le fait après « retiens que », accents préservés', () {
      final intent = MemoryIntentParser.parse(
        "Retiens que mon frère s'appelle Paul",
      );
      expect(intent, isA<RememberFact>());
      expect((intent! as RememberFact).fact, equals("mon frère s'appelle Paul"));
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

    test('préfixe en majuscules, pas en début de chaîne', () {
      final intent = MemoryIntentParser.parse(
        "Dis donc, RETIENS QUE ma fille s'appelle Lina",
      );
      expect(intent, isA<RememberFact>());
      expect(
        (intent! as RememberFact).fact,
        equals("ma fille s'appelle Lina"),
      );
    });
  });

  group('MemoryIntentParser.parse — Recall', () {
    test('« qu\'est-ce que tu sais de moi » → RecallFacts', () {
      expect(
        MemoryIntentParser.parse('Qu\'est-ce que tu sais de moi ?'),
        isA<RecallFacts>(),
      );
      expect(MemoryIntentParser.parse('que sais-tu de moi'), isA<RecallFacts>());
    });

    test('« qu\'est-ce que j\'ai vu » → RecallEpisodes', () {
      expect(
        MemoryIntentParser.parse('qu\'est-ce que j\'ai vu aujourd\'hui ?'),
        isA<RecallEpisodes>(),
      );
      expect(MemoryIntentParser.parse('tu te souviens de ce que j\'ai vu'),
          isA<RecallEpisodes>());
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

  group('MemoryIntentParser.parse — limite connue (matching par sous-chaîne)', () {
    test(
      '« retiens » comme verbe conjugué ordinaire est capté à tort '
      '(limitation documentée, pas de détection de frontière de mot)',
      () {
        // « Je retiens mon souffle » : aucune intention de mémorisation ici,
        // mais _rememberPrefixes cherche « retiens » n'importe où dans la
        // chaîne normalisée, sans vérifier qu'il s'agit d'un mot isolé en
        // tête d'énoncé. Ce test fige le comportement actuel plutôt que de
        // le corriger silencieusement : la correction (détection de
        // frontière de mot / position) n'est pas demandée par cette tâche.
        final intent = MemoryIntentParser.parse(
          'je retiens mon souffle avant de plonger',
        );
        expect(intent, isA<RememberFact>());
      },
    );
  });
}
