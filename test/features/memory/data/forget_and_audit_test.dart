import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/person.dart';

void main() {
  late KitaDatabase db;
  late MemoryVaultImpl vault;
  late ConsentDao consentDao;
  late EpisodeDao episodeDao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    episodeDao = EpisodeDao(db);
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
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> grantConsentFor(String scope) async {
    await consentDao.insert(
      consentType: 'data_storage',
      scope: scope,
      granted: true,
    );
  }

  /// Seeds test data across all domains.
  Future<void> seedAllDomains() async {
    await grantConsentFor('episodic');
    await grantConsentFor('semantic');
    await grantConsentFor('relational');

    await vault.saveEpisode(KitaEpisode(
      id: 0,
      source: 'camera',
      eventType: 'describe',
      summary: 'A park scene',
      tags: ['outdoor'],
      importanceScore: 0.7,
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
      relationship: 'friend',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    // Profile data (no consent required — it's user config)
    await vault.profileDao.insert(
      displayName: 'Marie',
      accessibilityProfile: 'blind',
      language: 'fr',
    );

    // Plugin data
    await vault.pluginDataDao.insert(
      pluginId: 'com.kita.describe',
      namespace: 'settings',
      key: 'model',
      value: 'yolo-v8',
    );
  }

  // ===== Forget scopes =====

  group('Forget — everything scope', () {
    test('erases 100% of data from all tables', () async {
      await seedAllDomains();

      final result = await vault.forget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final data = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(data, isEmpty);
    });

    test('auditForget confirms 0 residual data after everything', () async {
      await seedAllDomains();

      final request = ForgetRequest.everything(confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });
  });

  group('Forget — domain scope', () {
    test('erases only the specified domain (episodic)', () async {
      await seedAllDomains();

      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, isEmpty);

      // Other domains remain
      final pref = (await vault.getPreference('theme')).getOrNull();
      expect(pref, equals('dark'));

      final persons = (await vault.getPersons()).getOrNull()!;
      expect(persons, hasLength(1));
    });

    test('auditForget confirms 0 residual for episodic domain', () async {
      await seedAllDomains();

      final request =
          ForgetRequest.domain(MemoryDomain.episodic, confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });

    test('erases only the specified domain (semantic)', () async {
      await seedAllDomains();

      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.semantic, confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      // Preferences gone
      final prefs = (await vault.getPreferences()).getOrNull()!;
      expect(prefs, isEmpty);

      // Episodes remain
      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
    });

    test('auditForget confirms 0 residual for semantic domain', () async {
      await seedAllDomains();

      final request =
          ForgetRequest.domain(MemoryDomain.semantic, confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });

    test('erases only the specified domain (relational)', () async {
      await seedAllDomains();

      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.relational, confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final persons = (await vault.getPersons()).getOrNull()!;
      expect(persons, isEmpty);

      // Episodes remain
      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
    });

    test('auditForget confirms 0 residual for relational domain', () async {
      await seedAllDomains();

      final request =
          ForgetRequest.domain(MemoryDomain.relational, confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });

    test('forget working domain succeeds (no-op)', () async {
      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.working, confirmation: true),
      );
      expect(result.isSuccess, isTrue);
    });

    test('forget domain without domain specified fails', () async {
      final result = await vault.forget(
        const ForgetRequest(
          scope: ForgetScope.domain,
          confirmation: true,
        ),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('Forget — plugin scope', () {
    test('erases only the specified plugin data', () async {
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

      final remaining =
          (await vault.pluginDataDao.getAll()).getOrNull()!;
      expect(remaining, hasLength(1));
      expect(remaining.first.pluginId, equals('com.kita.alert'));
    });

    test('auditForget confirms 0 residual for plugin', () async {
      await vault.pluginDataDao.insert(
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
      );

      final request =
          ForgetRequest.plugin('com.kita.describe', confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });

    test('forget plugin without pluginId specified fails', () async {
      final result = await vault.forget(
        const ForgetRequest(
          scope: ForgetScope.plugin,
          confirmation: true,
        ),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('Forget — olderThan scope', () {
    test('erases episodes older than the specified date', () async {
      await grantConsentFor('episodic');

      // Insert an episode with a past expiry date -> must be erased.
      final oldDate = DateTime.now().subtract(const Duration(days: 30));
      await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Old scene',
        importanceScore: 0.3,
        isPinned: false,
        expiresAt: oldDate,
      );

      // Insert a recent episode with no expiry (created now) -> must survive a
      // cutoff placed in the past.
      await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Recent scene',
        importanceScore: 0.7,
        isPinned: false,
      );

      final cutoff = DateTime.now().subtract(const Duration(days: 15));
      final result = await vault.forget(
        ForgetRequest.olderThan(cutoff, confirmation: true),
      );
      expect(result.isSuccess, isTrue);

      final episodes = (await vault.getEpisodes()).getOrNull()!;
      // Old episode erased, recent no-expiry episode preserved.
      expect(episodes, hasLength(1));
      expect(episodes.first.summary, equals('Recent scene'));
    });

    test('auditForget confirms 0 residual for olderThan', () async {
      await grantConsentFor('episodic');

      final oldDate = DateTime.now().subtract(const Duration(days: 30));
      await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Old scene',
        importanceScore: 0.3,
        isPinned: false,
        expiresAt: oldDate,
      );

      final cutoff = DateTime.now();
      final request = ForgetRequest.olderThan(cutoff, confirmation: true);
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });

    test('forget olderThan without date specified fails', () async {
      final result = await vault.forget(
        const ForgetRequest(
          scope: ForgetScope.olderThan,
          confirmation: true,
        ),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('Forget — specific scope', () {
    test('erases only the specified episode IDs', () async {
      await grantConsentFor('episodic');

      final id1 = (await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Scene A',
        importanceScore: 0.5,
        isPinned: false,
      ))
          .getOrNull()!;

      final id2 = (await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Scene B',
        importanceScore: 0.5,
        isPinned: false,
      ))
          .getOrNull()!;

      await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Scene C',
        importanceScore: 0.5,
        isPinned: false,
      );

      final result = await vault.forget(
        ForgetRequest.specific(
          [id1.toString(), id2.toString()],
          confirmation: true,
        ),
      );
      expect(result.isSuccess, isTrue);

      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
      expect(episodes.first.summary, equals('Scene C'));
    });

    test('auditForget confirms 0 residual for specific IDs', () async {
      await grantConsentFor('episodic');

      final id1 = (await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Scene A',
        importanceScore: 0.5,
        isPinned: false,
      ))
          .getOrNull()!;

      final request = ForgetRequest.specific(
        [id1.toString()],
        confirmation: true,
      );
      await vault.forget(request);

      final audit = await vault.auditForget(request);
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isTrue);
    });
  });

  // ===== Confirmation gate =====

  group('Forget — confirmation gate', () {
    test('forget requires confirmation=true', () async {
      final result = await vault.forget(
        ForgetRequest.everything(confirmation: false),
      );
      expect(result.isFailure, isTrue);
    });

    test('forget domain also requires confirmation', () async {
      final result = await vault.forget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: false),
      );
      expect(result.isFailure, isTrue);
    });
  });

  // ===== Audit detects residual =====

  group('Audit — detects residual data', () {
    test('auditForget returns false when data still exists', () async {
      await seedAllDomains();

      // Do NOT call forget, just audit
      final audit = await vault.auditForget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isFalse);
    });

    test('auditForget domain returns false when domain has data', () async {
      await seedAllDomains();

      final audit = await vault.auditForget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isFalse);
    });

    test('auditForget specific returns false when episode exists', () async {
      await grantConsentFor('episodic');

      final id = (await episodeDao.insert(
        source: 'camera',
        eventType: 'describe',
        summary: 'Scene',
        importanceScore: 0.5,
        isPinned: false,
      ))
          .getOrNull()!;

      final audit = await vault.auditForget(
        ForgetRequest.specific([id.toString()], confirmation: true),
      );
      expect(audit.isSuccess, isTrue);
      expect(audit.getOrNull(), isFalse);
    });
  });

  // ===== Transparency after forget =====

  group('whatDoYouKnow — transparency after forget', () {
    test('returns empty map after forget everything', () async {
      await seedAllDomains();

      await vault.forget(ForgetRequest.everything(confirmation: true));

      final data = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(data, isEmpty);
    });

    test('returns remaining domains after partial forget', () async {
      await seedAllDomains();

      await vault.forget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );

      final data = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(data.containsKey(MemoryDomain.episodic), isFalse);
      expect(data.containsKey(MemoryDomain.semantic), isTrue);
      expect(data.containsKey(MemoryDomain.relational), isTrue);
    });

    test('returns structured data per domain', () async {
      await seedAllDomains();

      final data = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(data[MemoryDomain.episodic]!.first, contains('A park scene'));
      expect(data[MemoryDomain.semantic]!.first, contains('theme'));
      expect(data[MemoryDomain.relational]!.first, equals('Sophie'));
    });
  });

  // ===== Forget everything atomicity + external purge hook =====

  MemoryVaultImpl buildVault({Future<void> Function()? onPurgeExternal}) {
    return MemoryVaultImpl(
      episodeDao: EpisodeDao(db),
      preferenceDao: PreferenceDao(db),
      personDao: PersonDao(db),
      profileDao: ProfileDao(db),
      pluginDataDao: PluginDataDao(db),
      consentDao: ConsentDao(db),
      database: db,
      onPurgeExternal: onPurgeExternal,
    );
  }

  group('Forget everything — atomicity', () {
    test('rolls back every delete when one table fails mid-transaction',
        () async {
      await seedAllDomains();

      // Make the plugin_data delete fail inside the transaction.
      await db.customStatement('DROP TABLE plugin_data');

      final result = await vault.forget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(result.isFailure, isTrue);

      // Transaction rolled back: earlier deletes were undone.
      expect((await vault.getEpisodes()).getOrNull(), hasLength(1));
      expect((await vault.getPreferences()).getOrNull(), hasLength(1));
      expect((await vault.getPersons()).getOrNull(), hasLength(1));
    });
  });

  group('Forget everything — external purge hook', () {
    test('invokes onPurgeExternal after clearing local tables', () async {
      var purged = false;
      final vaultWithHook = buildVault(
        onPurgeExternal: () async {
          purged = true;
        },
      );
      await seedAllDomains();

      final result = await vaultWithHook.forget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(result.isSuccess, isTrue);
      expect(purged, isTrue);

      final data = (await vaultWithHook.whatDoYouKnow()).getOrNull()!;
      expect(data, isEmpty);
    });

    test('reports failure when onPurgeExternal throws', () async {
      final vaultWithBadHook = buildVault(
        onPurgeExternal: () async {
          throw Exception('external purge failed');
        },
      );
      await seedAllDomains();

      final result = await vaultWithBadHook.forget(
        ForgetRequest.everything(confirmation: true),
      );
      expect(result.isFailure, isTrue);
    });
  });

  // ===== Consent lock serialization (TOCTOU) =====

  group('Consent lock — revoke serializes with storage', () {
    test('concurrent saveEpisode + revokeConsent do not deadlock and stay '
        'consistent', () async {
      final consentId = (await consentDao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      ))
          .getOrNull()!;

      final episode = KitaEpisode(
        id: 0,
        source: 'camera',
        eventType: 'describe',
        summary: 'Concurrent scene',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      // saveEpisode is invoked first, so it acquires the shared lock first and
      // runs to completion before the revoke proceeds (no interleaving).
      final results = await Future.wait([
        vault.saveEpisode(episode),
        vault.revokeConsent(consentId),
      ]);

      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect((await vault.getEpisodes()).getOrNull(), hasLength(1));
      expect(
        (await vault.hasConsent(
          consentType: 'data_storage',
          scope: 'episodic',
        ))
            .getOrNull(),
        isFalse,
      );
    });
  });
}
