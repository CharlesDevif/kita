import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/consent_entry.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/person.dart';

void main() {
  late KitaDatabase db;
  late MemoryVaultImpl vault;
  late ConsentDao consentDao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    final episodeDao = EpisodeDao(db);
    final preferenceDao = PreferenceDao(db);
    final personDao = PersonDao(db);
    final profileDao = ProfileDao(db);
    final pluginDataDao = PluginDataDao(db);
    consentDao = ConsentDao(db);

    vault = MemoryVaultImpl(
      episodeDao: episodeDao,
      preferenceDao: preferenceDao,
      personDao: personDao,
      profileDao: profileDao,
      pluginDataDao: pluginDataDao,
      consentDao: consentDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to grant consent for a domain
  Future<void> grantConsentFor(String scope) async {
    await consentDao.insert(
      consentType: 'data_storage',
      scope: scope,
      granted: true,
    );
  }

  group('MemoryVaultImpl — Consent flow', () {
    test('saveEpisode fails without consent', () async {
      final episode = KitaEpisode(
        id: 0,
        source: 'camera',
        eventType: 'describe',
        summary: 'A park scene',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      final result = await vault.saveEpisode(episode);
      expect(result.isFailure, isTrue);
    });

    test('saveEpisode succeeds with consent', () async {
      await grantConsentFor('episodic');

      final episode = KitaEpisode(
        id: 0,
        source: 'camera',
        eventType: 'describe',
        summary: 'A park scene',
        tags: ['outdoor', 'park'],
        importanceScore: 0.7,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      final result = await vault.saveEpisode(episode);
      expect(result.isSuccess, isTrue);

      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
      expect(episodes.first.summary, equals('A park scene'));
      expect(episodes.first.tags, equals(['outdoor', 'park']));
    });

    test('setPreference fails without consent', () async {
      final result = await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );
      expect(result.isFailure, isTrue);
    });

    test('setPreference succeeds with consent', () async {
      await grantConsentFor('semantic');

      final result = await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );
      expect(result.isSuccess, isTrue);

      final pref = (await vault.getPreference('theme')).getOrNull();
      expect(pref, equals('dark'));
    });

    test('savePerson fails without consent', () async {
      final person = KitaPerson(
        id: 0,
        name: 'Sophie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await vault.savePerson(person);
      expect(result.isFailure, isTrue);
    });

    test('savePerson succeeds with consent', () async {
      await grantConsentFor('relational');

      final person = KitaPerson(
        id: 0,
        name: 'Sophie',
        relationship: 'friend',
        interests: ['cooking'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await vault.savePerson(person);
      expect(result.isSuccess, isTrue);

      final persons = (await vault.getPersons()).getOrNull()!;
      expect(persons, hasLength(1));
      expect(persons.first.name, equals('Sophie'));
    });
  });

  group('MemoryVaultImpl — Consent management', () {
    test('grantConsent stores consent entry', () async {
      final entry = ConsentEntry(
        id: 0,
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
        grantedAt: DateTime.now(),
        details: 'Store visual descriptions',
      );

      final result = await vault.grantConsent(entry);
      expect(result.isSuccess, isTrue);

      final consents = (await vault.getConsents()).getOrNull()!;
      expect(consents, hasLength(1));
      expect(consents.first.consentType, equals('data_storage'));
    });

    test('revokeConsent disables consent', () async {
      final insertResult = await consentDao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );
      final id = insertResult.getOrNull()!;

      final revokeResult = await vault.revokeConsent(id);
      expect(revokeResult.isSuccess, isTrue);

      final has = (await vault.hasConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      ))
          .getOrNull()!;
      expect(has, isFalse);
    });

    test('hasConsent returns true for active consent', () async {
      await grantConsentFor('episodic');

      final result = await vault.hasConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isTrue);
    });

    test('hasConsent returns false when no consent exists', () async {
      final result = await vault.hasConsent(
        consentType: 'data_storage',
        scope: 'episodic',
      );
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isFalse);
    });

    test('consent is tracked with timestamp and details', () async {
      final entry = ConsentEntry(
        id: 0,
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
        grantedAt: DateTime.now(),
        details: 'User accepted during onboarding',
      );

      await vault.grantConsent(entry);

      final consents = (await vault.getConsents()).getOrNull()!;
      expect(consents.first.details, equals('User accepted during onboarding'));
      expect(consents.first.grantedAt, isNotNull);
    });
  });

  group('MemoryVaultImpl — Transparency', () {
    test('whatDoYouKnow returns all domains', () async {
      // Grant all consents
      await grantConsentFor('episodic');
      await grantConsentFor('semantic');
      await grantConsentFor('relational');

      // Store data in each domain
      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'camera',
        eventType: 'describe',
        summary: 'A red car',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      ));

      await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );

      await vault.savePerson(KitaPerson(
        id: 0,
        name: 'Sophie',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final result = await vault.whatDoYouKnow();
      expect(result.isSuccess, isTrue);

      final data = result.getOrNull()!;
      expect(data.containsKey(MemoryDomain.episodic), isTrue);
      expect(data.containsKey(MemoryDomain.semantic), isTrue);
      expect(data.containsKey(MemoryDomain.relational), isTrue);
      expect(data[MemoryDomain.episodic], hasLength(1));
      expect(data[MemoryDomain.semantic], hasLength(1));
      expect(data[MemoryDomain.relational], hasLength(1));
    });

    test('whatDoYouKnow returns empty when no data', () async {
      final result = await vault.whatDoYouKnow();
      expect(result.isSuccess, isTrue);

      final data = result.getOrNull()!;
      expect(data, isEmpty);
    });
  });

  group('MemoryVaultImpl — Forget', () {
    test('forget everything deletes all data', () async {
      await grantConsentFor('episodic');
      await grantConsentFor('semantic');
      await grantConsentFor('relational');

      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'test',
        eventType: 'test',
        summary: 'Test',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      ));

      await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );

      final result = await vault.forget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final data = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(data, isEmpty);
    });

    test('forget requires confirmation', () async {
      final result = await vault.forget(
        ForgetRequest.everything(confirmation: false),
      );
      expect(result.isFailure, isTrue);
    });

    test('forget domain deletes only that domain', () async {
      await grantConsentFor('episodic');
      await grantConsentFor('semantic');

      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'test',
        eventType: 'test',
        summary: 'Test episode',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      ));

      await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );

      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      // Episodes should be gone
      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, isEmpty);

      // Preferences should still be there
      final pref = (await vault.getPreference('theme')).getOrNull();
      expect(pref, equals('dark'));
    });

    test('forget plugin deletes only plugin data', () async {
      // Insert plugin data directly
      await vault.pluginDataDao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );
      await vault.pluginDataDao.insert(
        pluginId: 'com.kita.alert',
        namespace: 'settings',
        key: 'threshold',
        value: '0.8',
      );

      final result = await vault.forget(
        ForgetRequest.plugin('com.kita.describe', confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final remaining = (await vault.pluginDataDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.pluginId, equals('com.kita.alert'));
    });
  });

  group('MemoryVaultImpl — 4 memory domains', () {
    test('working domain is not persisted (no DB operations)', () async {
      // Working memory is RAM-only, verified by forget not failing
      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.working, confirmation: true),
      );
      expect(result.isSuccess, isTrue);
    });

    test('episodic domain stores timestamped events', () async {
      await grantConsentFor('episodic');

      final now = DateTime.now();
      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'camera',
        eventType: 'describe',
        summary: 'A park scene',
        tags: ['outdoor'],
        importanceScore: 0.7,
        isPinned: false,
        createdAt: now,
      ));

      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
      expect(episodes.first.createdAt, isNotNull);
      expect(episodes.first.source, equals('camera'));
    });

    test('semantic domain stores key-value preferences', () async {
      await grantConsentFor('semantic');

      await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );

      final prefs = (await vault.getPreferences()).getOrNull()!;
      expect(prefs, hasLength(1));
      expect(prefs.first.key, equals('theme'));
      expect(prefs.first.category, equals('display'));
    });

    test('relational domain stores person data', () async {
      await grantConsentFor('relational');

      await vault.savePerson(KitaPerson(
        id: 0,
        name: 'Sophie',
        relationship: 'friend',
        interests: ['cooking', 'travel'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final persons = (await vault.getPersons()).getOrNull()!;
      expect(persons, hasLength(1));
      expect(persons.first.name, equals('Sophie'));
      expect(persons.first.relationship, equals('friend'));
    });
  });
}
