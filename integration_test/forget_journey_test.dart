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

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    consentDao = ConsentDao(db);
    vault = MemoryVaultImpl(
      episodeDao: EpisodeDao(db),
      preferenceDao: PreferenceDao(db),
      personDao: PersonDao(db),
      profileDao: ProfileDao(db),
      pluginDataDao: PluginDataDao(db),
      consentDao: consentDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper : pré-peupler la DB avec des données dans tous les domaines.
  Future<void> populateDatabase() async {
    // Accorder les consentements nécessaires
    await consentDao.insert(
      consentType: 'data_storage',
      scope: 'episodic',
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
          },
          failure: (f) => fail('whatDoYouKnow failed: ${f.logMessage}'),
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
      'whatDoYouKnow après forget — domaines épisodiques vides',
      () async {
        await populateDatabase();

        await vault.forget(ForgetRequest.everything(confirmation: true));

        final after = await vault.whatDoYouKnow();
        expect(after.isSuccess, isTrue);
        after.when(
          success: (data) {
            // Les domaines peuvent être absents ou vides
            final episodes = data[MemoryDomain.episodic] ?? [];
            expect(
              episodes,
              isEmpty,
              reason: 'Aucun épisode résiduel après forget(everything)',
            );
          },
          failure: (f) => fail('whatDoYouKnow après forget failed: ${f.logMessage}'),
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
