# Spec — Retour de progression + réduction de latence

- **Date :** 2026-07-09
- **Auteur :** Charles + Claude
- **Statut :** proposé (en attente de relecture)
- **Branche :** `develop`
- **Suite de :** `2026-07-06-reconnaissance-on-device-design.md` (reconnaissance validée sur S21 Ultra)

## 1. Problème

La reconnaissance locale fonctionne, mais **l'attente est insupportable et illisible**.

Constat terrain (Charles, S21 Ultra) : *« lorsqu'on attend, on ne sait pas ce qui se
passe, on ne sait pas si c'est en cours ou si c'est bugué »*.

Deux causes distinctes :

1. **Aucun signal pendant l'attente.** `OrbState.processing` n'est déclenché que dans
   `OutputCoordinator.enqueueSpeech`, c'est-à-dire quand Kita s'apprête à *parler*.
   Pendant les ~55 s d'inférence, l'orbe reste `passive` : l'app a l'air éteinte. Ni
   voix, ni vibration, ni animation, ni texte. Pour Marie (aveugle), c'est un silence
   total et anxiogène.
2. **La latence elle-même** : 70 s pour un « décris ».

## 2. Mesures réelles (logcat, S21 Ultra, 2026-07-09)

Un « décris » complet, horodaté :

| Étape | Instant | Durée |
|---|---|---|
| Entrée reçue | 12:17:37.810 | — |
| Décision tool-use terminée | 12:17:59.800 | **22,0 s** |
| Photo capturée | 12:18:01.340 | 1,5 s |
| 1ʳᵉ phrase prononcée (153 car.) | 12:18:33.217 | **31,9 s** |
| 2ᵉ phrase (103 car.) | 12:18:45.807 | 12,6 s |
| Fin (268 car. au total) | 12:18:48.086 | — |
| **Total** | | **70,3 s** |
| **Premier mot entendu** | | **55,4 s** |

**Débit de décodage mesuré : ~0,55 s/token.** C'est le décodage qui domine, pas la
« réflexion ».

Conséquences arithmétiques :
- L'appel d'outil `{"tool_call": {"name": "describe", "arguments": {"detail_level":
  "detailed"}}}` fait 78 caractères ≈ **30 tokens ≈ 16,5 s de pure écriture de JSON**.
- La 1ʳᵉ phrase de description fait 153 caractères ≈ **45 tokens ≈ 25 s**. Or elle
  n'est prononcée qu'une fois **terminée** (le `SentenceBuffer` attend la ponctuation
  finale). L'utilisateur attend donc 25 s en silence alors que les tokens coulent.

### Hypothèse invalidée
Réduire la résolution de l'image **n'apportera rien** : la caméra capture déjà en
`ResolutionPreset.medium` (~480p, ~89 Ko) et Gemma 3n ré-encode l'image à sa propre
résolution interne. Le coût vision est dominé par le décodage des tokens de sortie,
pas par l'encodage de l'image (prefill + encodage image ≈ 7 s sur les 31,9 s).

## 3. Décisions produit (validées par Charles)

- **Type de retour :** voix courte + texte + orbe. Deux repères vocaux maximum par
  requête, jamais un commentaire à chaque étape.
- **Pas de voie rapide court-circuitant le LLM.** Kita reste un agent conversationnel :
  même « décris » passe par le LLM. La latence sera gagnée ailleurs.
- **Palier visé : ~35-40 s au total, premier mot vers ~20 s.** Descendre plus bas exige
  un modèle plus petit ou l'accélérateur NPU — cycle ultérieur.

## 4. Design — Partie A : `ProgressReporter`

### 4.1 Principe

La connaissance de « où on en est » appartient à **l'orchestrateur**, pas éparpillée
dans chaque agent. Un composant dédié reçoit des **phases** et décide seul de la
politique de restitution (orbe / haptique / voix / texte).

Bénéfice : un futur module (recette-frigo, alarmes) émet sa phase et hérite du bon
comportement, sans réinventer une UX incohérente.

### 4.2 Phases

```dart
enum ProgressPhase {
  thinking,    // le LLM réfléchit
  working,     // un outil s'exécute (photo, analyse…)
  responding,  // Kita a commencé à parler
  done,
  failed,
}
```

### 4.3 Politique de restitution

| Phase | Orbe | Haptique | Voix | Texte |
|---|---|---|---|---|
| `thinking` | `processing` (pulse) | tick bref | après **2,5 s** : « Un instant. » (1×) | bulle « Réflexion… » |
| `working` | `processing` | tick bref | « Je regarde. » (1×, à la 1ʳᵉ occurrence) | bulle « Je regarde… » |
| `responding` | `responding` | — | (la réponse elle-même) | la réponse remplace la bulle |
| `done` | `passive` | tick de fin | — | — |
| `failed` | `error` | motif d'erreur | message d'échec honnête | bulle d'erreur |

Règles :
- Les repères vocaux sont **émis au plus une fois par requête** (drapeaux remis à zéro
  par `beginRequest()`).
- Le repère « Un instant. » est **annulé** si une sortie arrive avant les 2,5 s (cas
  d'une réponse texte rapide : Kita ne doit pas dire « Un instant » puis répondre
  aussitôt).
- Les repères passent par `OutputCoordinator.enqueueSpeech` avec `OutputPriority.high`
  (ils doivent précéder la file, mais céder devant une alerte `critical`).

### 4.4 Interface

```dart
class ProgressReporter {
  ProgressReporter({
    required OutputCoordinator coordinator,
    required Clock clock,
    required void Function(OrbState) onOrbStateChanged,
    required void Function(String? status) onStatusChanged,
    Duration spokenCueDelay = const Duration(milliseconds: 2500),
  });

  void beginRequest();                 // remet à zéro les drapeaux « une fois »
  void report(ProgressPhase phase);
  void endRequest({required bool success});
  void dispose();                      // annule les timers en attente
}
```

`onStatusChanged` alimente un `progressStatusProvider` (String?) que le Shell rend
comme **bulle transitoire** dans le fil de conversation (elle disparaît dès la vraie
réponse). Pas de nouveau plumbing Riverpod dans `orchestration/data` : le provider
injecte le callback, comme pour `onOrbStateChanged`.

### 4.5 Câblage (aucun changement d'interface agent)

- `InputRouter.route()` : `beginRequest()` puis `report(thinking)` dès l'entrée non
  vide ; `endRequest()` dans un `finally`.
- `ConversationEngineImpl`, juste avant `_executeToolCall(call)` : `report(working)`.
- `OutputCoordinator.onSpeechStart()` : `report(responding)`.

Les agents (`DescribeAgent`, `AlertAgent`) ne changent pas : la ConversationEngine sait
quand un outil démarre. C'est suffisant pour la politique ci-dessus et garde le
périmètre borné.

**Attention (piège existant) :** `_onSpeechEnqueued` alimente déjà le fil de
conversation. Les repères vocaux (« Un instant. », « Je regarde. ») y créeraient des
bulles permanentes. Ils doivent donc être marqués comme **transitoires** et exclus du
fil (le statut passe par `onStatusChanged`, pas par une entrée du fil).

## 5. Design — Partie B : latence

Aucun levier ne touche à l'intelligence conversationnelle.

### 5.1 Format d'appel d'outil compact (gain principal : ~15 s)

Aujourd'hui le prompt (`local_provider.dart:380-383`) impose :
```
{"tool_call": {"name": "tool_name", "arguments": {"key": "value"}}}
```
→ ~30 tokens décodés.

Nouveau format demandé au modèle, sur une ligne :
```
TOOL describe
TOOL alert start
```
→ ~4-6 tokens décodés (**~16,5 s → ~3 s**).

Le parseur `_parseGemmaToolResponse` accepte **les deux formats** : il tente d'abord la
ligne `TOOL <nom> [args…]`, et retombe sur le JSON si absent. Cela protège contre une
régression si le modèle, instruction-tuné au JSON, ignore parfois la consigne.

Mapping des arguments : le premier mot après le nom d'outil est la valeur du **premier
paramètre déclaré** de l'outil (`action` pour `alert`). Absent → valeur par défaut.
Après §5.4, `describe` n'a **plus aucun paramètre** : son appel se réduit à
`TOOL describe` (~3 tokens). Si un futur outil demande plusieurs paramètres, il
utilisera le format JSON (toujours accepté par le parseur).

### 5.2 Descriptions d'outils allégées (gain : ~2-3 s)

Le prompt tool-use fait 1991 caractères, dont ~500 pour la seule description de
`describe` (paragraphe en prose) et ~230 pour son paramètre `detail_level` (supprimé
en §5.4). Réduire chaque description à ~120 caractères essentiels. Le prefill n'est
pas dominant : gain modeste mais gratuit.

### 5.3 Première phrase courte (gain perçu : ~15 s sur le premier mot)

Le `SentenceBuffer` n'émet qu'une phrase **terminée**. Une 1ʳᵉ phrase de 45 tokens =
25 s de silence.

`DescribePlugin.describePrompt` gagne une consigne d'ouverture :
> « Décris cette image en français pour une personne aveugle. **Commence par une phrase
> très courte (5 à 8 mots) nommant l'élément principal.** Puis donne les détails,
> organisés spatialement (gauche, droite, devant, derrière). »

→ 1ʳᵉ phrase ~8 tokens ≈ **4,4 s de décodage** au lieu de 25 s.

### 5.4 `describe` : supprimer le paramètre mort `detail_level` (gain : ~15 s sur le total)

**Constat de code :** `DescribePlugin` n'utilise **jamais** l'argument `detail_level`.
Il applique toujours `describePrompt` (long, détaillé). La granularité passe déjà par la
commande vocale existante « plus de détails » (`VoiceCommand.moreDetails`), qui relance
la même image avec `detailedPrompt`.

Ce paramètre est donc du poids mort qui coûte deux fois : ~230 caractères de prompt, et
~12 tokens décodés dans chaque appel d'outil (`"arguments": {"detail_level":
"detailed"}`).

Actions :
- Retirer `detail_level` de `KitaTools.describe`.
- `describePrompt` devient **bref** (2-3 phrases) + la consigne de §5.3.
- `detailedPrompt` (inchangé) reste réservé à « plus de détails ».

### 5.5 Mesuré après implémentation (2026-07-09)

Samsung S21 Ultra, build release, deux requêtes « décris » consécutives.

| | Avant (mesuré) | Estimé | **Après (mesuré)** |
|---|---|---|---|
| Décision tool-use | 22,0 s | ~7 s | **4,0 s / 5,4 s** |
| Photo | 1,5 s | 1,5 s | **0,5 s** |
| 1ʳᵉ phrase | 31,9 s | ~12 s | **10,9 s** |
| **Premier mot entendu** | **55,4 s** | **~20 s** | **17,8 s / 17,0 s** |
| **Total** | **70,3 s** | **~35 s** | **29,3 s / 24,1 s** |

Le repère « Un instant. » est prononcé à **2,50 s** exactement, « Je regarde. » à l'instant
de la prise de photo. Les deux tiennent leur contrat.

Le format compact `TOOL describe` a rapporté davantage que prévu (−17 s sur la décision,
contre −15 s estimés) : le JSON legacy coûtait plus de tokens de décodage que modélisé.

**Dérive de prefill : trouvée, puis résolue.** Une troisième requête, avec un historique
chargé, avait mis **18,6 s** à décider — le prefill croît avec l'historique, et les
résultats d'outil internes y contribuaient pour rien. Depuis qu'ils sont omis du prompt
(§5.6), la même situation — « décris » après trois tours de conversation — décide en
**4,0 s**, soit le temps d'une requête à froid. Le cap `_maxHistoryLength = 20` reste le
levier suivant si la dérive réapparaît sur des conversations plus longues.

### 5.6 Régression trouvée pendant la validation device

Le format compact a introduit un défaut que les tests unitaires ne pouvaient pas voir :
**Gemma appelait `describe` à chaque message.** Une fois le premier appel effectué,
l'historique contenait `[assistant]: (tool call)` ; le modèle voyait son dernier tour et
imitait. « je ne t'ai pas demandé ça » relançait la caméra.

Cause seconde : le prompt ouvrait sur `You have access to the following tools` suivi de la
syntaxe d'appel — cadrage outil-d'abord, sans identité ni consigne de n'appeler qu'à la
demande explicite.

Correctif (`b4e9b7a`) : prompt refait en dialogue few-shot français — identité Kita,
conversation par défaut, exemples positifs **et négatifs**. Les appels passés sont rendus
`Kita : (a utilisé describe)`, les résultats d'outil omis. `stripHallucinatedTurns` coupe
la réponse si le modèle enchaîne en fabriquant le tour suivant.

**Leçon, jumelle de celle du §8 du spec reconnaissance.** Les chronos étaient excellents
pendant que le produit faisait la mauvaise chose. Une métrique verte ne dit rien du
comportement. Ici c'est l'utilisateur qui a écrit « je t'ai pas demandé ça » dans
l'application — c'est ce texte, dans les logs, qui a révélé le bug.

## 6. Accessibilité (obligatoire)

- Les repères vocaux sont courts, accentués, et ne se répètent jamais dans une requête.
- La bulle de statut est un `liveRegion` annoncé au lecteur d'écran.
- Les vibrations utilisent les motifs `HapticService` existants (info / succès / erreur).
- L'orbe respecte `MediaQuery.disableAnimations` (reduced motion) : pas de pulse, mais
  le statut texte et l'haptique restent.

## 7. Tests

Unitaires (`test()` + `ProviderContainer`, pas de `testWidgets` — piège CLAUDE.md) :
1. `thinking` puis sortie **avant** 2,5 s → « Un instant. » **jamais prononcé**.
2. `thinking` pendant > 2,5 s → « Un instant. » prononcé **exactement une fois**.
3. `working` deux fois dans la même requête → « Je regarde. » prononcé une seule fois.
4. `beginRequest()` remet les drapeaux à zéro : la requête suivante peut re-parler.
5. `endRequest()`/`dispose()` annulent le timer en attente (aucun `speak` après).
6. Les repères ne créent **aucune entrée** dans le fil de conversation.
7. Parseur d'outil : `TOOL describe` → tool call sans argument ; `TOOL alert start` →
   argument `action=start` ; JSON legacy → toujours accepté ; texte simple → pas de
   tool call ; `TOOL inconnu` → pas de tool call (traité comme texte).
8. `KitaTools.describe` n'expose plus `detail_level` (le test existant de sa structure
   doit être mis à jour), et « plus de détails » relance toujours `detailedPrompt`.

Instrumentation : les chronos (`Tool-use request completed in Xms`) existent déjà et
serviront à valider les gains sur device.

## 8. Risques

- **Le modèle ignore le format compact** et continue en JSON → le parseur double format
  couvre le cas ; gain de latence perdu, comportement intact. À mesurer.
- **La 1ʳᵉ phrase courte dégrade la qualité** de la description → à juger à l'oreille sur
  device ; réversible (un mot dans le prompt).
- **`clearHistory()` recrée la session native à chaque requête** (correctif de sécurité du
  cycle précédent) : coût non mesuré, potentiellement 1-2 s. À instrumenter ; ne pas le
  retirer sans corriger autrement la contamination texte/vision.
- **35 s restera lent.** Ce spec ne prétend pas rendre l'app confortable, seulement
  supportable et lisible. Le vrai saut (< 20 s) demande un modèle plus petit ou le NPU.

## 9. Hors portée

- Changement de modèle, quantification, backend NPU.
- Nouveaux modules (recette-frigo, alarmes, calories).
- Distribution du modèle à l'utilisateur final.
