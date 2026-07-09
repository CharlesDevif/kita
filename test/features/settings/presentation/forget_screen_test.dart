import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:kita/features/memory/data/memory_consent.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/di/providers.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/memory/domain/secure_key_vault.dart';
import 'package:kita/features/settings/presentation/forget_screen.dart';

import '../../../mocks/mock_secure_key_vault.dart';

/// Fake vault whose erasure "succeeds" but whose audit reports residual data,
/// to exercise the honest-failure path without a contrived real DB state.
class _AuditFailsVault implements MemoryVault {
  @override
  Future<Result<void>> forget(ForgetRequest request) async =>
      const Result.success(null);

  @override
  Future<Result<bool>> auditForget(ForgetRequest request) async =>
      const Result.success(false);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late KitaDatabase db;
  late MemoryVaultImpl vault;
  late ConsentDao consentDao;
  late ProfileDao profileDao;
  late PluginDataDao pluginDataDao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    consentDao = ConsentDao(db);
    profileDao = ProfileDao(db);
    pluginDataDao = PluginDataDao(db);
    vault = MemoryVaultImpl(
      episodeDao: EpisodeDao(db),
      preferenceDao: PreferenceDao(db),
      personDao: PersonDao(db),
      profileDao: profileDao,
      pluginDataDao: pluginDataDao,
      consentDao: consentDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Grants data_storage consent for a domain scope.
  Future<void> grantConsentFor(String scope) async {
    await consentDao.insert(
      consentType: 'data_storage',
      scope: scope,
      granted: true,
    );
  }

  /// Seeds one episode and one preference so there is data to erase.
  Future<void> seedData() async {
    await grantConsentFor('episodic');
    await grantConsentFor('semantic');
    await vault.saveEpisode(KitaEpisode(
      id: 0,
      source: 'camera',
      eventType: 'describe',
      summary: 'Une scène de parc',
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
    // `profile` et `plugin_data` sont semées explicitement : sans cela, les
    // assertions « count == 0 » après effacement seraient vraies avant même
    // l'effacement, et ne prouveraient rien.
    await profileDao.insert(displayName: 'Marie');
    await pluginDataDao.insert(
      pluginId: 'com.kita.describe',
      namespace: 'cache',
      key: 'derniere_scene',
      value: 'un parc',
    );
  }

  /// Pumps the ForgetScreen with the real [vault] injected.
  ///
  /// When [vaultOverride] is provided it replaces the default resolved-value
  /// override (used to exercise the loading state). When [keyVault] is
  /// provided it replaces the default fresh [MockSecureKeyVault] — used to
  /// pre-seed an opt-out before "Tout effacer" runs.
  Future<void> pumpScreen(
    WidgetTester tester, {
    FutureOr<MemoryVault> Function(Ref ref)? vaultOverride,
    SecureKeyVault? keyVault,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryVaultProvider.overrideWith(
            vaultOverride ?? (ref) => vault,
          ),
          // Après « tout effacer », ForgetScreen ré-accorde le consentement
          // via MemoryConsent.ensureGranted, qui lit le key vault sécurisé
          // pour vérifier un éventuel opt-out.
          secureKeyVaultProvider.overrideWithValue(
            keyVault ?? MockSecureKeyVault(),
          ),
        ],
        child: const MaterialApp(home: ForgetScreen()),
      ),
    );
  }

  group('ForgetScreen — intégration Drift réelle', () {
    testWidgets('Tout effacer supprime toutes les données et vérifie',
        (tester) async {
      await seedData();
      // Sans ces deux gardes, un seed défaillant rendrait vacantes les
      // assertions « count == 0 » qui suivent l'effacement.
      expect((await profileDao.count()).getOrNull(), equals(1));
      expect((await pluginDataDao.count()).getOrNull(), equals(1));

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // Double-step: sélection puis confirmation.
      await tester.tap(find.byKey(const Key('forget_everything')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forget_confirm')), findsOneWidget);

      await tester.tap(find.byKey(const Key('forget_confirm')));
      await tester.pumpAndSettle();

      // Message de succès vérifié affiché.
      expect(find.text('Données effacées et vérifiées.'), findsOneWidget);

      // La base est réellement vide.
      final known = (await vault.whatDoYouKnow()).getOrNull()!;
      expect(known, isEmpty);

      // whatDoYouKnow() ne couvre pas profile/plugin_data (pas de domaine
      // MemoryDomain associé) : attestées vides directement via leur DAO,
      // sinon seul le message UI en répondrait.
      expect((await profileDao.count()).getOrNull(), equals(0));
      expect((await pluginDataDao.count()).getOrNull(), equals(0));

      // Le consentement de stockage a été ré-accordé après l'effacement total
      // (consentDao.deleteAll() l'avait aussi supprimé) : sans ce garde-fou,
      // la mémoire resterait désactivée pour toujours.
      final consents = (await vault.getConsents()).getOrNull()!;
      expect(
        consents.where((c) => c.granted && c.revokedAt == null),
        hasLength(2),
      );

      // Preuve concrète : une écriture de préférence réussit à nouveau.
      final rewrite = await vault.setPreference(
        key: 'fact:apres_effacement',
        value: 'ok',
        category: 'user_fact',
        source: 'explicit',
      );
      expect(rewrite.isSuccess, isTrue);
    });

    testWidgets(
        'Tout effacer respecte un opt-out déjà actif : le consentement '
        "n'est pas ré-accordé", (tester) async {
      await seedData();

      final keyVault = MockSecureKeyVault();
      await keyVault.write(memoryConsentOptOutKey, 'true');

      await pumpScreen(tester, keyVault: keyVault);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_everything')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forget_confirm')), findsOneWidget);

      await tester.tap(find.byKey(const Key('forget_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Données effacées et vérifiées.'), findsOneWidget);

      // L'opt-out explicite doit survivre à « tout effacer » :
      // onPurgeExternal ne purge que les clés API, jamais
      // memory_consent_opt_out, donc MemoryConsent.ensureGranted (appelé par
      // ForgetScreen après l'effacement) ne doit ré-accorder AUCUNE ligne de
      // consentement actif. Si un futur onPurgeExternal se mettait à effacer
      // aussi l'opt-out, ce test échouerait.
      final consents = (await vault.getConsents()).getOrNull()!;
      expect(
        consents.where((c) => c.granted && c.revokedAt == null),
        isEmpty,
      );
    });

    testWidgets('Effacer une catégorie ne supprime que ce domaine',
        (tester) async {
      await seedData();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_domain')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_domain_episodic')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forget_confirm')), findsOneWidget);

      await tester.tap(find.byKey(const Key('forget_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Données effacées et vérifiées.'), findsOneWidget);

      // Les épisodes sont partis...
      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, isEmpty);

      // ...mais les préférences subsistent.
      final pref = (await vault.getPreference('theme')).getOrNull();
      expect(pref, equals('dark'));
    });

    testWidgets('Annuler la confirmation ne supprime rien', (tester) async {
      await seedData();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_everything')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_cancel')));
      await tester.pumpAndSettle();

      // Retour au menu.
      expect(find.byKey(const Key('forget_everything')), findsOneWidget);

      // Les données sont intactes.
      final episodes = (await vault.getEpisodes()).getOrNull()!;
      expect(episodes, hasLength(1));
    });
  });

  group('ForgetScreen — états', () {
    testWidgets('affiche le chargement tant que le vault n\'est pas prêt',
        (tester) async {
      await pumpScreen(
        tester,
        vaultOverride: (ref) => Future<MemoryVault>.delayed(
          const Duration(milliseconds: 300),
          () => vault,
        ),
      );

      // Premier frame : le vault est encore en cours de résolution.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement…'), findsOneWidget);

      // Une fois résolu, le menu apparaît.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('forget_everything')), findsOneWidget);
    });

    testWidgets('affiche un échec honnête si des données subsistent',
        (tester) async {
      await pumpScreen(tester, vaultOverride: (ref) => _AuditFailsVault());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_everything')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('forget_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Données effacées et vérifiées.'), findsNothing);
      expect(find.textContaining('Effacement incomplet'), findsOneWidget);
    });
  });

  group('ForgetScreen — accessibilité', () {
    testWidgets('les options ont des labels sémantiques descriptifs',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Tout effacer')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Effacer une catégorie')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('le bouton Tout effacer respecte la cible tactile critique',
        (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const Key('forget_everything')));
      expect(size.height, greaterThanOrEqualTo(56));
    });

    testWidgets('le bouton de confirmation respecte la cible tactile critique',
        (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget_everything')));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const Key('forget_confirm')));
      expect(size.height, greaterThanOrEqualTo(56));
    });
  });
}
