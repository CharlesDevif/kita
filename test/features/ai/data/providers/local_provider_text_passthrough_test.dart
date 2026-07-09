// Régression : `LocalProvider.completeWithTools` doit renvoyer la vraie
// réponse texte de Gemma quand celle-ci n'est pas un appel d'outil, et non
// pas retomber sur `_localResponse` (répondeur en conserve). Voir
// `_parseGemmaToolResponse` dans local_provider.dart.
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';
import 'package:kita/features/ai/data/providers/local_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/tool_models.dart';

// Réutilise le fake GemmaBridge déjà défini pour les tests du bridge.
import 'gemma_bridge_test.dart' show MockGemmaBridge;

void main() {
  group('LocalProvider.completeWithTools — text passthrough (régression)',
      () {
    late LocalProvider provider;
    late MockGemmaBridge mockGemma;

    setUp(() {
      mockGemma = MockGemmaBridge()..statusToReturn = GemmaModelStatus.ready;
      provider = LocalProvider(
        platform: TargetPlatform.android,
        gemmaBridge: mockGemma,
      );
    });

    test(
        'une réponse en texte libre de Gemma est renvoyée telle quelle, '
        'sans repli en conserve', () async {
      const conversationalText = 'Salut ! Comment vas-tu aujourd\'hui ?';
      mockGemma.completionToReturn =
          const GemmaCompletionResult(text: conversationalText);

      final result = await provider.completeWithTools(
        const AIRequest(prompt: 'salut'),
        tools: const [],
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIToolResponse>).value;
      expect(response.text, equals(conversationalText));
      expect(response.toolCalls, isEmpty);
      expect(response.hasToolCalls, isFalse);
    });

    test('un appel d\'outil `TOOL describe` produit un toolCall sans texte '
        'parasite', () async {
      mockGemma.completionToReturn =
          const GemmaCompletionResult(text: 'TOOL describe');

      final result = await provider.completeWithTools(
        const AIRequest(prompt: 'decris ce que tu vois'),
        tools: const [
          ToolSpec(
            name: 'describe',
            description: 'Décrit la scène visible via la caméra.',
            parameters: {},
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<AIToolResponse>).value;
      expect(response.hasToolCalls, isTrue);
      expect(response.toolCalls, hasLength(1));
      expect(response.toolCalls.single.name, equals('describe'));
      expect(response.hasText, isFalse);
    });
  });
}
