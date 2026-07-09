# Mémoire vivante — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Brancher la mémoire longue de Kita — faits explicites, faits déduits, épisodes — et lui donner conscience de sa propre configuration.

**Architecture :** Le déclenchement mémoire est **déterministe en Dart**, jamais délégué au LLM (un Gemma 3n E2B choisit mal quand il a trop d'outils). Les faits sont injectés dans le prompt local ; les épisodes ne le sont jamais. Une passe d'extraction différée, hors du prompt de décision d'outil, retient ce que l'utilisateur n'a pas demandé de retenir.

**Tech Stack :** Flutter 3.41 / Dart 3.11, Riverpod 3.3, Drift + SQLCipher, flutter_gemma 0.12.4.

**Spec :** `docs/superpowers/specs/2026-07-09-memoire-vivante-design.md`

## Global Constraints

- **Zero PII dans les logs.** Jamais le contenu d'un fait ni d'un épisode. Journaliser `(source, len=N)` ou un compte. Vérifier chaque `_log.*()` avant de marquer « review ».
- **Accents français corrects** dans toute string affichée ou prononcée (`déduit`, pas `deduit`).
- **`sealed class KitaFailure` + `Result<T>`** — jamais de `throw` non typé. `KitaFailure` n'est **pas** une `Exception` : aux frontières natives, utiliser `on Object catch`.
- **`test()` + `ProviderContainer`** pour tout ce qui touche aux streams/notifiers. `testWidgets` uniquement quand `pumpWidget`/`tap` est nécessaire (sinon : hang de 10 minutes).
- **Au moins 1 test d'intégration réel par tâche** touchant la DB (Drift réel en mémoire, pas de mock DB).
- **Accessibility Tax** (toute tâche avec UI) : `Semantics` sur chaque widget interactif, contraste texte ≥ 4,5:1, cible tactile ≥ 48×48.
- **Ne jamais commiter** `*.g.dart` / `*.freezed.dart`.
- **Riverpod 3** : pas de `StateProvider`/`StateNotifierProvider` (déplacés dans `legacy.dart`).
- Après modification d'un modèle Drift : `dart run build_runner build --delete-conflicting-outputs`.
- Chaque tâche finit par `dart analyze --fatal-infos` (clean) et `flutter test` (vert).

**Tests décrits mais non rédigés.** Dans les tâches 6, 7 et 8, certains tests sont donnés
par leur nom et leurs assertions, avec un corps `/* ... */`. Ce n'est **pas** une
autorisation de les survoler : l'implémenteur écrit le corps complet, avec des données
réelles, et le relecteur rejette la tâche si un test n'assert rien ou duplique un autre.
Les tests dont le corps est écrit ici sont à reprendre **verbatim**.

**Catégorie et sources canoniques (valeurs exactes, utilisées telles quelles) :**
- `category` des faits utilisateur : `'user_fact'`
- `source` d'un fait dit explicitement : `'explicit'`
- `source` d'un fait déduit par extraction : `'inferred'`
- `source` d'une préférence écrite par un plugin : `'plugin'`, `category: 'plugin_data'`
- préfixe de clé d'un fait : `'fact:'`

---

## File Structure

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/features/memory/data/memory_vault_impl.dart` | corriger `ForgetScope.specific` | 1 |
| `lib/features/memory/domain/memory_intent.dart` | `sealed class MemoryIntent` | 2 |
| `lib/features/memory/data/memory_intent_parser.dart` | détection déterministe + normalisation | 2 |
| `lib/features/plugins/data/vault_memory_access.dart` | maillon terminal `MemoryVault → MemoryAccess` | 3 |
| `lib/features/orchestration/di/providers.dart` | câblage sandbox + LocalProvider + extractor | 3, 5, 7 |
| `lib/features/plugins/built_in/describe/describe_plugin.dart` | écrire l'épisode | 4 |
| `lib/features/ai/data/providers/local_provider.dart` | bloc de faits + ligne runtime | 5 |
| `lib/features/memory/data/user_facts.dart` | lecture/écriture des faits (slug, tri, plafonds) | 5 |
| `lib/features/orchestration/data/input_router.dart` | intentions mémoire avant le LLM | 6 |
| `lib/features/ai/data/providers/gemma_bridge.dart` | `hasWaitingRealOps` | 7 |
| `lib/features/orchestration/data/fact_extractor.dart` | extraction différée | 7 |
| `lib/features/settings/presentation/memory_screen.dart` | écran Mémoire (remplace le stub) | 8 |
| `lib/features/settings/presentation/settings_placeholder.dart` | accents + lien diagnostic | 8 |

---

### Task 1: `ForgetScope.specific` efface aussi les faits, et ne ment jamais

**Contexte.** Aujourd'hui (`memory_vault_impl.dart:319-325`), `specific` boucle sur `specificIds`, fait `int.tryParse`, et supprime un épisode. Une clé de préférence (non numérique) est **ignorée en silence** : `forget()` renvoie `Result.success` sans rien avoir effacé. L'écran Mémoire de la tâche 8 en dépend.

**Files:**
- Modify: `lib/features/memory/data/memory_vault_impl.dart` (branche `ForgetScope.specific`)
- Test: `test/features/memory/data/memory_vault_impl_test.dart`

**Interfaces:**
- Consomme : `PreferenceDao.deleteByKey(String key) → Future<Result<int>>` (nombre de lignes supprimées), `EpisodeDao.deleteById(int id)`.
- Produit : rien de nouveau. Le contrat de `forget(ForgetRequest.specific([...]))` change : un identifiant qui ne correspond à rien renvoie `Result.failure(StorageFailure)`.

**Règle :** un `specificIds` entièrement numérique → épisodes. Une entrée préfixée `fact:` → préférence, via `deleteByKey`. Toute entrée qui ne supprime **aucune** ligne → `Result.failure`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/features/memory/data/memory_vault_impl_test.dart`, avec une **vraie base Drift en mémoire** (suivre le pattern déjà présent dans ce fichier) :

```dart
test('forget(specific) supprime une préférence par clé', () async {
  await vault.setPreference(
    key: 'fact:frere_paul', value: "mon frère s'appelle Paul",
    category: 'user_fact', source: 'explicit',
  );

  final result = await vault.forget(
    ForgetRequest.specific(const ['fact:frere_paul'], confirmation: true),
  );

  expect(result.isSuccess, isTrue);
  final prefs = (await vault.getPreferences()).getOrNull()!;
  expect(prefs.where((p) => p.key == 'fact:frere_paul'), isEmpty);
});

test('forget(specific) sur une clé inconnue échoue, jamais un succès silencieux',
    () async {
  final result = await vault.forget(
    ForgetRequest.specific(const ['fact:nexiste_pas'], confirmation: true),
  );
  expect(result.isSuccess, isFalse);
});

test('forget(specific) supprime toujours les épisodes par identifiant', () async {
  await vault.saveEpisode(KitaEpisode(
    id: 0, source: 'test', eventType: 'scene_description', summary: 'un bureau',
    importanceScore: 0.3, isPinned: false, createdAt: DateTime(2026, 7, 9),
  ));
  final saved = (await vault.getEpisodes()).getOrNull()!.single;

  final result = await vault.forget(
    ForgetRequest.specific(['${saved.id}'], confirmation: true),
  );

  expect(result.isSuccess, isTrue);
  expect((await vault.getEpisodes()).getOrNull(), isEmpty);
});
```

- [ ] **Step 2: Lancer les tests, vérifier qu'ils échouent**

Run: `flutter test test/features/memory/data/memory_vault_impl_test.dart`
Expected: FAIL — la clé de préférence n'est pas supprimée ; la clé inconnue renvoie `success`.

- [ ] **Step 3: Implémenter**

Remplacer la branche `case ForgetScope.specific:` :

```dart
case ForgetScope.specific:
  if (request.specificIds.isEmpty) {
    return const Result.failure(StorageFailure(
      userMessage: 'Rien à effacer.',
      logMessage: 'Forget specific request with no ids',
    ));
  }
  for (final idStr in request.specificIds) {
    final deleted = await _forgetSpecificId(idStr);
    if (deleted == 0) {
      // Jamais de succès silencieux : l'écran Mémoire afficherait « supprimé »
      // sur une ligne toujours présente en base.
      _log.warning('Forget specific: no row matched');
      return const Result.failure(StorageFailure(
        userMessage: "Cet élément n'existe plus.",
        logMessage: 'Forget specific: id matched no row',
      ));
    }
  }
  _log.info('Specific entries deleted (count=${request.specificIds.length})');
```

Et la méthode privée, à ajouter dans la classe :

```dart
/// Supprime une entrée désignée par [idStr] et renvoie le nombre de lignes
/// effacées. Une clé préfixée `fact:` vise le domaine sémantique ; un entier
/// vise un épisode.
Future<int> _forgetSpecificId(String idStr) async {
  if (idStr.startsWith(userFactKeyPrefix)) {
    final result = await preferenceDao.deleteByKey(idStr);
    return result.getOrNull() ?? 0;
  }
  final id = int.tryParse(idStr);
  if (id == null) return 0;
  final result = await episodeDao.deleteById(id);
  return result.getOrNull() ?? 0;
}
```

`userFactKeyPrefix` est défini **ici**, en tête de `memory_vault_impl.dart`, et importé par
`user_facts.dart` en Tâche 5 (jamais l'inverse — sinon dépendance circulaire) :

```dart
/// Préfixe des clés de préférence portant un fait utilisateur.
const String userFactKeyPrefix = 'fact:';
```

`EpisodeDao.deleteById` renvoie déjà `Future<Result<int>>` (`episode_dao.dart:118`) et
`PreferenceDao.deleteByKey` aussi (`preference_dao.dart:148`) : rien à adapter, le nombre
de lignes supprimées est directement exploitable.

- [ ] **Step 4: Lancer les tests, vérifier qu'ils passent**

Run: `flutter test test/features/memory/data/memory_vault_impl_test.dart`
Expected: PASS

- [ ] **Step 5: Vérifier la non-régression de l'écran d'oubli**

Run: `flutter test test/features/settings/ test/features/memory/`
Expected: PASS. `ForgetScreen` utilise `everything`/`domain`, pas `specific` — mais le vérifier.

- [ ] **Step 6: Commit**

```bash
git add lib/features/memory/data/memory_vault_impl.dart test/features/memory/data/memory_vault_impl_test.dart
git commit -m "fix(memory): forget(specific) efface les faits et ne renvoie plus un succès silencieux"
```

---

### Task 2: `MemoryIntentParser` — détection déterministe

**Contexte.** Aucun outil `remember`/`recall` n'est exposé au LLM (décision de spec §1.2). Les intentions mémoire sont reconnues en Dart, avant tout appel au modèle. `VoiceCommandHandler.recognize` existe déjà mais renvoie un enum sans charge utile : il ne sait pas extraire « mon frère s'appelle Paul » de « retiens que mon frère s'appelle Paul ».

**Files:**
- Create: `lib/features/memory/domain/memory_intent.dart`
- Create: `lib/features/memory/data/memory_intent_parser.dart`
- Test: `test/features/memory/data/memory_intent_parser_test.dart`

**Interfaces:**
- Produit : `MemoryIntentParser.parse(String transcript) → MemoryIntent?` — consommé par `InputRouter` en Tâche 6.
- Produit : `sealed class MemoryIntent` avec `RememberFact(fact)`, `RecallFacts()`, `RecallEpisodes()`.

**Piège documenté (CLAUDE.md).** La reconnaissance se fait sur une forme normalisée (minuscules + accents retirés), mais le fait stocké doit **garder ses accents**. La normalisation doit donc mapper **un caractère sur exactement un caractère**, pour que les indices restent valides et qu'on puisse découper la chaîne **originale**. Un test le vérifie caractère par caractère.

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/memory/data/memory_intent_parser_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/memory/data/memory_intent_parser.dart';
import 'package:kita/features/memory/domain/memory_intent.dart';

void main() {
  group('normalizeForMatch', () {
    test('préserve la longueur, caractère par caractère', () {
      const samples = [
        'Retiens que mon frère s\'appelle Paul',
        'ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ',
        'àâäçéèêëîïôöùûüÿ',
        'Ça déménage, où ?',
      ];
      for (final s in samples) {
        expect(normalizeForMatch(s).length, equals(s.length), reason: s);
      }
    });

    test('retire les accents et met en minuscules', () {
      expect(normalizeForMatch('Frère'), equals('frere'));
    });
  });

  group('MemoryIntentParser.parse — RememberFact', () {
    test('extrait le fait après « retiens que », accents préservés', () {
      final intent = MemoryIntentParser.parse(
        "Retiens que mon frère s'appelle Paul",
      );
      expect(intent, isA<RememberFact>());
      expect((intent! as RememberFact).fact, equals("mon frère s'appelle Paul"));
    });

    test('reconnaît « souviens-toi que » et « rappelle-toi que »', () {
      expect(
        (MemoryIntentParser.parse('souviens-toi que je prends le bus à 8h')!
                as RememberFact)
            .fact,
        equals('je prends le bus à 8h'),
      );
      expect(
        (MemoryIntentParser.parse('Rappelle-toi que j\'aime le café')!
                as RememberFact)
            .fact,
        equals("j'aime le café"),
      );
    });

    test('« retiens » seul, sans « que »', () {
      expect(
        (MemoryIntentParser.parse('retiens mon code postal : 75011')!
                as RememberFact)
            .fact,
        equals('mon code postal : 75011'),
      );
    });

    test('un fait vide n\'est pas une intention', () {
      expect(MemoryIntentParser.parse('retiens que'), isNull);
      expect(MemoryIntentParser.parse('retiens'), isNull);
    });
  });

  group('MemoryIntentParser.parse — Recall', () {
    test('« qu\'est-ce que tu sais de moi » → RecallFacts', () {
      expect(
        MemoryIntentParser.parse('Qu\'est-ce que tu sais de moi ?'),
        isA<RecallFacts>(),
      );
      expect(MemoryIntentParser.parse('que sais-tu de moi'), isA<RecallFacts>());
    });

    test('« qu\'est-ce que j\'ai vu » → RecallEpisodes', () {
      expect(
        MemoryIntentParser.parse('qu\'est-ce que j\'ai vu aujourd\'hui ?'),
        isA<RecallEpisodes>(),
      );
      expect(MemoryIntentParser.parse('tu te souviens de ce que j\'ai vu'),
          isA<RecallEpisodes>());
    });
  });

  group('MemoryIntentParser.parse — aucune intention', () {
    test('une phrase ordinaire ne déclenche rien', () {
      expect(MemoryIntentParser.parse('bonjour, comment vas-tu ?'), isNull);
      expect(MemoryIntentParser.parse('décris ce que tu vois'), isNull);
    });

    test('transcript vide', () {
      expect(MemoryIntentParser.parse('   '), isNull);
    });
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/memory/data/memory_intent_parser_test.dart`
Expected: FAIL — `memory_intent_parser.dart` n'existe pas.

- [ ] **Step 3: `memory_intent.dart`**

```dart
/// Intention mémoire reconnue **sans appel au LLM**.
///
/// Aucun outil `remember`/`recall` n'est exposé au modèle : un Gemma 3n E2B
/// choisit d'autant plus mal qu'il a d'options (voir le bug `describe`,
/// spec 2026-07-09-progression-et-latence §5.6).
sealed class MemoryIntent {
  const MemoryIntent();
}

/// « retiens que mon frère s'appelle Paul »
final class RememberFact extends MemoryIntent {
  const RememberFact(this.fact);

  /// Texte original du fait, accents préservés.
  final String fact;
}

/// « qu'est-ce que tu sais de moi ? »
final class RecallFacts extends MemoryIntent {
  const RecallFacts();
}

/// « qu'est-ce que j'ai vu ? »
final class RecallEpisodes extends MemoryIntent {
  const RecallEpisodes();
}
```

- [ ] **Step 4: `memory_intent_parser.dart`**

```dart
import '../domain/memory_intent.dart';

/// Table d'accents. Chaque entrée mappe **un** caractère sur **un** caractère :
/// la normalisation préserve donc les indices, ce qui permet de découper la
/// chaîne originale (accents intacts) à partir d'une correspondance trouvée
/// sur la forme normalisée.
const Map<String, String> _accentFolding = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y',
  'ñ': 'n',
};

/// Minuscules + accents retirés, **sans changer la longueur**.
///
/// `œ`/`æ` sont volontairement absents : ils se déplieraient en deux
/// caractères et casseraient l'alignement des indices.
String normalizeForMatch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentFolding[char] ?? char);
  }
  return buffer.toString();
}

/// Préfixes d'écriture, du plus long au plus court : « retiens que » doit être
/// testé avant « retiens », sinon le fait garderait un « que » en tête.
const List<String> _rememberPrefixes = [
  'souviens-toi que',
  'souviens toi que',
  'rappelle-toi que',
  'rappelle toi que',
  'retiens que',
  'note que',
  'retiens',
];

const List<String> _recallFactsPatterns = [
  'que sais-tu de moi',
  'que sais tu de moi',
  "qu'est-ce que tu sais de moi",
  'quest-ce que tu sais de moi',
  'tu sais quoi sur moi',
];

const List<String> _recallEpisodesPatterns = [
  "qu'est-ce que j'ai vu",
  "quest-ce que jai vu",
  "ce que j'ai vu",
  'ce que jai vu',
  "qu'ai-je vu",
];

class MemoryIntentParser {
  MemoryIntentParser._();

  /// Reconnaît une intention mémoire, ou `null` si le transcript n'en porte pas.
  static MemoryIntent? parse(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;
    final normalized = normalizeForMatch(trimmed);

    // Le rappel d'épisodes est testé avant celui des faits : « ce que j'ai vu »
    // est plus spécifique et ne doit pas être avalé par un motif plus large.
    for (final pattern in _recallEpisodesPatterns) {
      if (normalized.contains(pattern)) return const RecallEpisodes();
    }
    for (final pattern in _recallFactsPatterns) {
      if (normalized.contains(pattern)) return const RecallFacts();
    }

    for (final prefix in _rememberPrefixes) {
      final index = normalized.indexOf(prefix);
      if (index < 0) continue;
      // Découpe la chaîne ORIGINALE : les indices sont valides parce que
      // normalizeForMatch préserve la longueur.
      final fact = trimmed.substring(index + prefix.length).trim();
      if (fact.isEmpty) return null;
      return RememberFact(fact);
    }

    return null;
  }
}
```

- [ ] **Step 5: Lancer, vérifier le vert**

Run: `flutter test test/features/memory/data/memory_intent_parser_test.dart`
Expected: PASS (tous les groupes)

- [ ] **Step 6: `dart analyze --fatal-infos` + commit**

```bash
dart analyze --fatal-infos
git add lib/features/memory/domain/memory_intent.dart lib/features/memory/data/memory_intent_parser.dart test/features/memory/data/memory_intent_parser_test.dart
git commit -m "feat(memory): MemoryIntentParser — détection déterministe, sans LLM"
```

---

### Task 3: `VaultMemoryAccess` + le branchement manquant

**Contexte.** `pluginSandboxProvider` (`lib/features/orchestration/di/providers.dart:122-136`) construit `PluginSandboxImpl` **sans** `memoryAccess`. Comme `_buildMemoryAccess` commence par `if (memoryAccess == null) return null;`, `context.memory` est `null` pour tout agent. C'est LA cause racine. Et le maillon terminal `MemoryVault → MemoryAccess` n'existe pas : seul `SandboxedMemoryAccess` implémente l'interface, et il ne fait que déléguer.

**Files:**
- Create: `lib/features/plugins/data/vault_memory_access.dart`
- Modify: `lib/features/orchestration/di/providers.dart` (`pluginSandboxProvider`)
- Test: `test/features/plugins/data/vault_memory_access_test.dart`

**Interfaces:**
- Consomme : `MemoryVault` (`saveEpisode`, `getPreference`, `setPreference({key, value, category, source})`).
- Produit : `class VaultMemoryAccess implements MemoryAccess` — consommé par `PluginSandboxImpl` via `pluginSandboxProvider`, et par la Tâche 4 (épisodes du plugin describe).

**Asymétrie d'interface.** `MemoryAccess.setPreference(String key, String value)` ne porte ni `category` ni `source`, contrairement à `MemoryVault.setPreference`. L'adaptateur comble avec `category: 'plugin_data'`, `source: 'plugin'`. Les **faits utilisateur ne passent pas par là** (voir Tâche 5) : cette asymétrie est donc sans conséquence.

**Résolution paresseuse.** `memoryVaultProvider` est un `FutureProvider` ; `pluginSandboxProvider` est synchrone. L'adaptateur reçoit un `Future<MemoryVault> Function()` et l'appelle au premier usage. Riverpod mémoïse `.future` : le vault n'est ouvert qu'une fois.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/plugins/data/vault_memory_access.dart';
// Utiliser le fake/mock MemoryVault déjà présent dans test/, sinon en écrire un.

void main() {
  test('délègue saveEpisode au vault', () async {
    final vault = FakeMemoryVault();
    final access = VaultMemoryAccess(vaultLoader: () async => vault);

    final result = await access.saveEpisode(KitaEpisode(
      id: 0, source: 'test', eventType: 'scene_description', summary: 'bureau',
      importanceScore: 0.3, isPinned: false, createdAt: DateTime(2026, 7, 9),
    ));

    expect(result.isSuccess, isTrue);
    expect(vault.savedEpisodes, hasLength(1));
  });

  test('setPreference comble category/source absents de MemoryAccess', () async {
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
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/plugins/data/vault_memory_access_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3: Implémenter `VaultMemoryAccess`**

```dart
import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../memory/domain/episode.dart';
import '../../memory/domain/memory_vault.dart';
import '../domain/memory_access.dart';

/// Maillon terminal entre les plugins et le coffre chiffré.
///
/// `SandboxedMemoryAccess` ne fait que déléguer ; sans cet adaptateur, la
/// chaîne n'aboutit nulle part et `context.memory` reste `null`.
class VaultMemoryAccess implements MemoryAccess {
  VaultMemoryAccess({required Future<MemoryVault> Function() vaultLoader})
      : _vaultLoader = vaultLoader;

  static final _log = KitaLogger('Plugin.MemoryAccess');

  final Future<MemoryVault> Function() _vaultLoader;
  MemoryVault? _vault;

  /// Résolution paresseuse : `pluginSandboxProvider` est synchrone alors que
  /// `memoryVaultProvider` est un `FutureProvider`. Charger ici évite de
  /// bloquer le démarrage de l'app.
  Future<MemoryVault?> _resolve() async {
    final cached = _vault;
    if (cached != null) return cached;
    try {
      final vault = await _vaultLoader();
      _vault = vault;
      return vault;
    } on Object catch (e, stack) {
      // KitaFailure n'est pas une Exception : `on Object` est obligatoire.
      _log.error('Memory vault unavailable', error: e, stackTrace: stack);
      return null;
    }
  }

  static const _unavailable = StorageFailure(
    userMessage: 'La mémoire est indisponible.',
    logMessage: 'Memory vault could not be loaded',
  );

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    return vault.saveEpisode(episode);
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    return vault.getPreference(key);
  }

  @override
  Future<Result<void>> setPreference(String key, String value) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    // MemoryAccess ne transporte ni category ni source : valeurs par défaut
    // pour les écritures de plugin. Les faits utilisateur passent directement
    // par MemoryVault (voir user_facts.dart).
    return vault.setPreference(
      key: key, value: value, category: 'plugin_data', source: 'plugin',
    );
  }
}
```

Vérifier le constructeur exact de `StorageFailure` (`lib/core/errors/kita_failure.dart`) et
adapter si `userMessage`/`logMessage` diffèrent.

- [ ] **Step 4: Brancher `pluginSandboxProvider`**

`lib/features/orchestration/di/providers.dart` :

```dart
final pluginSandboxProvider = Provider<PluginSandboxImpl>((ref) {
  final camera = ref.watch(cameraServiceProvider);
  final location = ref.watch(locationServiceProvider);
  final motion = ref.watch(motionServiceProvider);
  final aiRouter = ref.watch(aiRouterProvider);

  return PluginSandboxImpl(
    sensorAccess: RealSensorAccess(
      cameraService: camera,
      locationService: location,
      motionService: motion,
    ),
    aiAccess: RealAIAccess(aiRouter: aiRouter),
    // Sans ceci, `_buildMemoryAccess` renvoie null et toute la mémoire est
    // inerte, quelles que soient les permissions déclarées par les plugins.
    memoryAccess: VaultMemoryAccess(
      vaultLoader: () => ref.read(memoryVaultProvider.future),
    ),
  );
});
```

Imports à ajouter : `../../plugins/data/vault_memory_access.dart`,
`../../memory/di/providers.dart`.

**Attention lint riverpod.** `provider_dependencies` et
`scoped_providers_should_specify_dependencies` sont désactivés dans
`analysis_options.yaml` (section `plugins:`). Ne pas ajouter de `dependencies: []`.

- [ ] **Step 5: Lancer, vérifier le vert + non-régression**

Run: `flutter test test/features/plugins/ test/features/orchestration/`
Expected: PASS

- [ ] **Step 6: `dart analyze --fatal-infos` + commit**

```bash
dart analyze --fatal-infos
git add lib/features/plugins/data/vault_memory_access.dart lib/features/orchestration/di/providers.dart test/features/plugins/data/vault_memory_access_test.dart
git commit -m "feat(memory): VaultMemoryAccess — le maillon manquant, context.memory n'est plus null"
```

---

### Task 3bis: Consentement au stockage — accordé au démarrage, révocable

**Contexte — seconde cause racine, découverte pendant la Tâche 1.** `saveEpisode` et
`setPreference` sont tous deux verrouillés par `_withConsentLock(consentType:
'data_storage', scope: 'episodic' | 'semantic')` (`memory_vault_impl.dart:71-75,113-116`).
`grantConsent` a **zéro appelant en production**. Sans cette tâche, la Tâche 3 brancherait
`memoryAccess` et **chaque écriture échouerait quand même** — tests verts, mémoire morte
sur device. C'est le piège des deux cycles précédents ; on le désamorce ici.

**Décision de Charles (2026-07-09) :** consentement accordé au premier lancement, sans
question, et révocable par un interrupteur dans l'écran Mémoire. La donnée est locale et
chiffrée, jamais transmise.

**Piège en cascade.** `forget(everything)` appelle `consentDao.deleteAll()`
(`memory_vault_impl.dart:368`). Sans précaution, effacer ses données **désactive la mémoire
définitivement**. Le consentement doit donc être ré-accordé après un effacement total —
sauf si l'utilisateur a explicitement coupé l'interrupteur.

**Files:**
- Create: `lib/features/memory/data/memory_consent.dart`
- Modify: `lib/features/memory/di/providers.dart` (provider de bootstrap)
- Modify: `lib/app.dart` (déclencher le bootstrap au démarrage)
- Modify: `lib/features/settings/presentation/forget_screen.dart` (ré-accorder après `everything`)
- Test: `test/features/memory/data/memory_consent_test.dart`

**Interfaces:**
- Produit : `MemoryConsent.ensureGranted(MemoryVault)`, `MemoryConsent.isGranted(MemoryVault)`,
  `MemoryConsent.revokeAll(MemoryVault)` — consommés par le bootstrap, par `ForgetScreen`,
  et par l'interrupteur de l'écran Mémoire (Tâche 8).
- Produit : `memoryConsentBootstrapProvider` (`FutureProvider<void>`, `keepAlive`).
- Constantes : `consentTypeDataStorage = 'data_storage'`, scopes `'episodic'` et `'semantic'`.

**Idempotence obligatoire.** `ensureGranted` vérifie `hasConsent` avant d'insérer :
`grantConsent` insère une ligne **par appel** (`memory_vault_impl.dart:169`, commentaire à
la ligne 198). Sans garde, chaque lancement ajouterait deux lignes.

**Interrupteur coupé ≠ consentement absent.** Si l'utilisateur révoque, le bootstrap ne
doit pas ré-accorder au lancement suivant. Persister le choix dans une préférence
**hors du domaine sémantique verrouillé** — utiliser `ProfileDao` ou
`SecureKeyVault`, jamais `setPreference` (qui exige justement le consentement : deadlock).
Décision : `SecureKeyVault.write('memory_consent_opt_out', 'true')`.

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/memory/data/memory_consent_test.dart`, **vraie base Drift en mémoire** :

```dart
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
  final result = await vault.saveEpisode(/* épisode minimal */);
  expect(result.isSuccess, isFalse);
});

test('ensureGranted ne ré-accorde pas si l\'utilisateur a coupé l\'interrupteur',
    () async {
  // keyVault contient memory_consent_opt_out = 'true'
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
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/memory/data/memory_consent_test.dart`
Expected: FAIL — `memory_consent.dart` n'existe pas.

- [ ] **Step 3: Implémenter `memory_consent.dart`**

```dart
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/consent_entry.dart';
import '../domain/memory_vault.dart';
import '../domain/secure_key_vault.dart';

/// Type de consentement exigé par `MemoryVaultImpl._withConsentLock`.
const String consentTypeDataStorage = 'data_storage';

/// Scopes verrouillés : `saveEpisode` exige `episodic`, `setPreference` exige
/// `semantic`.
const List<String> memoryConsentScopes = ['episodic', 'semantic'];

/// Clé de l'opt-out utilisateur. Stockée hors du domaine sémantique : celui-ci
/// exige justement le consentement, ce qui créerait un interblocage.
const String memoryConsentOptOutKey = 'memory_consent_opt_out';

/// Le coffre refuse toute écriture sans consentement `data_storage`. Personne
/// ne le demandait : la mémoire était morte pour cette raison autant que par le
/// `memoryAccess` manquant.
class MemoryConsent {
  MemoryConsent._();

  static final _log = KitaLogger('Memory.Consent');

  static Future<bool> _optedOut(SecureKeyVault? keyVault) async {
    if (keyVault == null) return false;
    final value = (await keyVault.read(memoryConsentOptOutKey)).getOrNull();
    return value == 'true';
  }

  /// Accorde le consentement pour les deux scopes, sauf opt-out explicite.
  ///
  /// Idempotent : `grantConsent` insère une ligne par appel, donc on vérifie
  /// `hasConsent` d'abord. Appelé au démarrage **et** après `forget(everything)`,
  /// qui supprime toutes les lignes de consentement.
  static Future<void> ensureGranted(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
    DateTime Function()? now,
  }) async {
    if (await _optedOut(keyVault)) {
      _log.info('Memory consent opted out by user, not granting');
      return;
    }
    final timestamp = (now ?? DateTime.now)();
    for (final scope in memoryConsentScopes) {
      final already = (await vault.hasConsent(
        consentType: consentTypeDataStorage,
        scope: scope,
      )).getOrElse((_) => false);
      if (already) continue;

      final result = await vault.grantConsent(ConsentEntry(
        id: 0,
        consentType: consentTypeDataStorage,
        scope: scope,
        granted: true,
        grantedAt: timestamp,
      ));
      if (result.isFailure) {
        _log.warning('Could not grant memory consent for scope $scope');
      }
    }
    _log.info('Memory consent ensured');
  }

  static Future<bool> isGranted(MemoryVault vault) async {
    for (final scope in memoryConsentScopes) {
      final granted = (await vault.hasConsent(
        consentType: consentTypeDataStorage, scope: scope,
      )).getOrElse((_) => false);
      if (!granted) return false;
    }
    return true;
  }

  /// Révoque les deux scopes et mémorise l'opt-out, pour que le bootstrap du
  /// prochain démarrage ne ré-accorde pas dans le dos de l'utilisateur.
  static Future<void> revokeAll(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    final consents = (await vault.getConsents()).getOrNull() ?? const [];
    for (final entry in consents.where(
      (c) => c.granted && c.consentType == consentTypeDataStorage,
    )) {
      await vault.revokeConsent(entry.id);
    }
    await keyVault?.write(memoryConsentOptOutKey, 'true');
    _log.info('Memory consent revoked');
  }

  /// Ré-autorise après un opt-out.
  static Future<void> grantAgain(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    await keyVault?.delete(memoryConsentOptOutKey);
    await ensureGranted(vault, keyVault: keyVault);
  }
}
```

Vérifier les signatures réelles de `SecureKeyVault` (`read` / `write` / `delete`) dans
`lib/features/memory/domain/secure_key_vault.dart` et adapter (`getOrNull()` peut ne pas
s'appliquer si `read` renvoie `Future<String?>`).

- [ ] **Step 4: Provider de bootstrap**

`lib/features/memory/di/providers.dart` :

```dart
/// Accorde le consentement de stockage au démarrage (décision produit :
/// activé par défaut, révocable dans l'écran Mémoire). Sans lui, `saveEpisode`
/// et `setPreference` échouent silencieusement à l'exécution.
@Riverpod(keepAlive: true)
Future<void> memoryConsentBootstrap(Ref ref) async {
  final vault = await ref.watch(memoryVaultProvider.future);
  final keyVault = ref.watch(secureKeyVaultProvider);
  await MemoryConsent.ensureGranted(vault, keyVault: keyVault);
}
```

Puis `dart run build_runner build --delete-conflicting-outputs` (ne pas commiter `*.g.dart`).

- [ ] **Step 5: Déclencher au démarrage**

`lib/app.dart` : à côté de `autoCleanupProvider` et `cloudProvidersInitProvider`
(lignes 27-28), ajouter `ref.watch(memoryConsentBootstrapProvider);`.

- [ ] **Step 6: Ré-accorder après `forget(everything)`**

`lib/features/settings/presentation/forget_screen.dart` : après un `forget(everything)`
réussi, appeler `MemoryConsent.ensureGranted(vault, keyVault: keyVault)`.

Ajouter un test : après « tout effacer », une écriture de préférence réussit à nouveau.

- [ ] **Step 7: Suite complète + analyze**

Run: `flutter test && dart analyze --fatal-infos`

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix(memory): accorder le consentement de stockage — sans lui, toute écriture échoue"
```

---

### Task 4: Le plugin `describe` écrit son épisode

**Files:**
- Modify: `lib/features/plugins/built_in/describe/describe_plugin.dart`
- Test: `test/features/plugins/built_in/describe/describe_plugin_test.dart`

**Interfaces:**
- Consomme : `context.memory` (`MemoryAccess?`) — non-null depuis la Tâche 3, à condition que le manifeste déclare la permission.
- Consomme : `VaultMemoryAccess` via `SandboxedMemoryAccess`.

**Prérequis.** Le manifeste du plugin doit déclarer `'memory'` dans `permissions`. Le plugin est `TrustLevel.official`, donc `_buildMemoryAccess` lui rend l'accès **partagé** (pas sandboxé). Vérifier la valeur exacte de la chaîne de permission attendue par `SandboxedMemoryAccess` (`grep -n "allowedPermissions" lib/features/plugins/data/sandboxed_memory_access.dart`) — elle doit appartenir au set connu (`camera`, `microphone`, `location`, `memory`, …).

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/features/plugins/built_in/describe/describe_plugin_test.dart`, avec un
`FakeMemoryAccess` capturant les épisodes :

```dart
test('écrit un épisode après une description réussie', () async {
  final memory = FakeMemoryAccess();
  final plugin = KitaDescribePlugin();
  await plugin.onSpawn(contextWith(memory: memory, aiText: 'Un bureau. Une souris grise.'));

  await plugin.handleInput(AgentInput(
    command: 'decris', params: const {}, source: InputSource.voice,
    timestamp: DateTime(2026, 7, 9),
  ));

  expect(memory.savedEpisodes, hasLength(1));
  final episode = memory.savedEpisodes.single;
  expect(episode.source, equals('com.kita.describe'));
  expect(episode.eventType, equals('scene_description'));
  expect(episode.summary, equals('Un bureau.'));       // 1ʳᵉ phrase
  expect(episode.details, contains('souris grise'));   // texte complet
  expect(episode.isPinned, isFalse);
});

test('n\'écrit rien quand la mémoire est indisponible', () async {
  final plugin = KitaDescribePlugin();
  await plugin.onSpawn(contextWith(memory: null, aiText: 'Un bureau.'));
  // Ne doit pas lever : `context.memory?` est nullable par contrat.
  await plugin.handleInput(/* ... */);
});

test('n\'écrit rien quand la description a échoué', () async { /* ... */ });
```

Adapter `contextWith(...)` au helper déjà présent dans ce fichier de test.

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/plugins/built_in/describe/describe_plugin_test.dart`
Expected: FAIL — `savedEpisodes` est vide.

- [ ] **Step 3: Déclarer la permission**

Dans le manifeste du plugin (`describe_plugin.dart`, autour de la ligne 100) ajouter
`'memory'` à `permissions`.

- [ ] **Step 4: Écrire l'épisode**

À la fin du pipeline de description, une fois le texte complet obtenu et **seulement en
cas de succès** :

```dart
/// Première phrase du texte, ou le texte entier s'il n'y a pas de point.
/// Sert de `summary` d'épisode : court, lisible dans l'écran Mémoire.
static String firstSentence(String text) {
  final match = RegExp(r'^[^.!?]*[.!?]').firstMatch(text.trim());
  return (match?.group(0) ?? text.trim()).trim();
}

Future<void> _saveEpisode(String description) async {
  final memory = context?.memory;
  if (memory == null) {
    _log.debug('No memory access, episode not saved');
    return;
  }
  final result = await memory.saveEpisode(KitaEpisode(
    id: 0,
    source: 'com.kita.describe',
    eventType: 'scene_description',
    summary: firstSentence(description),
    details: description,
    tags: const [],
    importanceScore: 0.3,
    isPinned: false,
    createdAt: _clock.now(),
  ));
  // Zero PII : jamais le contenu, seulement la longueur.
  switch (result) {
    case Success():
      _log.info('Episode saved (len=${description.length})');
    case Failure(:final failure):
      _log.warning('Episode not saved: ${failure.logMessage}');
  }
}
```

Appeler `await _saveEpisode(fullText);` juste avant `Streaming description complete`.
Ne **jamais** faire échouer la description parce que l'écriture a échoué.

- [ ] **Step 5: Lancer, vérifier le vert**

Run: `flutter test test/features/plugins/`
Expected: PASS

- [ ] **Step 6: `dart analyze --fatal-infos` + commit**

```bash
dart analyze --fatal-infos
git add lib/features/plugins/built_in/describe/describe_plugin.dart test/features/plugins/built_in/describe/describe_plugin_test.dart
git commit -m "feat(memory): le plugin describe enregistre un épisode par scène décrite"
```

---

### Task 5: Faits utilisateur — écriture, lecture, injection dans le prompt

**Files:**
- Create: `lib/features/memory/data/user_facts.dart`
- Modify: `lib/features/ai/data/providers/local_provider.dart` (`buildLocalToolPrompt`, ctor `LocalProvider`)
- Modify: `lib/features/orchestration/di/providers.dart` (`aiRouterProvider`, ligne 87)
- Test: `test/features/memory/data/user_facts_test.dart`
- Test: `test/features/ai/data/providers/tool_prompt_test.dart` (existant — ajouter des groupes)

**Interfaces:**
- Produit : `class UserFacts` — `saveFact(vault, fact, {required source})`, `loadFactsForPrompt(vault)` → `List<String>`, `const String userFactCategory = 'user_fact'`, `factKey(String fact)`.
- Produit : `buildLocalToolPrompt(..., {List<String> knownFacts = const [], bool includeRuntimeNote = true})` — signature étendue, paramètres nommés optionnels : les appels existants continuent de compiler.
- Produit : `LocalProvider({..., Future<List<String>> Function()? knownFactsLoader})`.

**Décision d'architecture — pourquoi pas `AIRequest`.** Les faits ne transitent **pas**
par `AIRequest` : ce champ est acheminé vers les providers cloud, et la spec §3 exige que
les faits ne quittent jamais l'appareil. `LocalProvider` reçoit un **chargeur** à la
construction. Les faits sont ainsi local-only *par construction*, pas par convention.

- [ ] **Step 1: Tests de `user_facts.dart` (échec attendu)**

`test/features/memory/data/user_facts_test.dart`, **vraie base Drift en mémoire** :

```dart
test('factKey est idempotent : deux formulations identiques → une entrée', () async {
  await UserFacts.saveFact(vault, "Mon frère s'appelle Paul", source: 'explicit');
  await UserFacts.saveFact(vault, "mon frère s'appelle paul", source: 'explicit');

  final prefs = (await vault.getPreferences()).getOrNull()!;
  expect(prefs.where((p) => p.category == 'user_fact'), hasLength(1));
});

test('un fait est stocké avec ses accents', () async {
  await UserFacts.saveFact(vault, "j'aime le café très serré", source: 'explicit');
  final prefs = (await vault.getPreferences()).getOrNull()!;
  expect(prefs.single.value, equals("j'aime le café très serré"));
  expect(prefs.single.key, startsWith('fact:'));
});

test('loadFactsForPrompt place les faits explicites avant les déduits', () async {
  await UserFacts.saveFact(vault, 'fait déduit', source: 'inferred');
  await UserFacts.saveFact(vault, 'fait explicite', source: 'explicit');
  final facts = await UserFacts.loadFactsForPrompt(vault);
  expect(facts.first, equals('fait explicite'));
});

test('loadFactsForPrompt plafonne à 8 faits', () async {
  for (var i = 0; i < 12; i++) {
    await UserFacts.saveFact(vault, 'fait numéro $i', source: 'explicit');
  }
  expect((await UserFacts.loadFactsForPrompt(vault)).length, equals(8));
});

test('loadFactsForPrompt plafonne à 400 caractères au total', () async {
  for (var i = 0; i < 8; i++) {
    await UserFacts.saveFact(vault, 'x' * 90 + ' $i', source: 'explicit');
  }
  final facts = await UserFacts.loadFactsForPrompt(vault);
  expect(facts.join('\n').length, lessThanOrEqualTo(400));
});
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/memory/data/user_facts_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3: Implémenter `user_facts.dart`**

`user_facts.dart` vit dans `lib/features/memory/data/`, donc `memory_vault_impl.dart` et
`memory_intent_parser.dart` sont ses **voisins** (pas de `../data/`).

```dart
import '../../../core/errors/result.dart';
import '../domain/memory_vault.dart';
import '../domain/preference.dart';
import 'memory_intent_parser.dart' show normalizeForMatch;
import 'memory_vault_impl.dart' show userFactKeyPrefix;

/// Catégorie des préférences portant un fait sur l'utilisateur.
const String userFactCategory = 'user_fact';

/// Sources canoniques.
const String factSourceExplicit = 'explicit';
const String factSourceInferred = 'inferred';

/// Plafonds d'injection dans le prompt. Chaque fait coûte du prefill à
/// **chaque** message : 8 faits + la ligne de runtime ≈ 150 tokens.
const int maxFactsInPrompt = 8;
const int maxFactsCharsInPrompt = 400;

class UserFacts {
  UserFacts._();

  /// Clé stable et idempotente : redire le même fait n'ajoute pas d'entrée.
  static String factKey(String fact) {
    final slug = normalizeForMatch(fact)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final truncated = slug.length > 64 ? slug.substring(0, 64) : slug;
    return '$userFactKeyPrefix$truncated';
  }

  static Future<Result<void>> saveFact(
    MemoryVault vault,
    String fact, {
    required String source,
  }) {
    return vault.setPreference(
      key: factKey(fact),
      value: fact.trim(), // texte original, accents préservés
      category: userFactCategory,
      source: source,
    );
  }

  /// Faits à injecter dans le prompt : explicites d'abord, puis les plus
  /// récents, sous les deux plafonds.
  static Future<List<String>> loadFactsForPrompt(MemoryVault vault) async {
    final result = await vault.getPreferences();
    final all = result.getOrNull() ?? const <KitaPreference>[];
    final facts = all.where((p) => p.category == userFactCategory).toList()
      ..sort((a, b) {
        if (a.source != b.source) {
          return a.source == factSourceExplicit ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final kept = <String>[];
    var chars = 0;
    for (final pref in facts) {
      if (kept.length >= maxFactsInPrompt) break;
      final cost = pref.value.length + 1;
      if (chars + cost > maxFactsCharsInPrompt) break;
      kept.add(pref.value);
      chars += cost;
    }
    return kept;
  }
}
```

- [ ] **Step 4: Lancer, vérifier le vert**

Run: `flutter test test/features/memory/data/user_facts_test.dart`
Expected: PASS

- [ ] **Step 5: Tests du prompt étendu (échec attendu)**

Ajouter dans `test/features/ai/data/providers/tool_prompt_test.dart` :

```dart
group('buildLocalToolPrompt — faits connus', () {
  test('injecte un bloc [Ce que tu sais de l\'utilisateur]', () {
    final prompt = buildLocalToolPrompt('salut', tools, const [],
        knownFacts: const ["mon frère s'appelle Paul"]);
    expect(prompt, contains('[Ce que tu sais de l\'utilisateur]'));
    expect(prompt, contains("- mon frère s'appelle Paul"));
  });

  test('aucun bloc quand il n\'y a aucun fait', () {
    final prompt = buildLocalToolPrompt('salut', tools, const []);
    expect(prompt, isNot(contains('Ce que tu sais')));
  });

  test('les épisodes ne sont jamais injectés', () {
    // Garde-fou de conception : la signature ne doit exposer aucun paramètre
    // d'épisode. Ce test documente l'intention.
    final prompt = buildLocalToolPrompt('salut', tools, const [],
        knownFacts: const ['un fait']);
    expect(prompt, isNot(contains('scene_description')));
  });
});

group('buildLocalToolPrompt — conscience de sa configuration', () {
  test('annonce qu\'elle tourne en local et mentionne les Réglages', () {
    final prompt = buildLocalToolPrompt('pourquoi tu es lente ?', tools, const []);
    expect(prompt, contains('en local'));
    expect(prompt, contains('clé API'));
    expect(prompt, contains('Réglages'));
  });

  test('la ligne de runtime peut être retirée', () {
    final prompt = buildLocalToolPrompt('salut', tools, const [],
        includeRuntimeNote: false);
    expect(prompt, isNot(contains('clé API')));
  });
});
```

- [ ] **Step 6: Étendre `buildLocalToolPrompt`**

Signature et corps (dans `local_provider.dart`) :

```dart
/// Ligne de runtime : constante, pas un état calculé. `buildLocalToolPrompt`
/// n'est appelé que par [LocalProvider], donc elle est vraie par construction.
const String _runtimeNote =
    'Tu tournes sur Gemma, en local sur le téléphone, sans clé API : tu es plus '
    "lente qu'un modèle en ligne. Si l'utilisateur te trouve lente, dis-lui "
    "qu'il peut ajouter une clé API dans les Réglages.";

String buildLocalToolPrompt(
  String userMessage,
  List<ToolSpec> tools,
  List<ConversationMessage> history, {
  List<String> knownFacts = const [],
  bool includeRuntimeNote = true,
}) {
  final toolDescriptions = tools.map(_formatToolForPrompt).join('\n');
  final historyText =
      history.map(_formatHistoryLine).whereType<String>().join('\n');
  final factsBlock = knownFacts.isEmpty
      ? ''
      : "[Ce que tu sais de l'utilisateur]\n"
          '${knownFacts.map((f) => '- $f').join('\n')}\n\n';

  return '''[Instructions]
Tu es Kita, une assistante vocale française pour personnes déficientes
visuelles. Tu réponds brièvement, en français, comme à l'oral.
${includeRuntimeNote ? '$_runtimeNote\n' : ''}
Par défaut, tu réponds par du texte. N'appelle un outil que si l'utilisateur
demande explicitement cette action, maintenant.

Outils disponibles :
$toolDescriptions

Pour appeler un outil, réponds par cette seule ligne, sans rien d'autre :
TOOL describe
TOOL alert start

[Exemples]
Utilisateur : qu'est-ce qu'il y a devant moi ?
Kita : TOOL describe
Utilisateur : salut, ça va ?
Kita : Bonjour ! Ça va, et toi ?
Utilisateur : préviens-moi s'il y a un obstacle
Kita : TOOL alert start
Utilisateur : je ne t'ai pas demandé ça
Kita : Désolée. Que puis-je faire pour toi ?
Utilisateur : tu en penses quoi ?
Kita : Je n'ai pas encore d'avis. Dis-m'en plus.

$factsBlock${historyText.isNotEmpty ? '[Conversation]\n$historyText\n' : ''}Utilisateur : $userMessage
Kita :''';
}
```

Vérifier que les tests existants du groupe « cadrage du modèle » passent toujours
(notamment `endsWith('Utilisateur : ...\nKita :')`).

- [ ] **Step 7: Brancher le chargeur de faits dans `LocalProvider`**

Constructeur (`local_provider.dart:247`) : ajouter

```dart
    Future<List<String>> Function()? knownFactsLoader,
```
et `_knownFactsLoader = knownFactsLoader;` + `final Future<List<String>> Function()? _knownFactsLoader;`

Puis, dans `completeWithTools`, avant de construire le prompt :

```dart
// Les faits ne transitent PAS par AIRequest : ce champ part vers les
// providers cloud. Ils sont local-only par construction.
final facts = await _loadFactsSafely();
final toolPrompt = buildLocalToolPrompt(
  request.prompt, tools, history, knownFacts: facts,
);
```

et

```dart
/// Ne jamais faire échouer une réponse parce que la mémoire est indisponible.
Future<List<String>> _loadFactsSafely() async {
  final loader = _knownFactsLoader;
  if (loader == null) return const [];
  try {
    return await loader();
  } on Object catch (e) {
    _log.warning('Known facts unavailable: $e');
    return const [];
  }
}
```

- [ ] **Step 8: Câbler le provider**

`lib/features/orchestration/di/providers.dart:82-88` :

```dart
final aiRouterProvider = Provider<AIRouter>((ref) {
  final classifier = ref.watch(requestClassifierProvider);
  final gemmaBridge = ref.watch(gemmaBridgeProvider);
  return AIRouterImpl(
    classifier: classifier,
    providers: [
      LocalProvider(
        gemmaBridge: gemmaBridge,
        knownFactsLoader: () async {
          final vault = await ref.read(memoryVaultProvider.future);
          return UserFacts.loadFactsForPrompt(vault);
        },
      ),
    ],
  );
});
```

- [ ] **Step 9: Suite complète + analyze**

Run: `flutter test && dart analyze --fatal-infos`
Expected: PASS / No issues found

- [ ] **Step 10: Commit**

```bash
git add lib/features/memory/data/user_facts.dart lib/features/ai/data/providers/local_provider.dart lib/features/orchestration/di/providers.dart test/
git commit -m "feat(memory): faits injectés dans le prompt local + Kita consciente de tourner en local"
```

---

### Task 6: `InputRouter` — les intentions mémoire, avant le LLM

**Files:**
- Modify: `lib/features/orchestration/data/input_router.dart`
- Modify: `lib/features/orchestration/di/providers.dart` (passer le vault à `InputRouter`)
- Test: `test/features/orchestration/data/input_router_test.dart`

**Interfaces:**
- Consomme : `MemoryIntentParser.parse` (Tâche 2), `UserFacts.saveFact` / `loadFactsForPrompt` (Tâche 5), `MemoryVault.getEpisodes`.
- `InputRouter` gagne un paramètre optionnel `Future<MemoryVault> Function()? vaultLoader`.

**Point d'insertion exact.** Dans `_routeTranscript` (`input_router.dart:97`), **après** la
commande de sécurité « stop » (étape 3, jamais déplacée : elle doit marcher LLM éteint) et
**avant** le `ConversationEngine` (étape 4). Une intention mémoire reconnue court-circuite
entièrement le LLM : réponse en une fraction de seconde.

- [ ] **Step 1: Écrire les tests qui échouent**

`test()` + `ProviderContainer`, jamais `testWidgets` (piège CLAUDE.md).

```dart
test('« retiens que ... » écrit le fait et ne touche pas au LLM', () async {
  final engine = FakeConversationEngine();
  final vault = FakeMemoryVault();
  final router = InputRouter(/* ..., */ conversationEngine: engine,
      vaultLoader: () async => vault);

  await router.route(RawInput(
    source: InputSource.text, transcript: "retiens que mon frère s'appelle Paul",
    timestamp: DateTime(2026, 7, 9),
  ));

  expect(vault.lastPreference!.value, equals("mon frère s'appelle Paul"));
  expect(vault.lastPreference!.source, equals('explicit'));
  expect(engine.processInputCalls, isEmpty); // le LLM n'a jamais été appelé
});

test('« qu\'est-ce que tu sais de moi » énonce les faits, sans LLM', () async {
  // vault pré-rempli : 1 explicit, 1 inferred
  // attendu : la sortie distingue « Tu m'as dit » et « J'ai compris »
});

test('« qu\'est-ce que j\'ai vu » énonce les épisodes récents, sans LLM', () async {
  // vault pré-rempli avec 6 épisodes ; attendu : 5 énoncés, les plus récents
});

test('« stop » reste prioritaire sur toute intention mémoire', () async {
  // « stop, retiens que ... » -> annulation, pas d'écriture
});

test('une phrase ordinaire va bien au ConversationEngine', () async {
  // « bonjour » -> engine.processInputCalls == ['bonjour']
});

test('sans vault, une intention mémoire ne plante pas et retombe sur le LLM',
    () async {
  // vaultLoader == null -> engine appelé
});
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/orchestration/data/input_router_test.dart`
Expected: FAIL

- [ ] **Step 3: Implémenter**

Dans `_routeTranscript`, juste après le bloc `stop` :

```dart
    // 3bis. Intentions mémoire — déterministes, sans LLM (spec §1.2).
    //       Court-circuite le modèle : réponse immédiate, zéro prefill.
    final memoryIntent = MemoryIntentParser.parse(transcript);
    if (memoryIntent != null) {
      final handled = await _handleMemoryIntent(memoryIntent);
      if (handled) return;
      // Vault indisponible : on laisse le LLM répondre plutôt que de rester muet.
      _log.warning('Memory intent not handled, falling through to LLM');
    }
```

Puis les méthodes privées. Aucune ne journalise le contenu d'un fait.

```dart
/// Traite une intention mémoire. Renvoie `false` si le vault est indisponible,
/// pour que l'appelant retombe sur le chemin normal.
Future<bool> _handleMemoryIntent(MemoryIntent intent) async {
  final loader = _vaultLoader;
  if (loader == null) return false;

  final MemoryVault vault;
  try {
    vault = await loader();
  } on Object catch (e) {
    _log.warning('Memory vault unavailable: $e');
    return false;
  }

  switch (intent) {
    case RememberFact(:final fact):
      final result = await UserFacts.saveFact(vault, fact,
          source: factSourceExplicit);
      if (result.isSuccess) {
        _log.info('Fact saved (len=${fact.length})'); // zero PII
        await _speak("C'est noté.");
      } else {
        await _speak("Je n'ai pas réussi à retenir ça.");
      }
      return true;

    case RecallFacts():
      final prefs = (await vault.getPreferences()).getOrNull() ?? const [];
      final facts = prefs.where((p) => p.category == userFactCategory).toList();
      if (facts.isEmpty) {
        await _speak('Je ne sais encore rien de toi.');
        return true;
      }
      final said = facts.where((f) => f.source == factSourceExplicit);
      final inferred = facts.where((f) => f.source == factSourceInferred);
      final buffer = StringBuffer();
      for (final f in said) {
        buffer.writeln("Tu m'as dit que ${f.value}.");
      }
      for (final f in inferred) {
        buffer.writeln("J'ai compris que ${f.value}.");
      }
      _log.info('Facts recalled (count=${facts.length})'); // zero PII
      await _speak(buffer.toString().trim());
      return true;

    case RecallEpisodes():
      final episodes = (await vault.getEpisodes()).getOrNull() ?? const [];
      if (episodes.isEmpty) {
        await _speak("Je n'ai rien vu récemment.");
        return true;
      }
      final recent = (episodes.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(5);
      _log.info('Episodes recalled (count=${recent.length})'); // zero PII
      await _speak(recent.map((e) => e.summary).join(' '));
      return true;
  }
}

/// `enqueueSpeech` prend l'identifiant d'agent en **premier argument positionnel**
/// (`output_coordinator.dart:215`) : `(String agentId, String text, OutputPriority priority)`.
Future<void> _speak(String text) => _outputCoordinator.enqueueSpeech(
      AgentIds.orchestrator, text, OutputPriority.normal,
    );
```

Vérifier la constante d'identifiant réellement disponible dans
`lib/features/orchestration/domain/models/agent_ids.dart` — si aucune ne désigne
l'orchestrateur lui-même, en ajouter une (`static const orchestrator = 'com.kita.core';`)
plutôt que de passer une chaîne littérale.

Ajouter `Future<MemoryVault> Function()? vaultLoader` au constructeur d'`InputRouter`, et
le passer depuis `inputRouterProvider` avec `() => ref.read(memoryVaultProvider.future)`.

- [ ] **Step 4: Lancer, vérifier le vert**

Run: `flutter test test/features/orchestration/`
Expected: PASS

- [ ] **Step 5: Suite complète + analyze**

Run: `flutter test && dart analyze --fatal-infos`

- [ ] **Step 6: Commit**

```bash
git add lib/features/orchestration/ test/features/orchestration/
git commit -m "feat(memory): « retiens que… » et « qu'est-ce que tu sais de moi » court-circuitent le LLM"
```

---

### Task 7: `FactExtractor` — retenir sans qu'on le demande

**Files:**
- Modify: `lib/features/ai/data/providers/gemma_bridge.dart` (exposer `hasWaitingRealOps`)
- Create: `lib/features/orchestration/data/fact_extractor.dart`
- Modify: `lib/features/orchestration/di/providers.dart` (provider + `ref.onDispose`)
- Modify: `lib/features/orchestration/data/input_router.dart` (nourrir le tampon)
- Test: `test/features/orchestration/data/fact_extractor_test.dart`

**Interfaces:**
- Consomme : `GemmaBridge.complete(String prompt)`, `GemmaBridge.hasWaitingRealOps`, `UserFacts.saveFact(..., source: factSourceInferred)`.
- Produit : `FactExtractor.recordTurn(user, kita)`, `FactExtractor.flush()`, `FactExtractor.dispose()`.

**Pourquoi `GemmaBridge` et pas `AIRouter`.** Seul le pont expose `hasWaitingRealOps` et le
drapeau `isRealRequest: false`. C'est aussi la garantie que les faits ne partent jamais
vers un provider cloud (spec §3).

**Resource disposal (règle CLAUDE.md).** `FactExtractor` détient un `Timer` : il DOIT avoir
un `dispose()`, un drapeau `_disposed`, et le provider DOIT appeler `ref.onDispose`. Les
callbacks async dans `onDispose` utilisent `unawaited()`.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
test('n\'extrait rien avant le délai d\'inactivité', () async {
  final gemma = FakeGemmaBridge(response: 'mon frère s\'appelle Paul');
  final extractor = FactExtractor(gemma: gemma, vaultLoader: ..., clock: fakeClock);
  extractor.recordTurn(user: 'mon frère Paul vient', kita: 'Bonne visite !');
  expect(gemma.completeCalls, isEmpty);
});

test('extrait après 20 s d\'inactivité et écrit avec source=inferred', () async {
  // avancer l'horloge de 20 s -> 1 appel, 1 fait écrit, source == 'inferred'
});

test('abandonne si une requête utilisateur attend', () async {
  final gemma = FakeGemmaBridge(hasWaitingRealOps: true);
  // après 20 s : aucun appel à complete()
});

test('« RIEN » ne produit aucun fait', () async {
  // response: 'RIEN'  -> aucune écriture. Tester aussi 'rien' (casse).
});

test('rejette une ligne de plus de 80 caractères', () async {
  // response: 'x' * 81  -> aucune écriture
});

test('rejette une ligne qui recopie le dialogue', () async {
  // response: 'Utilisateur : bonjour'  -> aucune écriture
  // response: 'Kita : bonjour'         -> aucune écriture
});

test('plafonne à 2 faits par extraction', () async {
  // response: 4 lignes valides -> 2 écritures
});

test('ne bufferise pas les tours avec appel d\'outil', () async {
  // recordTurn n'est appelé que pour les tours conversationnels : vérifié
  // côté InputRouter (test d'intégration), documenté ici.
});

test('dispose() annule le timer et n\'extrait plus', () async { /* ... */ });

test('le tampon est plafonné à 10 tours', () async { /* ... */ });
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/orchestration/data/fact_extractor_test.dart`

- [ ] **Step 3: `hasWaitingRealOps` sur `GemmaBridge`**

```dart
  /// Vrai quand une requête utilisateur attend son tour. Les tâches de fond
  /// (extraction de faits) doivent s'abstenir : la session native de Gemma est
  /// unique et une inférence en cours ne s'interrompt pas.
  bool get hasWaitingRealOps => _waitingRealOps > 0;
```

Test unitaire dans `gemma_bridge_test.dart` : `hasWaitingRealOps` est `false` au repos.

- [ ] **Step 4: Implémenter `fact_extractor.dart`**

```dart
import 'dart:async';

import '../../../core/utils/logger.dart';
import '../../ai/data/providers/gemma_bridge.dart';
import '../../memory/data/user_facts.dart';
import '../../memory/domain/memory_vault.dart';

/// Délai d'inactivité avant extraction. Une inférence par **rafale** de
/// conversation, pas par tour : la batterie et la chaleur comptent.
const Duration factExtractionIdleDelay = Duration(seconds: 20);

const int _maxBufferedTurns = 10;
const int _maxFactsPerExtraction = 2;
const int _maxFactLength = 80;

const String _extractionPrompt = '''
Voici un échange entre un utilisateur et son assistante.
Liste les faits durables sur l'utilisateur : prénom, proches, habitudes,
préférences, santé. Un fait par ligne, très court.
Si aucun fait durable, réponds exactement : RIEN.

''';

/// Retient ce que l'utilisateur n'a pas demandé de retenir.
///
/// Tourne **après** la réponse, jamais pendant : le prompt de décision d'outil
/// n'est pas touché, donc aucun risque de rouvrir le bug `describe` (spec
/// 2026-07-09-progression-et-latence §5.6).
class FactExtractor {
  FactExtractor({
    required GemmaBridge gemma,
    required Future<MemoryVault> Function() vaultLoader,
    Duration idleDelay = factExtractionIdleDelay,
  })  : _gemma = gemma,
        _vaultLoader = vaultLoader,
        _idleDelay = idleDelay;

  static final _log = KitaLogger('Orchestration.FactExtractor');

  final GemmaBridge _gemma;
  final Future<MemoryVault> Function() _vaultLoader;
  final Duration _idleDelay;

  final List<String> _turns = [];
  Timer? _timer;
  bool _disposed = false;
  bool _extracting = false;

  /// Enregistre un tour de **conversation** (jamais un tour avec appel d'outil :
  /// une description de scène produit déjà son épisode).
  void recordTurn({required String user, required String kita}) {
    if (_disposed) return;
    _turns.add('Utilisateur : $user\nKita : $kita');
    while (_turns.length > _maxBufferedTurns) {
      _turns.removeAt(0);
    }
    _timer?.cancel();
    _timer = Timer(_idleDelay, () {
      unawaited(flush().catchError((Object e, StackTrace st) {
        _log.warning('Extraction failed', error: e, stackTrace: st);
      }));
    });
  }

  /// Extrait maintenant. Abandonne si une requête utilisateur attend.
  Future<void> flush() async {
    if (_disposed || _extracting || _turns.isEmpty) return;
    if (_gemma.hasWaitingRealOps) {
      _log.debug('Real request waiting, skipping extraction');
      return;
    }
    _extracting = true;
    final turns = List<String>.from(_turns);
    _turns.clear();

    try {
      // `complete` renvoie un GemmaCompletionResult (un simple `{text}`), pas un
      // Result<T> : il lève en cas d'échec, d'où le `on Object catch` plus bas.
      final result = await _gemma.complete(
        '$_extractionPrompt${turns.join('\n\n')}',
        isRealRequest: false,
      );
      if (_disposed) return;

      final facts = parseExtractedFacts(result.text);
      if (facts.isEmpty) {
        _log.info('No durable fact extracted');
        return;
      }
      final vault = await _vaultLoader();
      if (_disposed) return;
      for (final fact in facts) {
        await UserFacts.saveFact(vault, fact, source: factSourceInferred);
      }
      _log.info('Facts inferred (count=${facts.length})'); // zero PII
    } on Object catch (e, st) {
      _log.warning('Extraction failed', error: e, stackTrace: st);
    } finally {
      _extracting = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _turns.clear();
  }
}

/// Garde-fous : un modèle 2B invente, recopie le dialogue, et déborde.
List<String> parseExtractedFacts(String raw) {
  final lines = raw.trim().split('\n');
  if (lines.isEmpty) return const [];
  if (lines.first.trim().toUpperCase() == 'RIEN') return const [];

  final facts = <String>[];
  for (final line in lines) {
    final fact = line.trim().replaceFirst(RegExp(r'^[-*•]\s*'), '');
    if (fact.isEmpty) continue;
    if (fact.toUpperCase() == 'RIEN') continue;
    if (fact.length > _maxFactLength) continue;
    if (fact.contains('Utilisateur') || fact.contains('Kita')) continue;
    facts.add(fact);
    if (facts.length >= _maxFactsPerExtraction) break;
  }
  return facts;
}
```

**`GemmaBridge.complete` n'accepte pas encore `isRealRequest`.** Sa signature actuelle est
`Future<GemmaCompletionResult> complete(String prompt, {String? systemPrompt, int? maxTokens})`,
déclarée à `gemma_bridge.dart:53` (interface) et `:230` (implémentation). Ajouter
`bool isRealRequest = true` en paramètre nommé aux **deux**, et le transmettre à
`_acquireTurn(isRealRequest: isRealRequest)`. Tous les appels existants restent valides.

- [ ] **Step 5: Provider + disposal**

```dart
final factExtractorProvider = Provider<FactExtractor>((ref) {
  final extractor = FactExtractor(
    gemma: ref.watch(gemmaBridgeProvider),
    vaultLoader: () => ref.read(memoryVaultProvider.future),
  );
  ref.onDispose(extractor.dispose);
  return extractor;
});
```

- [ ] **Step 6: Nourrir le tampon depuis `InputRouter`**

Dans `_handleConversationResponse`, **seulement** quand `response.toolCalls.isEmpty` :

```dart
      _factExtractor?.recordTurn(user: transcript, kita: response.text);
```

(passer `transcript` en paramètre si nécessaire ; ajouter `FactExtractor? factExtractor`
au constructeur d'`InputRouter`).

- [ ] **Step 7: Suite complète + analyze**

Run: `flutter test && dart analyze --fatal-infos`

- [ ] **Step 8: Commit**

```bash
git add lib/features/ai/data/providers/gemma_bridge.dart lib/features/orchestration/ test/
git commit -m "feat(memory): extraction différée des faits, hors du prompt de décision d'outil"
```

---

### Task 8: Écran Mémoire + hygiène des Réglages

**Files:**
- Create: `lib/features/settings/presentation/memory_screen.dart`
- Delete: `lib/features/settings/presentation/memory_view_placeholder.dart`
- Modify: `lib/core/navigation/router.dart` (route `/settings/memory`)
- Modify: `lib/features/settings/presentation/settings_placeholder.dart` (accents + lien diagnostic)
- Test: `test/features/settings/presentation/memory_screen_test.dart`
- Test: `test/core/navigation/router_test.dart` (label Semantics mis à jour)

**Interfaces:**
- Consomme : `MemoryVault.whatDoYouKnow()`, `MemoryVault.getPreferences()`,
  `MemoryVault.forget(ForgetRequest.specific([key], confirmation: true))` (Tâche 1),
  `UserFacts.factKey`.

**Accessibility Tax (obligatoire).** `Semantics` sur chaque fait et chaque bouton, label
explicite (« supprimer le fait : mon frère s'appelle Paul »), cible tactile ≥ 48×48,
contraste ≥ 4,5:1. Confirmation de suppression via `SemanticsService.sendAnnouncement`
(`View.of(context)`, pas la méthode dépréciée `announce`).

**Hygiène des Réglages.** `settings_placeholder.dart` affiche « Parametres », « Memoire »,
« Ecran des parametres Kita » — **sans accents**, ce qui viole la règle CLAUDE.md — et
« Settings — Placeholder » à l'utilisateur. Il n'expose pas la route `/settings/diagnostic`
qui existe pourtant. Corriger les quatre. Mettre à jour l'assertion de
`test/core/navigation/router_test.dart` (« Ecran des parametres Kita »).

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
testWidgets('affiche les faits avec leur origine', (tester) async {
  // vault : 1 explicit, 1 inferred
  // attendu : « dit » sur l'un, « déduit » sur l'autre
});

testWidgets('chaque fait a un bouton supprimer accessible', (tester) async {
  expect(
    find.bySemanticsLabel(RegExp(r'^supprimer le fait')),
    findsNWidgets(2),
  );
});

testWidgets('supprimer un fait le retire de la liste', (tester) async {
  // tap -> vault.forget(specific) appelé -> la ligne disparaît
});

testWidgets('un vault vide affiche un message, pas une liste vide', (tester) async {
  expect(find.text('Kita ne sait encore rien de toi.'), findsOneWidget);
});

testWidgets('les cibles tactiles font au moins 48x48', (tester) async { /* ... */ });
```

Note : ici `testWidgets` est légitime (`pumpWidget` / `tap`). Ne pas y créer de
`StreamProvider` actif.

- [ ] **Step 2: Lancer, vérifier l'échec**

- [ ] **Step 3: Implémenter `memory_screen.dart`**

`ConsumerStatefulWidget`, `FutureProvider` local ou `AsyncValue` sur `getPreferences()`
filtré sur `category == 'user_fact'`. Une ligne = valeur + puce d'origine
(`dit` / `déduit`) + `IconButton` de suppression, dans un `Semantics(button: true,
label: 'supprimer le fait : ${fact.value}')`.

Suppression : `vault.forget(ForgetRequest.specific([fact.key], confirmation: true))`.
En cas de `Failure`, afficher un `SnackBar` et **annoncer** l'échec — ne jamais retirer la
ligne de l'affichage si la suppression a échoué (c'est exactement ce que la Tâche 1 rend
détectable).

Palette : reprendre celle du fil de conversation (fond `#2D3A5F`, texte `#F8FAFC`,
secondaire `#A8B2C4` — 5,22:1, validé). **Ne pas** utiliser `#94A3B8` (4,35:1, échoue AA).

- [ ] **Step 4: Router + suppression du stub**

```dart
      GoRoute(
        path: 'memory',
        builder: (context, state) => const MemoryScreen(),
      ),
```
puis `git rm lib/features/settings/presentation/memory_view_placeholder.dart`.

- [ ] **Step 5: Corriger `settings_placeholder.dart`**

`'Parametres'` → `'Paramètres'`, `'Memoire'` → `'Mémoire'`,
`'Ecran des parametres Kita'` → `'Écran des paramètres Kita'`,
supprimer `const Text('Settings — Placeholder')`, ajouter un bouton vers
`/settings/diagnostic` (« Diagnostic »).

Mettre à jour `test/core/navigation/router_test.dart` en conséquence.

- [ ] **Step 6: Suite complète + analyze**

Run: `flutter test && dart analyze --fatal-infos`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(settings): écran Mémoire réel + accents et lien diagnostic dans les Réglages"
```

---

### Task 9: Validation sur device — mesurer, ne pas supposer

**Contexte.** Deux cycles de suite, une métrique verte a masqué un comportement faux : les
logs disaient « description complete » pendant que Kita lisait du JSON à voix haute ; les
chronos étaient excellents pendant qu'elle reprenait une photo à chaque message. **On
vérifie le contenu, pas le compteur.**

**Files:**
- Modify: `docs/superpowers/specs/2026-07-09-memoire-vivante-design.md` (§2.7)
- Modify: `.superpowers/sdd/progress.md`

**Environnement.**
```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_SERIAL=192.168.201.65:38121   # revérifier via `adb mdns services`
```
**Ne jamais monter le volume du téléphone** (contrainte de Charles). Ne pas prendre de
capture d'écran sans confirmer que le téléphone est déverrouillé.

- [ ] **Step 1: Mesurer le prefill AVANT**

Sur le build actuel (sans faits), noter la durée « Tool-use request completed via gemma in
XXXXms » sur un « salut » à froid. Référence connue : **4,0 s**.

- [ ] **Step 2: Build + install**

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
adb shell am start -n com.kita.kita/.MainActivity
```

- [ ] **Step 3: Vérifier le comportement, pas les compteurs**

| Scénario | Attendu |
|---|---|
| « retiens que mon frère s'appelle Paul » | « C'est noté. » **immédiat** (aucun `Tool-use request` dans les logs) |
| « qu'est-ce que tu sais de moi ? » | Kita énonce le fait, avec ses accents |
| « décris » | description **et** `Episode saved (len=…)` |
| « qu'est-ce que j'ai vu ? » | Kita énonce le résumé de la scène |
| « pourquoi tu es lente ? » | Kita mentionne d'elle-même la clé API et les Réglages |
| « salut » puis 20 s de silence | `Facts inferred (count=…)` **ou** `No durable fact extracted` |
| Parler pendant l'extraction | `Real request waiting, skipping extraction` |
| Écran Mémoire | les faits apparaissent, « dit » / « déduit » corrects |
| Supprimer un fait | il disparaît **et** ne revient pas après redémarrage |
| Redémarrer l'app | les faits survivent |

- [ ] **Step 4: Mesurer le prefill APRÈS**

Avec 8 faits en base, relever à nouveau « Tool-use request completed via gemma in XXXXms »
sur un « salut ». Comparer à l'étape 1.

- [ ] **Step 5: Vérifier zéro PII dans les logs**

```bash
adb logcat -d | grep "kita:" | grep -iE "paul|frère|café|bus"
```
Expected: **aucune ligne**. Si un fait apparaît en clair, c'est un bug bloquant.

- [ ] **Step 6: Remplacer §2.7 du spec par les mesures réelles**

Titre « Mesuré après implémentation (2026-07-XX) », conserver la colonne « Avant ».
**Consigner les chiffres réels, même s'ils déçoivent.**

- [ ] **Step 7: Ledger + commit**

```bash
git add -A
git commit -m "docs: validation device de la mémoire vivante — mesures réelles"
```
