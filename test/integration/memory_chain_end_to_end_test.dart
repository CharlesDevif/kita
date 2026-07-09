// Preuve bout-en-bout que le cycle « mémoire vivante » aboutit réellement,
// avec une VRAIE base Drift en mémoire (pas de mock DB) :
//
//   plugin/agent -> VaultMemoryAccess -> MemoryVaultImpl -> Drift (SQLite)
//
// Deux causes racines rendaient cette chaîne inerte avant les Tâches 3 et
// 3bis :
//   1. pluginSandboxProvider ne construisait jamais de memoryAccess, donc
//      context.memory restait null (Tâche 3, VaultMemoryAccess).
//   2. saveEpisode/setPreference sont verrouillés par un consentement
//      'data_storage' que rien n'accordait en production (Tâche 3bis,
//      MemoryConsent).
//
// Ce test construit la chaîne réelle (sans provider Riverpod, pour isoler la
// preuve du câblage DI) et vérifie que :
//   - sans consentement, l'écriture échoue proprement (pas d'exception) ;
//   - après MemoryConsent.ensureGranted, l'écriture réussit ET l'épisode est
//     réellement relu par vault.getEpisodes() — pas seulement un Result de
//     succès en façade.
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
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/plugins/data/vault_memory_access.dart';

void main() {
  late KitaDatabase db;
  late MemoryVault vault;

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

  KitaEpisode episode({String summary = 'Une scène de bureau'}) => KitaEpisode(
        id: 0,
        source: 'com.kita.describe',
        eventType: 'scene_description',
        summary: summary,
        importanceScore: 0.4,
        isPinned: false,
        createdAt: DateTime(2026, 7, 9),
      );

  group('Chaîne mémoire vivante — bout-en-bout, base Drift réelle', () {
    test(
        'sans consentement, VaultMemoryAccess.saveEpisode échoue (chaîne '
        'complète, DB réelle)', () async {
      final access = VaultMemoryAccess(vaultLoader: () async => vault);

      final result = await access.saveEpisode(episode());

      expect(result.isSuccess, isFalse);
      // Rien n'a réellement été écrit : la façade "success" ne peut pas
      // mentir puisqu'on relit la vraie table.
      final stored = (await vault.getEpisodes()).getOrNull()!;
      expect(stored, isEmpty);
    });

    test(
        'avec consentement accordé via MemoryConsent, saveEpisode aboutit et '
        "l'épisode est réellement relu par vault.getEpisodes()", () async {
      // (1) Accorde le consentement — Tâche 3bis, désamorce le deuxième
      // interblocage (grantConsent n'a aucun autre appelant en prod).
      await MemoryConsent.ensureGranted(vault);

      // (2) Construit le maillon terminal réel — Tâche 3, sans lequel
      // context.memory reste null pour tout agent/plugin.
      final access = VaultMemoryAccess(vaultLoader: () async => vault);

      // (3) Écrit à travers VaultMemoryAccess, comme le ferait un agent via
      // AgentContext.memory ou un plugin via PluginRequest.memory.
      final result = await access.saveEpisode(episode(summary: 'Le salon'));
      expect(result.isSuccess, isTrue);

      // (4) Relit directement depuis le vault : preuve que la donnée a
      // atteint la table Drift, pas seulement un mock en mémoire du test.
      final stored = (await vault.getEpisodes()).getOrNull()!;
      expect(stored, hasLength(1));
      expect(stored.single.summary, equals('Le salon'));
      expect(stored.single.source, equals('com.kita.describe'));
    });

    test(
        'le même round-trip fonctionne pour setPreference/getPreference '
        '(comblement category/source)', () async {
      await MemoryConsent.ensureGranted(vault);
      final access = VaultMemoryAccess(vaultLoader: () async => vault);

      final writeResult =
          await access.setPreference('theme_haptique', 'court');
      expect(writeResult.isSuccess, isTrue);

      // Relecture par le VRAI vault (pas par l'adaptateur) : la donnée est
      // bien dans la table `preference`, avec category/source par défaut.
      final prefs = (await vault.getPreferences()).getOrNull()!;
      expect(prefs, hasLength(1));
      expect(prefs.single.key, equals('theme_haptique'));
      expect(prefs.single.value, equals('court'));
      expect(prefs.single.category, equals('plugin_data'));
      expect(prefs.single.source, equals('plugin'));
    });
  });
}
