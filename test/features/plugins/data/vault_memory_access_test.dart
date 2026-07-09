import 'package:flutter_test/flutter_test.dart';

import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/plugins/data/vault_memory_access.dart';

/// Fake minimal de [MemoryVault] pour tester [VaultMemoryAccess] en
/// isolation. Seules les 3 opérations consommées par l'adaptateur sont
/// implémentées ; le reste de l'interface retombe sur `noSuchMethod`
/// (même patron que `_AuditFailsVault` dans `forget_screen_test.dart`).
class FakeMemoryVault implements MemoryVault {
  final List<KitaEpisode> savedEpisodes = [];

  ({String key, String value, String category, String source})?
      lastPreference;

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    savedEpisodes.add(episode);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
    required String source,
  }) async {
    lastPreference =
        (key: key, value: value, category: category, source: source);
    return const Result.success(null);
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    final pref = lastPreference;
    if (pref == null || pref.key != key) return const Result.success(null);
    return Result.success(pref.value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('délègue saveEpisode au vault', () async {
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async => vault);

    final result = await access.saveEpisode(KitaEpisode(
      id: 0,
      source: 'test',
      eventType: 'scene_description',
      summary: 'bureau',
      importanceScore: 0.3,
      isPinned: false,
      createdAt: DateTime(2026, 7, 9),
    ));

    expect(result.isSuccess, isTrue);
    expect(vault.savedEpisodes, hasLength(1));
  });

  test('setPreference comble category/source absents de MemoryAccess',
      () async {
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async => vault);

    await access.setPreference('couleur', 'bleu');

    expect(vault.lastPreference!.category, equals('plugin_data'));
    expect(vault.lastPreference!.source, equals('plugin'));
  });

  test('le vault n\'est chargé qu\'une fois, au premier appel', () async {
    var loads = 0;
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async {
      loads++;
      return vault;
    });

    expect(loads, equals(0)); // paresseux : rien à la construction
    await access.getPreference('a');
    await access.getPreference('b');
    expect(loads, equals(1));
  });

  test('un vault qui ne se charge pas renvoie une failure, sans exception',
      () async {
    final access = VaultMemoryAccess(
      vaultLoader: () async => throw StateError('db locked'),
    );
    final result = await access.getPreference('a');
    expect(result.isSuccess, isFalse);
  });

  test(
      'deux appels concurrents avant résolution ne déclenchent le loader '
      "qu'une seule fois", () async {
    // DÉFAUT C : seule la valeur résolue (_vault) était mémorisée, pas le
    // Future en vol. Deux appels lancés avant que le premier ne se
    // résolve appelaient chacun _vaultLoader(). Ce test échoue (loads == 2)
    // tant que le Future en vol n'est pas mémoïsé.
    var loads = 0;
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async {
      loads++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return vault;
    });

    await Future.wait([
      access.getPreference('a'),
      access.getPreference('b'),
    ]);

    expect(loads, equals(1));
  });

  test('après un échec de chargement, un appel ultérieur retente',
      () async {
    var loads = 0;
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async {
      loads++;
      if (loads == 1) throw StateError('db locked');
      return vault;
    });

    final first = await access.getPreference('a');
    expect(first.isSuccess, isFalse);
    expect(loads, equals(1));

    final second = await access.getPreference('a');
    expect(second.isSuccess, isTrue);
    expect(loads, equals(2));
  });
}
