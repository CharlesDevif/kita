import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';

/// Le moteur mobile ne garde qu'UNE session native, partagée entre texte et
/// vision. Si le contexte tool-use fuit dans l'appel vision, Gemma renvoie un
/// `{"tool_call": ...}` JSON au lieu d'une description — et Kita le lisait
/// tel quel à voix haute à une utilisatrice aveugle (bug terrain, S21 Ultra).
///
/// Ces tests verrouillent le prédicat du garde-fou.
void main() {
  group('détection d\'une réponse vision qui est un appel d\'outil', () {
    test('rejette le JSON tool_call exact observé sur device', () {
      const observed =
          '{"tool_call": {"name": "describe", "arguments": {"detail_level": '
          '"detailed"}}}';
      expect(GemmaBridgeImpl.debugLooksLikeToolCall(observed), isTrue);
    });

    test('rejette tout début de JSON', () {
      expect(GemmaBridgeImpl.debugLooksLikeToolCall('{"name": "x"}'), isTrue);
    });

    test('rejette une mention de tool_call en milieu de texte', () {
      expect(
        GemmaBridgeImpl.debugLooksLikeToolCall('Voici : {"tool_call": {}}'),
        isTrue,
      );
    });

    test('accepte une vraie description de scène', () {
      const description =
          'Une table basse en bois avec une tasse à gauche et un livre ouvert.';
      expect(GemmaBridgeImpl.debugLooksLikeToolCall(description), isFalse);
    });

    test('accepte une description contenant une accolade plus loin', () {
      expect(
        GemmaBridgeImpl.debugLooksLikeToolCall('Un panneau affiche { ouvert }.'),
        isFalse,
      );
    });
  });
}
