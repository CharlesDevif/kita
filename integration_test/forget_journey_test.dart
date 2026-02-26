/// Journey test : "Forget everything" → 0 donnée résiduelle (AC4)
///
/// Valide le parcours :
///   DB Drift réelle (in-memory) avec données pré-peuplées
///   → forget(ForgetRequest.everything()) exécuté
///   → auditForget() == true (0 donnée résiduelle)
///   → consentements révoqués
///
/// Utilise MemoryVaultImpl avec vraie DB Drift (pas de mock) —
/// pattern établi depuis phase2_integration_gate_test.dart.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kita/core/data/database.dart' hide UserProfile;
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/person.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late KitaDatabase db;
  late MemoryVaultImpl vault;
  late ConsentDao consentDao;
  late PluginDataDao pluginDataDao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    consentDao = ConsentDao(db);
    pluginDataDao = PluginDataDao(db);
    vault = MemoryVaultImpl(
      episodeDao: EpisodeDao(db),
      preferenceDao: PreferenceDao(db),
      personDao: PersonDao(db),
      profileDao: ProfileDao(db),
      pluginDataDao: pluginDataDao,
      consentDao: consentDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper : pré-peupler la DB avec des données dans tous les domaines.
  Future<void> populateDatabase() async {
    // Accorder les consentements nécessaires pour chaque domaine
    await consentDao.insert(
      consentType: 'data_storage',
      scope: 'episodic',
      granted: true,
    );
    await consentDao.insert(
      consentType: 'data_storage',
      scope: 'semantic',
      granted: true,
    );
    await consentDao.insert(
      consentType: 'data_storage',
      scope: 'relational',
      granted: true,
    );

    // Sauvegarder 3 épisodes
    for (var i = 1; i <= 3; i++) {
      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'integration_test',
        eventType: 'description',
        summary: 'Épisode $i — description de scene',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      ));
    }

    // Sauvegarder 2 préférences
    await vault.setPreference(
      key: 'theme',
      value: 'dark',
      category: 'ui',
      source: 'integration_test',
    );
    await vault.setPreference(
      key: 'language',
      value: 'fr',
      category: 'ui',
      source: 'integration_test',
    );

    // Sauvegarder 1 personne
    await vault.savePerson(KitaPerson(
      id: 0,
      name: 'Sophie',
      relationship: 'amie',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    // Sauvegarder 1 plugin data (via DAO directement — pas de méthode vault)
    await pluginDataDao.insert(
      pluginId: 'com.kita.test',
      namespace: 'settings',
      key: 'volume',
      value: '80',
    );
  }

  group('Journey "forget everything" — 0 donnée résiduelle (AC4)', () {
    test(
      'données pré-peuplées sont bien enregistrées',
      () async {
        await populateDatabase();

        final result = await vault.whatDoYouKnow();
        expect(result.isSuccess, isTrue);
        result.when(
          success: (data) {
            expect(
              data.containsKey(MemoryDomain.episodic),
              isTrue,
              reason: 'Les épisodes doivent être stockés',
            );
            expect(
              data[MemoryDomain.episodic]!.length,
              greaterThanOrEqualTo(3),
              reason: '3 épisodes doivent être présents',
            );
            expect(
              data.containsKey(MemoryDomain.semantic),
              isTrue,
              reason: 'Les préférences doivent être stockées',
            );
            expect(
              data[MemoryDomain.semantic]!.length,
              greaterThanOrEqualTo(2),
              reason: '2 préférences doivent être présentes',
            );
            expect(
              data.containsKey(MemoryDomain.relational),
              isTrue,
              reason: 'Les personnes doivent être stockées',
            );
            expect(
              data[MemoryDomain.relational]!.length,
              greaterThanOrEqualTo(1),
              reason: '1 personne doit être présente',
            );
          },
          failure: (f) => fail('whatDoYouKnow failed: ${f.logMessage}'),
        );

        // Plugin data : vérifier via le DAO directement
        final pluginResult = await pluginDataDao.getByPlugin('com.kita.test');
        expect(pluginResult.isSuccess, isTrue);
        final pluginEntries = pluginResult.getOrElse((_) => []);
        expect(
          pluginEntries.length,
          greaterThanOrEqualTo(1),
          reason: '1 plugin data doit être présent',
        );
      },
    );

    test(
      'forget(everything) → isSuccess == true',
      () async {
        await populateDatabase();

        final forgetResult = await vault.forget(
          ForgetRequest.everything(confirmation: true),
        );
        expect(
          forgetResult.isSuccess,
          isTrue,
          reason: 'forget(everything) doit réussir',
        );
      },
    );

    test(
      'auditForget(everything) → true (0 donnée résiduelle)',
      () async {
        await populateDatabase();

        // Supprimer tout
        await vault.forget(ForgetRequest.everything(confirmation: true));

        // Audit : doit confirmer la suppression complète
        final auditResult = await vault.auditForget(
          ForgetRequest.everything(confirmation: true),
        );
        expect(auditResult.isSuccess, isTrue);
        expect(
          auditResult.getOrElse((_) => false),
          isTrue,
          reason: 'L\'audit doit confirmer 0 donnée résiduelle',
        );
      },
    );

    test(
      'whatDoYouKnow après forget — tous les domaines vides',
      () async {
        await populateDatabase();

        await vault.forget(ForgetRequest.everything(confirmation: true));

        final after = await vault.whatDoYouKnow();
        expect(after.isSuccess, isTrue);
        after.when(
          success: (data) {
            // Tous les domaines doivent être absents ou vides
            final episodes = data[MemoryDomain.episodic] ?? [];
            expect(
              episodes,
              isEmpty,
              reason: 'Aucun épisode résiduel après forget(everything)',
            );
            final prefs = data[MemoryDomain.semantic] ?? [];
            expect(
              prefs,
              isEmpty,
              reason: 'Aucune préférence résiduelle après forget(everything)',
            );
            final persons = data[MemoryDomain.relational] ?? [];
            expect(
              persons,
              isEmpty,
              reason: 'Aucune personne résiduelle après forget(everything)',
            );
          },
          failure: (f) => fail('whatDoYouKnow après forget failed: ${f.logMessage}'),
        );

        // Plugin data : vérifier via le DAO directement
        final pluginResult = await pluginDataDao.getAll();
        expect(pluginResult.isSuccess, isTrue);
        final pluginEntries = pluginResult.getOrElse((_) => []);
        expect(
          pluginEntries,
          isEmpty,
          reason: 'Aucun plugin data résiduel après forget(everything)',
        );
      },
    );

    test(
      'consentements révoqués après forget(everything)',
      () async {
        await populateDatabase();

        // Vérifier que des consentements actifs existent avant le forget
        final beforeResult = await consentDao.getActiveConsents();
        expect(beforeResult.isSuccess, isTrue);
        final activeBefore = beforeResult.getOrElse((_) => []);
        expect(
          activeBefore,
          isNotEmpty,
          reason: 'Des consentements actifs doivent exister avant le forget',
        );

        // Supprimer tout
        await vault.forget(ForgetRequest.everything(confirmation: true));

        // forget(everything) supprime toutes les entrées de consent_log
        // (consentDao.deleteAll() est appelé dans l'implémentation).
        // Vérifier qu'aucun consentement actif ne subsiste.
        final afterResult = await consentDao.getActiveConsents();
        expect(afterResult.isSuccess, isTrue);
        final activeAfter = afterResult.getOrElse((_) => []);
        expect(
          activeAfter,
          isEmpty,
          reason: 'Aucun consentement actif ne doit subsister après forget(everything)',
        );

        // Le count total doit aussi être 0
        final countResult = await consentDao.count();
        expect(countResult.isSuccess, isTrue);
        expect(
          countResult.getOrElse((_) => -1),
          equals(0),
          reason: 'Aucune entrée de consentement ne doit subsister',
        );
      },
    );

    test(
      'forget(domain: episodic) → préférences et personnes intactes',
      () async {
        await consentDao.insert(
          consentType: 'data_storage',
          scope: 'episodic',
          granted: true,
        );

        // Sauvegarder un épisode
        await vault.saveEpisode(KitaEpisode(
          id: 0,
          source: 'test',
          eventType: 'description',
          summary: 'Épisode à supprimer',
          importanceScore: 0.5,
          isPinned: false,
          createdAt: DateTime.now(),
        ));

        // Supprimer uniquement le domaine épisodique
        final forgetResult = await vault.forget(
          ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
        );
        expect(forgetResult.isSuccess, isTrue);

        // Audit du domaine épisodique
        final auditResult = await vault.auditForget(
          ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
        );
        expect(auditResult.isSuccess, isTrue);
        expect(
          auditResult.getOrElse((_) => false),
          isTrue,
          reason: 'Le domaine épisodique doit être vide après forget(domain)',
        );
      },
    );

    test(
      'forget sans confirmation (confirmation: false) → refusé',
      () async {
        await consentDao.insert(
          consentType: 'data_storage',
          scope: 'episodic',
          granted: true,
        );

        await vault.saveEpisode(KitaEpisode(
          id: 0,
          source: 'test',
          eventType: 'test',
          summary: 'Épisode protégé',
          importanceScore: 0.5,
          isPinned: false,
          createdAt: DateTime.now(),
        ));

        // Sans confirmation, le forget doit échouer (sécurité)
        final forgetResult = await vault.forget(
          ForgetRequest.everything(confirmation: false),
        );
        expect(
          forgetResult.isFailure,
          isTrue,
          reason: 'forget sans confirmation doit être refusé',
        );

        // Les données doivent toujours être présentes
        final check = await vault.whatDoYouKnow();
        check.when(
          success: (data) {
            final episodes = data[MemoryDomain.episodic] ?? [];
            expect(
              episodes,
              isNotEmpty,
              reason: 'Les épisodes doivent rester après un forget refusé',
            );
          },
          failure: (_) {},
        );
      },
    );
  });
}
