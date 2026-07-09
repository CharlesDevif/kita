import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/shell/di/conversation_providers.dart';
import 'package:kita/features/shell/domain/conversation_entry.dart';

void main() {
  group('ConversationFeed', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() {
      container.dispose();
    });

    test('démarre vide', () {
      expect(container.read(conversationFeedProvider), isEmpty);
    });

    test('ajoute les messages utilisateur et Kita dans l\'ordre', () {
      final feed = container.read(conversationFeedProvider.notifier);
      feed.addUser('décris');
      feed.addKita('Je vois une table avec une tasse.');

      final entries = container.read(conversationFeedProvider);
      expect(entries, hasLength(2));
      expect(entries[0].speaker, ConversationSpeaker.user);
      expect(entries[0].text, 'décris');
      expect(entries[1].speaker, ConversationSpeaker.kita);
      expect(entries[1].text, 'Je vois une table avec une tasse.');
    });

    test('ignore les textes vides ou blancs', () {
      final feed = container.read(conversationFeedProvider.notifier);
      feed.addUser('');
      feed.addKita('   ');
      expect(container.read(conversationFeedProvider), isEmpty);
    });

    test('borne la taille du fil (les plus anciens sortent)', () {
      final feed = container.read(conversationFeedProvider.notifier);
      for (var i = 0; i < ConversationFeed.maxEntries + 10; i++) {
        feed.addUser('message $i');
      }
      final entries = container.read(conversationFeedProvider);
      expect(entries, hasLength(ConversationFeed.maxEntries));
      expect(entries.first.text, 'message 10');
      expect(entries.last.text,
          'message ${ConversationFeed.maxEntries + 9}');
    });

    test('clear vide le fil', () {
      final feed = container.read(conversationFeedProvider.notifier);
      feed.addUser('bonjour');
      feed.clear();
      expect(container.read(conversationFeedProvider), isEmpty);
    });
  });
}
