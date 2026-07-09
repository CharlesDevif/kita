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
  // Apostrophe typographique (U+2019) → apostrophe droite (U+0027) : les
  // claviers français et la reconnaissance vocale produisent l'apostrophe
  // typographique, alors que les motifs sont écrits avec l'apostrophe
  // droite. Un caractère vers un caractère : la longueur reste préservée.
  '’': "'",
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

/// Normalisation « loose », réservée aux motifs de **rappel**.
///
/// CONTRAINTE : `normalizeForMatch` doit rester 1:1 parce que `RememberFact`
/// découpe la chaîne ORIGINALE à partir d'un indice trouvé sur la forme
/// normalisée — changer la longueur y casserait l'alignement. Les motifs de
/// rappel, eux, ne découpent rien : ils ne font que tester une présence
/// (`contains`). Sans cette contrainte d'indices, on peut se permettre de
/// retirer apostrophes et traits d'union et de réduire les espaces
/// multiples, ce qui rend atteignables des variantes orales sans
/// ponctuation (« quest ce que jai vu »).
String normalizeLoose(String input) {
  final withoutPunctuation = normalizeForMatch(
    input,
  ).replaceAll("'", '').replaceAll('-', ' ');
  return withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
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

// Motifs de rappel : testés sur `normalizeLoose`, donc écrits SANS
// apostrophe ni trait d'union (ils seraient sinon inatteignables — la
// normalisation loose les a déjà retirés de la chaîne comparée).
const List<String> _recallFactsPatterns = [
  'que sais tu de moi',
  'quest ce que tu sais de moi',
  'tu sais quoi sur moi',
];

const List<String> _recallEpisodesPatterns = [
  'ce que jai vu',
  'quai je vu',
];

class MemoryIntentParser {
  MemoryIntentParser._();

  /// Vocatif optionnel en tête d'énoncé : « kita » suivi d'au moins une
  /// virgule et/ou un espace. Testé sur la forme normalisée (1:1), ce qui
  /// permet de retirer le même nombre de caractères sur la chaîne originale
  /// pour garder l'alignement des indices utilisé par `RememberFact`.
  static final RegExp _vocative = RegExp(r'^kita[ ,]+');

  /// Un caractère d'espacement en tête de chaîne : sert à vérifier qu'un
  /// préfixe est suivi d'une frontière de mot, pas du milieu d'un autre mot
  /// (« que » ne doit pas matcher le début de « quelque »).
  static final RegExp _leadingWhitespace = RegExp(r'^\s');

  /// Au moins une lettre (accents compris) ou un chiffre : sert à rejeter un
  /// « fait » qui ne serait que de la ponctuation (« retiens que ! »).
  static final RegExp _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Reconnaît une intention mémoire, ou `null` si le transcript n'en porte pas.
  static MemoryIntent? parse(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;

    // Rappel : aucune découpe de la chaîne originale, donc normalisation
    // agressive (apostrophes et traits d'union retirés). Testé avant les
    // faits de mémorisation : « ce que j'ai vu » est plus spécifique et ne
    // doit pas être avalé par un motif plus large.
    final loose = normalizeLoose(trimmed);
    for (final pattern in _recallEpisodesPatterns) {
      if (loose.contains(pattern)) return const RecallEpisodes();
    }
    for (final pattern in _recallFactsPatterns) {
      if (loose.contains(pattern)) return const RecallFacts();
    }

    // RememberFact découpe la chaîne ORIGINALE (accents préservés) à partir
    // d'un indice trouvé sur la forme normalisée : normalizeForMatch doit
    // donc rester 1:1 ici, contrairement au rappel ci-dessus.
    var working = trimmed;
    var normalized = normalizeForMatch(trimmed);

    final vocative = _vocative.firstMatch(normalized);
    if (vocative != null) {
      // Retire le vocatif des DEUX chaînes en même temps : la longueur
      // supprimée est identique de part et d'autre, l'alignement survit.
      working = working.substring(vocative.end);
      normalized = normalized.substring(vocative.end);
    }

    // Le préfixe doit être en tête du transcript (après vocatif optionnel) :
    // un `indexOf` n'importe où dans la phrase produirait des faux positifs
    // sur des verbes conjugués ordinaires (« je retiens mon souffle »).
    for (final prefix in _rememberPrefixes) {
      if (!normalized.startsWith(prefix)) continue;

      // Frontière de mot obligatoire après le préfixe : « que » est un
      // préfixe de « quelque », donc `startsWith` seul accepterait
      // « retiens quelque chose » et tronquerait le fait en « lque chose ».
      // La queue doit être vide (préfixe = tout le transcript) ou commencer
      // par un espacement — sinon ce préfixe ne matche pas vraiment, on
      // essaie le suivant (potentiellement plus court) dans la liste.
      final tail = normalized.substring(prefix.length);
      if (tail.isNotEmpty && !tail.startsWith(_leadingWhitespace)) continue;

      final fact = working.substring(prefix.length).trim();
      if (fact.isEmpty) return null;
      // Un fait qui ne contient aucune lettre ni chiffre (juste de la
      // ponctuation, ex. « retiens que ! ») ne vaut pas la peine d'être
      // écrit en mémoire.
      if (!_alphanumeric.hasMatch(fact)) return null;
      return RememberFact(fact);
    }

    return null;
  }
}
