import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';
import 'package:kita/features/ai/domain/tool_models.dart';

/// Extrait la section `[Conversation]` du prompt, là où l'historique est
/// rendu. Les assertions « le modèle ne doit pas voir X » portent sur cette
/// section seule : le bloc `[Exemples]`, lui, contient légitimement des
/// lignes `TOOL ...`.
String conversationSection(String prompt) {
  const marker = '[Conversation]';
  final index = prompt.indexOf(marker);
  return index < 0 ? '' : prompt.substring(index);
}

const describeSpec = ToolSpec(
  name: 'describe',
  description: 'Prend une photo et décrit ce que la caméra voit.',
  parameters: {'type': 'object', 'properties': <String, dynamic>{}},
);

const alertSpec = ToolSpec(
  name: 'alert',
  description: "Active ou désactive la surveillance d'obstacles.",
  parameters: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'description': 'Action à effectuer.',
        'enum': ['start', 'stop'],
      },
    },
    'required': ['action'],
  },
);

const tools = [describeSpec, alertSpec];

void main() {
  group('buildLocalToolPrompt — cadrage du modèle', () {
    test('établit l\'identité de Kita', () {
      final prompt = buildLocalToolPrompt('bonjour', tools, const []);
      expect(prompt, contains('Kita'));
    });

    test('présente la conversation comme le comportement par défaut', () {
      final prompt = buildLocalToolPrompt('bonjour', tools, const []);
      expect(prompt, contains('Par défaut, tu réponds par du texte'));
    });

    test('exige une demande explicite avant d\'appeler un outil', () {
      final prompt = buildLocalToolPrompt('bonjour', tools, const []);
      expect(prompt, contains('explicitement'));
    });

    test('montre un exemple où une phrase banale ne déclenche aucun outil', () {
      final prompt = buildLocalToolPrompt('bonjour', tools, const []);
      // Le contre-exemple qui a manqué sur device : l'utilisateur reproche à
      // Kita d'avoir agi, et la bonne réponse est du texte, pas un outil.
      expect(prompt, contains('je ne t\'ai pas demandé ça'));
    });

    test('place le message utilisateur en dernier, avant le tour de Kita', () {
      final prompt = buildLocalToolPrompt('quelle heure est-il ?', tools, const []);
      expect(prompt, endsWith('Utilisateur : quelle heure est-il ?\nKita :'));
    });
  });

  group('buildLocalToolPrompt — description des outils', () {
    test('describe est rendu sans argument', () {
      final prompt = buildLocalToolPrompt('x', const [describeSpec], const []);
      expect(prompt, contains('- describe : Prend une photo'));
      expect(prompt, isNot(contains('argument')));
    });

    test('alert expose son argument et ses valeurs possibles', () {
      final prompt = buildLocalToolPrompt('x', const [alertSpec], const []);
      expect(prompt, contains('- alert :'));
      expect(prompt, contains('argument : action (start ou stop)'));
    });

    test('n\'expose pas le JSON Schema brut', () {
      final prompt = buildLocalToolPrompt('x', tools, const []);
      expect(prompt, isNot(contains('"type":"object"')));
      expect(prompt, isNot(contains('properties')));
    });
  });

  group('buildLocalToolPrompt — rendu de l\'historique', () {
    final historyWithToolCall = [
      const ConversationMessage.user('décris ce que tu vois'),
      const ConversationMessage.assistantToolCalls([
        ToolCall(id: '1', name: 'describe'),
      ]),
      const ConversationMessage.toolResult(
        callId: '1',
        result: 'Description en cours.',
      ),
    ];

    test('un appel d\'outil passé n\'est jamais rendu comme "(tool call)"', () {
      final prompt = buildLocalToolPrompt('merci', tools, historyWithToolCall);
      expect(conversationSection(prompt), isNot(contains('(tool call)')));
    });

    test(
      'un appel d\'outil passé n\'est jamais rendu comme une ligne TOOL '
      '(le modèle recopiait la ligne et redéclenchait la caméra)',
      () {
        final prompt = buildLocalToolPrompt('merci', tools, historyWithToolCall);
        expect(conversationSection(prompt), isNot(contains('TOOL describe')));
      },
    );

    test('un appel d\'outil passé est décrit en langage naturel', () {
      final prompt = buildLocalToolPrompt('merci', tools, historyWithToolCall);
      expect(prompt, contains('Kita : (a utilisé describe)'));
    });

    test('les résultats d\'outil internes sont omis', () {
      final prompt = buildLocalToolPrompt('merci', tools, historyWithToolCall);
      expect(prompt, isNot(contains('Description en cours.')));
    });

    test('les tours utilisateur et assistant sont étiquetés', () {
      final prompt = buildLocalToolPrompt('merci', tools, const [
        ConversationMessage.user('salut'),
        ConversationMessage.assistant('Bonjour !'),
      ]);
      expect(prompt, contains('Utilisateur : salut'));
      expect(prompt, contains('Kita : Bonjour !'));
    });

    test('sans historique, aucune section [Conversation]', () {
      final prompt = buildLocalToolPrompt('salut', tools, const []);
      expect(prompt, isNot(contains('[Conversation]')));
    });

    test('les messages vides sont ignorés', () {
      final prompt = buildLocalToolPrompt('merci', tools, const [
        ConversationMessage.user('  '),
        ConversationMessage.assistant('Bonjour !'),
      ]);
      expect(prompt, isNot(contains('Utilisateur :   ')));
    });
  });

  group('stripHallucinatedTurns', () {
    test('coupe un tour utilisateur inventé par le modèle', () {
      // Le prompt few-shot est un dialogue : le modèle a tendance à
      // poursuivre en inventant la réplique suivante. Sans coupe, Kita lit
      // à voix haute une question que l'utilisateur n'a jamais posée.
      expect(
        stripHallucinatedTurns('Bonjour !\nUtilisateur : et sinon ?'),
        equals('Bonjour !'),
      );
    });

    test('coupe aussi un tour Kita répété', () {
      expect(
        stripHallucinatedTurns('Bonjour !\nKita : Autre chose ?'),
        equals('Bonjour !'),
      );
    });

    test('laisse intacte une réponse normale multi-phrases', () {
      expect(
        stripHallucinatedTurns('Bonjour !\nComment vas-tu ?'),
        equals('Bonjour !\nComment vas-tu ?'),
      );
    });

    test('laisse intacte une ligne TOOL', () {
      expect(stripHallucinatedTurns('TOOL describe'), equals('TOOL describe'));
    });
  });
}
