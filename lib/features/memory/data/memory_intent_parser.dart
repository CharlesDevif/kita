import '../domain/memory_intent.dart';

/// Table d'accents. Chaque entrée mappe **un** caractère sur **un** caractère :
/// la normalisation préserve donc les indices, ce qui permet de découper la
/// chaîne originale (accents intacts) à partir d'une correspondance trouvée
/// sur la forme normalisée.
const Map<String, String> _accentFolding = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y',
  'ñ': 'n',
};

/// Minuscules + accents retirés, **sans changer la longueur**.
///
/// `œ`/`æ` sont volontairement absents : ils se déplieraient en deux
/// caractères et casseraient l'alignement des indices.
String normalizeForMatch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentFolding[char] ?? char);
  }
  return buffer.toString();
}

/// Préfixes d'écriture, du plus long au plus court : « retiens que » doit être
/// testé avant « retiens », sinon le fait garderait un « que » en tête.
const List<String> _rememberPrefixes = [
  'souviens-toi que',
  'souviens toi que',
  'rappelle-toi que',
  'rappelle toi que',
  'retiens que',
  'note que',
  'retiens',
];

const List<String> _recallFactsPatterns = [
  'que sais-tu de moi',
  'que sais tu de moi',
  "qu'est-ce que tu sais de moi",
  'quest-ce que tu sais de moi',
  'tu sais quoi sur moi',
];

const List<String> _recallEpisodesPatterns = [
  "qu'est-ce que j'ai vu",
  'quest-ce que jai vu',
  "ce que j'ai vu",
  'ce que jai vu',
  "qu'ai-je vu",
];

class MemoryIntentParser {
  MemoryIntentParser._();

  /// Reconnaît une intention mémoire, ou `null` si le transcript n'en porte pas.
  static MemoryIntent? parse(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;
    final normalized = normalizeForMatch(trimmed);

    // Le rappel d'épisodes est testé avant celui des faits : « ce que j'ai vu »
    // est plus spécifique et ne doit pas être avalé par un motif plus large.
    for (final pattern in _recallEpisodesPatterns) {
      if (normalized.contains(pattern)) return const RecallEpisodes();
    }
    for (final pattern in _recallFactsPatterns) {
      if (normalized.contains(pattern)) return const RecallFacts();
    }

    for (final prefix in _rememberPrefixes) {
      final index = normalized.indexOf(prefix);
      if (index < 0) continue;
      // Découpe la chaîne ORIGINALE : les indices sont valides parce que
      // normalizeForMatch préserve la longueur.
      final fact = trimmed.substring(index + prefix.length).trim();
      if (fact.isEmpty) return null;
      return RememberFact(fact);
    }

    return null;
  }
}
