import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/logger.dart';
import '../domain/conversation_entry.dart';

/// In-session conversation feed: what the user said (voice or text) and what
/// Kita answered. Never persisted (privacy-first) — cleared when the app
/// process ends.
class ConversationFeed extends Notifier<List<ConversationEntry>> {
  static final _log = KitaLogger('Shell.Feed');

  /// Oldest entries are dropped beyond this cap to bound memory.
  static const int maxEntries = 100;

  @override
  List<ConversationEntry> build() => const [];

  /// Appends a user message (voice transcript or typed text).
  void addUser(String text) => _add(ConversationSpeaker.user, text);

  /// Appends a Kita spoken response.
  void addKita(String text) => _add(ConversationSpeaker.kita, text);

  void clear() => state = const [];

  void _add(ConversationSpeaker speaker, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    // Métadonnées seulement — le contenu du message est de la donnée
    // personnelle et n'est JAMAIS loggé.
    _log.info('Entry added (${speaker.name}, len=${trimmed.length})');
    final next = [
      ...state,
      ConversationEntry(
        speaker: speaker,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
    ];
    state = next.length > maxEntries
        ? next.sublist(next.length - maxEntries)
        : next;
  }
}

/// The conversation feed shown in the Shell viewport.
final conversationFeedProvider =
    NotifierProvider<ConversationFeed, List<ConversationEntry>>(
  ConversationFeed.new,
);
