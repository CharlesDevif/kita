# Mémoire vivante — Design

**Date :** 2026-07-09
**Statut :** approuvé par Charles, prêt pour le plan d'implémentation

## 0. Constat : la mémoire longue est du code mort

Audit du 2026-07-09, vérifié ligne par ligne.

| Preuve | Fichier |
|---|---|
| Le provider de production construit le sandbox **sans** `memoryAccess` | `lib/features/orchestration/di/providers.dart:122-136` |
| `_buildMemoryAccess` / `_buildAgentMemoryAccess` renvoient `null` si `memoryAccess == null` | `lib/features/plugins/data/plugin_sandbox_impl.dart:163,183` |
| `saveEpisode` n'a que des définitions et des délégations — aucun appelant issu du flux applicatif | `grep -rn saveEpisode lib/` |
| `getEpisodes`, `getPersons`, `whatDoYouKnow` : **zéro appelant** dans tout `lib/` | `grep -rn ... lib/` |

Conséquence : `context.memory` est `null` pour tout agent et tout plugin, en permanence.
Rien n'écrit, rien ne relit.

Ce qui fonctionne réellement aujourd'hui : la base SQLCipher est ouverte et déchiffrée à
chaque démarrage (`lib/app.dart:27-28` → `kitaDatabaseProvider`), le profil d'onboarding
et les clés API sont persistés, `AutoCleanupService` purge à 30 jours
(`auto_cleanup_service.dart:10`), et `ForgetScreen` efface — des tables épisodiques
structurellement vides.

La seule mémoire réelle est `ConversationEngineImpl._history` (20 messages,
`conversation_engine.dart:55-58`), en RAM, détruite avec le process.

### 0.0 Seconde cause racine : le consentement n'est jamais demandé

Découverte pendant l'implémentation de la Tâche 1, **pas par l'audit**.

`saveEpisode` et `setPreference` sont verrouillés par `_withConsentLock(consentType:
'data_storage', scope: 'episodic' | 'semantic')` (`memory_vault_impl.dart:71-75,113-116`).
Or `grantConsent` a **zéro appelant en production**.

La mémoire est donc morte pour **deux raisons indépendantes**. Brancher `memoryAccess`
(§2.4) n'aurait rien changé : les tests seraient restés verts — ils accordent le
consentement — et chaque écriture aurait échoué sur device avec « Consentement requis pour
stocker ces données ». C'est exactement le piège des deux cycles précédents (§8).

**Décision de Charles :** consentement accordé au premier lancement, sans question,
révocable par un interrupteur dans l'écran Mémoire. Donnée locale, chiffrée, jamais
transmise.

**Piège en cascade.** `forget(everything)` appelle `consentDao.deleteAll()`
(`memory_vault_impl.dart:368`). Sans précaution, effacer ses données désactiverait la
mémoire **définitivement** : le droit à l'oubli deviendrait une lobotomie. Le consentement
est donc ré-accordé après un effacement total, sauf opt-out explicite. L'opt-out est stocké
dans `SecureKeyVault`, jamais via `setPreference` — qui exige justement le consentement
(interblocage).

### 0.1 Défaut découvert pendant l'audit

`ForgetScope.specific` ne supprime **que des épisodes** (`memory_vault_impl.dart:319-325`) :

```dart
for (final idStr in request.specificIds) {
  final id = int.tryParse(idStr);
  if (id != null) { await episodeDao.deleteById(id); }
}
```

Une clé de préférence (non numérique) est **ignorée en silence** : pas d'erreur, pas de
log. Un « supprime ce fait » réussirait en apparence sans rien effacer. À corriger, sinon
l'écran Mémoire ment à l'utilisateur.

## 1. Décisions

Prises avec Charles, 2026-07-09.

1. **Kita retient des faits explicites ET des épisodes.** (Pattern OpenClaw : `MEMORY.md`
   relu à chaque session + notes journalières consultables à la demande.)
2. **Aucun outil `remember`/`recall` n'est ajouté au prompt.** Un Gemma 3n E2B choisit
   d'autant plus mal qu'il a plus d'options — le bug `describe` du matin même l'a montré
   (voir `2026-07-09-progression-et-latence-design.md` §5.6). Le déclenchement est
   déterministe, en Dart, avant tout appel LLM.
3. **Kita retient aussi ce qu'on ne lui demande pas de retenir**, via une passe
   d'extraction différée qui ne touche pas au prompt de décision d'outil.
4. **L'extraction est silencieuse.** Les faits déduits sont marqués `inferred`, visibles
   et supprimables dans l'écran Mémoire, et lisibles à la voix.

## 2. Architecture

Six pièces, dont cinq déjà écrites.

```
        message utilisateur
                │
                ▼
    ┌───────────────────────┐   intention reconnue
    │  MemoryIntentParser   │──────────────┐        (aucun appel LLM)
    │  (déterministe, Dart) │              │
    └───────────┬───────────┘              ▼
                │ aucune            MemoryVault
                ▼                   (existe déjà)
       ConversationEngine ◄── faits injectés dans le prompt
                │
                ├──► réponse à l'utilisateur  ◄── perçu ici
                │
                └──► FactExtractor (buffer)
                          │  après 20 s d'inactivité
                          ▼
                     2ᵉ inférence Gemma ──► MemoryVault (source: inferred)
```

### 2.1 `MemoryIntentParser` — nouveau

`lib/features/memory/domain/memory_intent.dart`
`lib/features/memory/data/memory_intent_parser.dart`

```dart
sealed class MemoryIntent {}
final class RememberFact extends MemoryIntent { final String fact; }
final class RecallFacts extends MemoryIntent {}      // « qu'est-ce que tu sais de moi ? »
final class RecallEpisodes extends MemoryIntent {}   // « qu'est-ce que j'ai vu ? »
```

`MemoryIntentParser.parse(String transcript) → MemoryIntent?`

Préfixes reconnus pour `RememberFact` : `retiens que`, `retiens`, `souviens-toi que`,
`souviens toi que`, `rappelle-toi que`, `rappelle toi que`, `note que`.

**Contrainte de normalisation.** La reconnaissance se fait sur une forme normalisée
(minuscules, accents retirés) mais la valeur stockée doit garder ses accents. La
normalisation doit donc **préserver les indices de caractères** : chaque caractère se
mappe sur exactement un caractère. Un test vérifie `normalize(s).length == s.length` sur
un échantillon accentué, caractère par caractère (piège connu, cf. CLAUDE.md).

Le parser vit dans `features/memory` (propriété E4) et est consommé par
`features/orchestration`, comme `describe_plugin` l'est déjà.

### 2.2 Écriture des faits

Domaine sémantique existant, aucune table nouvelle :

```dart
vault.setPreference(
  key: 'fact:${_slug(normalized)}',   // idempotent : redire le même fait n'ajoute rien
  value: fact,                        // texte original, accents préservés
  category: 'user_fact',
  source: 'explicit',                 // ou 'inferred'
);
```

`_slug` : normalisé, non alphanumériques → `_`, tronqué à 64 caractères.

### 2.3 Écriture des épisodes

`KitaDescribePlugin`, à la fin d'une description réussie :

```dart
await context.memory?.saveEpisode(KitaEpisode(
  id: 0, source: 'com.kita.describe', eventType: 'scene_description',
  summary: firstSentence, details: fullText, tags: const [],
  importanceScore: 0.3, isPinned: false, createdAt: clock.now(),
));
```

Le manifeste du plugin déclare la permission `memory`. Il est `TrustLevel.official`, donc
`_buildMemoryAccess` lui rend l'accès partagé. `AutoCleanupService` purge à 30 jours sans
modification.

### 2.4 Le branchement manquant

**Aucun adaptateur `MemoryVault → MemoryAccess` n'existe.** `MemoryAccess`
(`lib/features/plugins/domain/memory_access.dart`) est une interface étroite —
`saveEpisode`, `getPreference`, `setPreference(key, value)` — et son unique
implémentation, `SandboxedMemoryAccess`, ne fait que déléguer à une autre `MemoryAccess`.
Il faut donc écrire le maillon terminal :

`lib/features/plugins/data/vault_memory_access.dart` — `plugins` dépend déjà de `memory`
(`memory_access.dart` importe `memory/domain/episode.dart`), donc le sens de dépendance
est respecté.

```dart
class VaultMemoryAccess implements MemoryAccess {
  VaultMemoryAccess({required Future<MemoryVault> Function() vaultLoader});
}
```

`memoryVaultProvider` est un `FutureProvider` alors que `pluginSandboxProvider` est
synchrone : le loader résout le vault paresseusement au premier appel (Riverpod mémoïse
`.future`), sans bloquer le démarrage.

`MemoryAccess.setPreference(key, value)` ne porte ni `category` ni `source`, contrairement
à `MemoryVault.setPreference`. L'adaptateur comble avec `category: 'plugin_data'`,
`source: 'plugin'`. Cette asymétrie est sans conséquence ici : **les faits utilisateur ne
passent pas par `MemoryAccess`.**

Deux chemins d'écriture, volontairement distincts :

| Donnée | Chemin |
|---|---|
| Faits utilisateur | orchestration → `MemoryVault` directement (via `memoryVaultProvider`) |
| Épisodes | `KitaDescribePlugin` → `context.memory` → `SandboxedMemoryAccess` → `VaultMemoryAccess` → `MemoryVault` |

Enfin, `pluginSandboxProvider` (`lib/features/orchestration/di/providers.dart:122-136`)
reçoit ce `VaultMemoryAccess`. Sans cette ligne, tout le reste est inerte.

### 2.5 `FactExtractor` — nouveau

`lib/features/orchestration/data/fact_extractor.dart`

Tampon des derniers tours de **conversation** (pas les tours avec appel d'outil : une
description de scène produit déjà son épisode). Plafond : 10 tours.

Déclenchement : `Timer` d'inactivité de **20 s**, réarmé à chaque message. Flush
également à la mise en pause de l'application. Jamais pendant qu'une requête utilisateur
attend : `GemmaBridge` expose `bool get hasWaitingRealOps` (adossé au compteur
`_waitingRealOps` déjà présent), et l'extraction est abandonnée si ce compteur est non nul.

`FactExtractor` dépend **directement de `GemmaBridge`**, pas de `AIRouter` : seul le pont
expose `hasWaitingRealOps` et le drapeau `isRealRequest: false` qui empêche l'extraction
de se compter comme requête utilisateur. C'est cohérent avec la décision de ne jamais
envoyer les faits à un provider cloud (§3).

Si `GemmaBridge` est absent (modèle non installé), `FactExtractor` ne fait rien —
l'extraction est un bonus, jamais un prérequis.

Prompt d'extraction (séparé, sans outils) :

```
Voici un échange entre un utilisateur et son assistante.
Liste les faits durables sur l'utilisateur : prénom, proches, habitudes,
préférences, santé. Un fait par ligne, très court.
Si aucun fait durable, réponds exactement : RIEN.

<tours>
```

Garde-fous sur la sortie (un modèle 2B se trompe) :
- première ligne `RIEN` (insensible à la casse) → aucun fait ;
- au plus **2 faits** par extraction ;
- une ligne de plus de 80 caractères est rejetée ;
- une ligne contenant `Utilisateur` ou `Kita` est rejetée (le modèle recopie le dialogue) ;
- une ligne vide est ignorée.

Les faits retenus sont écrits avec `source: 'inferred'`.

### 2.6 Injection dans le prompt

`buildLocalToolPrompt` (déjà refait ce matin) gagne deux paramètres nommés optionnels :

```dart
String buildLocalToolPrompt(
  String userMessage,
  List<ToolSpec> tools,
  List<ConversationMessage> history, {
  List<String> knownFacts = const [],
  bool includeRuntimeNote = true,
})
```

**Bloc de faits**, seulement s'il y en a :

```
[Ce que tu sais de l'utilisateur]
- mon frère s'appelle Paul
- je prends le bus à 8h
```

Plafonds : **8 faits**, **400 caractères** au total. Les faits `explicit` passent avant
les `inferred` ; à égalité, les plus récents d'abord.

**Ligne de runtime**, juste après l'identité :

```
Tu tournes sur Gemma, en local sur le téléphone, sans clé API : tu es plus lente
qu'un modèle en ligne. Si l'utilisateur trouve que tu es lente, dis-lui qu'il peut
ajouter une clé API dans les Réglages.
```

Cette ligne est une **constante**, pas un état calculé : `buildLocalToolPrompt` n'est
appelé que par `LocalAIProvider`, donc elle est vraie par construction. Zéro plomberie,
zéro provider nouveau. C'est le point (a) de la recommandation de recherche (ligne fixe
ultra-courte) ; le point (b), un outil `get_status` à la demande, est écarté par la
décision 2.

Les épisodes ne sont **jamais** injectés.

### 2.7 Coût de prefill

8 faits courts + la ligne de runtime ≈ **150 tokens** ajoutés à chaque message.
Home Assistant Assist paie ~1300 tokens pour 30 entités exposées en permanence
(developers.home-assistant.io/docs/core/llm). **À mesurer sur device** : la décision
tool-use est aujourd'hui à 4,0 s ; on consignera le chiffre réel, même s'il déçoit.

### 2.8 Lecture à la voix

`RecallFacts` → `vault.getPreferences()` filtré sur `category == 'user_fact'`, énoncé :
« Tu m'as dit que… J'ai compris que… » (`explicit` / `inferred` distingués à l'oral).
Marie est aveugle : un écran avec des boutons « supprimer » ne lui sert à rien si elle ne
peut pas d'abord **entendre** ce que Kita a retenu.

`RecallEpisodes` → `vault.getEpisodes()`, les 5 plus récents, énoncés avec un repère
temporel relatif.

### 2.9 Écran Mémoire

`lib/features/settings/presentation/memory_screen.dart` remplace
`memory_view_placeholder.dart` (20 lignes de stub).

Source : `vault.whatDoYouKnow()`, déjà implémenté. Chaque fait affiche son origine
(`dit` / `déduit`) et un bouton « supprimer ».

**Prérequis :** corriger `ForgetScope.specific` (§0.1) pour qu'il supprime aussi les
préférences par clé, via `PreferenceDao.deleteByKey` (existe déjà). Une clé inconnue doit
produire un `Result.failure` ou un log d'avertissement — **jamais** un succès silencieux.

## 3. Confidentialité

- Les épisodes contiennent la description de ce que la caméra voit chez l'utilisateur.
  Donnée intime. Chiffrée (SQLCipher), locale, jamais transmise.
- Rétention **30 jours** (`defaultRetentionPeriod`), déjà appliquée par `AutoCleanupService`.
- Zéro PII dans les logs : on journalise `(source, len=N)`, jamais le contenu d'un fait
  ni d'un épisode. Règle CLAUDE.md, vérifiée à la revue.
- Le prompt d'extraction et les faits ne quittent jamais l'appareil : `LocalAIProvider`
  uniquement. Si un provider cloud est actif, les faits ne sont pas injectés dans ce
  cycle (hors périmètre, voir §6).

## 4. Accessibilité

- L'écran Mémoire : `Semantics` sur chaque fait et chaque bouton « supprimer », label
  explicite (« supprimer le fait : mon frère s'appelle Paul »), cible tactile ≥ 48×48.
- Contraste texte ≥ 4,5:1 (le bug `#94A3B8` à 4,35:1 corrigé ce matin est un précédent).
- La suppression est confirmée à la voix et par `SemanticsService.sendAnnouncement`.
- `RecallFacts` rend l'écran facultatif : tout est accessible sans voir.

## 5. Tests

Fonctionnels et réels, pas seulement des mocks (règle CLAUDE.md).

| Sujet | Nature |
|---|---|
| `MemoryIntentParser` | unitaire, table de cas ; **normalisation préservant les indices** |
| `_slug` idempotent | unitaire : deux formulations identiques → une seule entrée |
| Écriture/lecture d'un fait | **intégration Drift réelle**, pas de mock DB |
| `ForgetScope.specific` sur une clé de préférence | intégration : la ligne disparaît vraiment |
| `ForgetScope.specific` sur une clé inconnue | échec ou avertissement, **jamais** succès silencieux |
| Garde-fous de `FactExtractor` | unitaire : `RIEN`, >80 car., `Utilisateur:`, >2 faits |
| `FactExtractor` abandonne si une requête attend | unitaire, `hasWaitingRealOps == true` |
| `buildLocalToolPrompt` avec faits | plafonds 8 / 400 car. ; `explicit` avant `inferred` |
| `buildLocalToolPrompt` sans fait | aucun bloc `[Ce que tu sais]` |
| Épisode écrit après une description | intégration : plugin + vault réel |
| Écran Mémoire | widget + `Semantics` matcher |

`test()` + `ProviderContainer` pour tout ce qui touche aux streams — jamais `testWidgets`
(piège documenté dans CLAUDE.md).

## 6. Hors périmètre de ce cycle

- Refonte complète des Réglages et vue des modules installés → cycle suivant.
  (Exception : corriger les accents manquants « Parametres », « Memoire », et retirer
  « Settings — Placeholder » affiché à l'utilisateur.)
- Marketplace de plugins.
- Injection des faits vers un provider **cloud** (question de consentement distincte).
- Outils `remember`/`recall` exposés au LLM quand une clé API cloud est configurée.
- Persistance du fil de conversation (`ConversationFeed`) entre deux lancements.

## 7. Risques assumés

| Risque | Mitigation |
|---|---|
| Le 2B extrait des faits faux | Marqués `inferred`, plafonnés à 2/extraction, filtrés, visibles, supprimables |
| L'extraction fait attendre l'utilisateur | Déclenchée à 20 s d'inactivité ; abandonnée si `hasWaitingRealOps` |
| Batterie / chaleur | Une inférence par **rafale** de conversation, pas par tour |
| Le prefill des faits ralentit chaque message | Plafonné à 8 faits / 400 car. ; **mesuré sur device** avant/après |
| L'utilisateur ne dit jamais « retiens que » | C'est précisément ce que l'extraction différée résout |

## 8. Leçon reprise des deux cycles précédents

Les logs disaient « description complete (78 chars) » pendant que l'app lisait du JSON à
voix haute. Les chronos étaient excellents pendant que Gemma reprenait une photo à chaque
message. **Une métrique verte ne dit rien du comportement.** Ce cycle se valide sur le
téléphone, en vérifiant le *contenu* de ce que Kita retient — pas le nombre de lignes
insérées.
