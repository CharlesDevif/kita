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
import 'package:kita/features/memory/data/memory_consent.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';

import '../../../mocks/mock_secure_key_vault.dart';

void main() {
  late KitaDatabase db;
  late MemoryVaultImpl vault;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    vault = MemoryVaultImpl(
      episodeDao: EpisodeDao(db),
      preferenceDao: PreferenceDao(db),
      personDao: PersonDao(db),
      profileDao: ProfileDao(db),
      pluginDataDao: PluginDataDao(db),
      consentDao: ConsentDao(db),
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('ensureGranted accorde les deux scopes sur un coffre neuf', () async {
    await MemoryConsent.ensureGranted(vault);

    expect(
      (await vault.hasConsent(consentType: 'data_storage', scope: 'episodic'))
          .getOrNull(),
      isTrue,
    );
    expect(
      (await vault.hasConsent(consentType: 'data_storage', scope: 'semantic'))
          .getOrNull(),
      isTrue,
    );
  });

  test('ensureGranted est idempotent : deux appels, pas de doublon', () async {
    await MemoryConsent.ensureGranted(vault);
    await MemoryConsent.ensureGranted(vault);

    final consents = (await vault.getConsents()).getOrNull()!;
    expect(consents.where((c) => c.granted), hasLength(2)); // episodic + semantic
  });

  test('après ensureGranted, une écriture de préférence réussit', () async {
    await MemoryConsent.ensureGranted(vault);
    final result = await vault.setPreference(
      key: 'fact:test', value: 'un fait', category: 'user_fact', source: 'explicit',
    );
    expect(result.isSuccess, isTrue);
  });

  test('sans consentement, une écriture de préférence échoue', () async {
    final result = await vault.setPreference(
      key: 'fact:test', value: 'un fait', category: 'user_fact', source: 'explicit',
    );
    expect(result.isSuccess, isFalse);
  });

  test('revokeAll coupe les écritures', () async {
    await MemoryConsent.ensureGranted(vault);
    await MemoryConsent.revokeAll(vault);
    final result = await vault.saveEpisode(KitaEpisode(
      id: 0,
      source: 'test',
      eventType: 'scene_description',
      summary: 'bureau',
      importanceScore: 0.3,
      isPinned: false,
      createdAt: DateTime(2026, 7, 9),
    ));
    expect(result.isSuccess, isFalse);
  });

  test('ensureGranted ne ré-accorde pas si l\'utilisateur a coupé l\'interrupteur',
      () async {
    final keyVault = MockSecureKeyVault();
    await keyVault.write(memoryConsentOptOutKey, 'true');

    await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
    expect((await vault.getConsents()).getOrNull(), isEmpty);
  });

  test('après forget(everything), le consentement est ré-accordé', () async {
    await MemoryConsent.ensureGranted(vault);
    await vault.forget(ForgetRequest.everything(confirmation: true));
    expect((await vault.getConsents()).getOrNull(), isEmpty); // deleteAll a frappé

    await MemoryConsent.ensureGranted(vault);
    final result = await vault.setPreference(
      key: 'fact:x', value: 'y', category: 'user_fact', source: 'explicit',
    );
    expect(result.isSuccess, isTrue); // la mémoire n'est pas lobotomisée
  });

  group('opt-out / grantAgain', () {
    test('revokeAll mémorise l\'opt-out : ensureGranted suivant ne ré-accorde pas',
        () async {
      final keyVault = MockSecureKeyVault();
      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
      await MemoryConsent.revokeAll(vault, keyVault: keyVault);

      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
      final consents = (await vault.getConsents()).getOrNull()!;
      expect(consents.where((c) => c.granted && c.revokedAt == null), isEmpty);
    });

    test('grantAgain efface l\'opt-out et ré-accorde', () async {
      final keyVault = MockSecureKeyVault();
      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
      await MemoryConsent.revokeAll(vault, keyVault: keyVault);

      await MemoryConsent.grantAgain(vault, keyVault: keyVault);
      expect(await MemoryConsent.isGranted(vault), isTrue);
    });
  });

  group('opt-out illisible (échec de lecture du coffre sécurisé)', () {
    // DÉFAUT 1 : un échec de lecture du coffre (Keystore indisponible,
    // erreur transitoire...) est indistinguable d'une clé absente une fois
    // passé par `Result.getOrNull()`. Les deux valent `null`. Sans
    // distinction, un opt-out devenu illisible est traité comme "jamais
    // choisi" et le bootstrap ré-accorde dans le dos de l'utilisateur.
    test(
        'Failure de lecture de l\'opt-out : ensureGranted n\'accorde aucun '
        'consentement (fail-closed)', () async {
      final keyVault = MockSecureKeyVault()..shouldFail = true;

      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);

      expect((await vault.getConsents()).getOrNull(), isEmpty);
    });

    test(
        'Success(null) (clé absente, premier lancement) : ensureGranted '
        'accorde normalement même avec un keyVault fourni', () async {
      final keyVault = MockSecureKeyVault(); // store vide, shouldFail = false

      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);

      final consents = (await vault.getConsents()).getOrNull()!;
      expect(consents.where((c) => c.granted), hasLength(2));
    });
  });

  group('revokeAll persiste l\'opt-out avant de révoquer', () {
    // DÉFAUT 2 : l'ordre initial (révoquer, puis écrire l'opt-out sans
    // vérifier le résultat) laisse le consentement retiré mais l'opt-out
    // jamais mémorisé si l'écriture échoue — le prochain bootstrap
    // ré-accorde silencieusement.
    test(
        'write en échec : revokeAll renvoie Failure et ne révoque rien',
        () async {
      final keyVault = MockSecureKeyVault();
      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
      keyVault.shouldFail = true; // le coffre devient illisible/inscriptible

      final result = await MemoryConsent.revokeAll(vault, keyVault: keyVault);

      expect(result.isFailure, isTrue);
      expect(
        await MemoryConsent.isGranted(vault),
        isTrue,
        reason: 'le consentement doit rester actif tant que l\'opt-out '
            'n\'est pas persisté',
      );
    });

    test('write en succès : revokeAll renvoie Success et révoque bien',
        () async {
      final keyVault = MockSecureKeyVault();
      await MemoryConsent.ensureGranted(vault, keyVault: keyVault);

      final result = await MemoryConsent.revokeAll(vault, keyVault: keyVault);

      expect(result.isSuccess, isTrue);
      expect(await MemoryConsent.isGranted(vault), isFalse);
    });
  });

  group('ensureGranted sérialise les appels concurrents', () {
    // DÉFAUT 3 (TOCTOU) : `hasConsent` puis `grantConsent` ne sont pas
    // atomiques. Deux appels concurrents (bootstrap + ré-accord après
    // `forget`) pourraient chacun voir "pas encore consenti" avant que
    // l'autre n'ait inséré sa ligne, doublant les lignes de consentement.
    test('deux ensureGranted en parallèle : 2 lignes de consentement, pas 4',
        () async {
      await Future.wait([
        MemoryConsent.ensureGranted(vault),
        MemoryConsent.ensureGranted(vault),
      ]);

      final consents = (await vault.getConsents()).getOrNull()!;
      expect(consents.where((c) => c.granted), hasLength(2));
    });
  });
}
