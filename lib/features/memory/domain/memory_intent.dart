/// Intention mémoire reconnue **sans appel au LLM**.
///
/// Aucun outil `remember`/`recall` n'est exposé au modèle : un Gemma 3n E2B
/// choisit d'autant plus mal qu'il a d'options (voir le bug `describe`,
/// spec 2026-07-09-progression-et-latence §5.6).
sealed class MemoryIntent {
  const MemoryIntent();
}

/// « retiens que mon frère s'appelle Paul »
final class RememberFact extends MemoryIntent {
  const RememberFact(this.fact);

  /// Texte original du fait, accents préservés.
  final String fact;
}

/// « qu'est-ce que tu sais de moi ? »
final class RecallFacts extends MemoryIntent {
  const RecallFacts();
}

/// « qu'est-ce que j'ai vu ? »
final class RecallEpisodes extends MemoryIntent {
  const RecallEpisodes();
}
