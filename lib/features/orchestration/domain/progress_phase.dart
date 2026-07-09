/// Où en est Kita dans le traitement d'une requête utilisateur.
///
/// Émis par l'InputRouter, la ConversationEngine et l'OutputCoordinator ;
/// consommé par [ProgressReporter] qui décide seul de la restitution
/// (orbe / haptique / voix / texte).
enum ProgressPhase {
  /// Le LLM réfléchit (aucune sortie encore).
  thinking,

  /// Un outil s'exécute (photo, analyse d'image…).
  working,

  /// Kita a commencé à répondre.
  responding,

  /// Requête terminée avec succès.
  done,

  /// Requête échouée.
  failed,
}
