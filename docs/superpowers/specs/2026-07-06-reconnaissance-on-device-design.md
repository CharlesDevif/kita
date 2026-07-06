# Spec — Faire fonctionner le module de reconnaissance sur l'appareil (Gemma local)

- **Date :** 2026-07-06
- **Auteur :** Charles + Claude
- **Statut :** proposé (en attente de relecture)
- **Branche :** `develop`

## 1. Objectif et portée

**Objectif :** que le module de reconnaissance de base (`describe` / com.kita.describe)
fonctionne de bout en bout **sur le téléphone Android de test**, en **local via Gemma 3n**,
**hors-ligne**, débogable en direct par `flutter run` sur WiFi.

C'est le « module de base » exigé avant d'ajouter les futurs modules (recette-frigo,
alarmes, suivi calories). L'architecture de modules (`KitaAgent`) existe déjà ; ce cycle
la **prouve** sur un module réel.

### Dans la portée
- Livraison du modèle Gemma **hors de l'APK**, poussé une fois sur l'appareil (`adb push`),
  chargé via `fromFile`.
- Fiabilisation du pipeline de reconnaissance (dégradation gracieuse, jamais de blocage
  ou de fausse alerte vocale silencieuse).
- Un **écran de diagnostic** accessible pour vérifier l'état du modèle.
- Procédure de validation sur device par `flutter run` / WiFi.

### Hors portée (cycles suivants)
- Les modules recette-frigo / alarmes / calories (chacun son cycle : spec → plan → impl).
- La **stratégie de distribution finale** pour l'utilisateur réel (bundled, download
  in-app, companion…). `adb push` est une étape de **dev** pour prouver la base ; elle
  n'est pas destinée à Marie/l'utilisateur final.
- Le chemin cloud (Claude/OpenAI). Déjà câblé, optionnel, non requis ici.

## 2. Prérequis — aucune clé API

Le chemin de base **ne nécessite AUCUNE clé API**. La reconnaissance tourne à 100 % en
local sur l'appareil via Gemma 3n. Les providers cloud sont un renfort optionnel
(déjà câblé) et ne sont pas sollicités sur ce chemin.

Prérequis réels :
- Un téléphone Android compatible (≈ 6 Go RAM, GPU récent — Adreno 640+ / Mali-G77+),
  débogage sans fil activé (`flutter run` par WiFi).
- Le fichier modèle `gemma-3n-E2B-it-int4.litertlm` (~3,5 Go, déjà présent sur le PC).
- `adb` fonctionnel.

## 3. État actuel (constats)

- `GemmaBridgeImpl` (lib/features/ai/data/providers/gemma_bridge.dart) charge le modèle
  via `FlutterGemma.installModel(...).fromAsset('assets/models/gemma-3n-E2B-it-int4.litertlm')`.
  → le modèle est **embarqué dans l'APK** : APK de 3,5 Go, réinstallé à chaque
  `flutter run` (intenable par WiFi).
- flutter_gemma **0.12.4** confirmé : `ModelFileType.task` couvre `.task` **et** `.litertlm`
  (donc le format actuel est correct) ; `Message.withImage`, `installModel().fromFile()`,
  `.fromNetwork()`, `.withProgress()` existent bien. **L'usage de l'API est correct.**
- Pipeline reconnaissance (vérifié) :
  `« décris »` → InputRouter → spawn describe → `context.sensors.capturePhoto()`
  → strip EXIF → `context.ai.visionStream(image, prompt)` → `routeVisionStream`
  → FallbackChain → LocalProvider → `GemmaBridge.describeImageStream`
  → tokens → SentenceBuffer → `output.speak()` → TTS.
- Risques de fiabilité (audit Phase 2) sur la voie Gemma :
  - `StateError` (« already processing », « disposed ») lancés par `completeStream` /
    `describeImageStream` : ce sont des `Error`, pas des `Exception`, donc ils traversent
    les `catch (Exception)` du pipeline et peuvent remonter brut.
  - Streams d'inférence sans timeout : si l'inférence se fige, le flux ne se termine
    jamais → l'utilisateur reste sans réponse ni message.
  - Fuite mémoire GPU/native connue de flutter_gemma 0.12.4 (issue #348) en usage soutenu.

## 4. Design

### 4.1 Livraison du modèle : `fromFile` + `adb push`

`GemmaBridgeImpl` charge le modèle depuis un **chemin fichier sur l'appareil**, pas depuis
les assets.

- Chemin cible sur l'appareil : dossier de stockage externe applicatif obtenu via
  `path_provider` (`getExternalStorageDirectory()`), sous-dossier `models/`, fichier
  `gemma-3n-E2B-it-int4.litertlm`. `applicationId` = `com.kita.kita`, donc le dossier est
  accessible en `adb push` sans root : `/sdcard/Android/data/com.kita.kita/files/models/`.
- `_ensureInitialized()` :
  1. Résout le chemin cible.
  2. Si le fichier est absent → statut `error` + message clair (« Modèle IA introuvable.
     Voir la procédure d'installation. ») ; ne tente PAS de télécharger.
  3. Si présent → `FlutterGemma.installModel(modelType: ModelType.gemmaIt,
     fileType: ModelFileType.task).fromFile(path).install()` puis `getActiveModel(...)`.
- Le constructeur accepte un `modelFilePath` optionnel (défaut : le chemin résolu) pour
  l'injection en test.
- **`pubspec.yaml`** : retirer `assets/models/` des assets (le modèle n'est plus embarqué).
  Le `.gitignore` continue d'exclure `*.litertlm`.

**Procédure `adb push` (documentée dans le SETUP_GUIDE) :**
```bash
adb shell mkdir -p /sdcard/Android/data/com.kita.kita/files/models
adb push gemma-3n-E2B-it-int4.litertlm \
  /sdcard/Android/data/com.kita.kita/files/models/
```
À faire une seule fois par appareil de test. Le modèle survit aux réinstallations de
l'app tant que le dossier `files/` n'est pas effacé.

### 4.2 Fiabilisation du pipeline

Dans `GemmaBridgeImpl` :
- **Attraper les `Error` autant que les `Exception`** aux frontières (`completeStream`,
  `describeImageStream`, `checkStatus`, `warmUp`) : convertir tout échec en `KitaFailure`
  typé propre, jamais de `StateError` brut qui remonte.
- **Timeout sur les streams d'inférence** : si aucun token n'arrive en N secondes
  (constante configurable, ex. 30 s), fermer le flux et renvoyer un échec explicite.
- **Guard `_processing`** conservé (déjà présent), mais un rejet « already processing »
  devient un `KitaFailure` propre, pas un `StateError`.
- **Session/mémoire** : libérer/recycler la session de chat entre inférences vision pour
  limiter la fuite #348 (à valider par mesure sur device).

Dans le pipeline `describe` : les `catch` qui n'attrapaient que `Exception` attrapent
aussi les échecs remontés, et **toujours** produire une sortie vocale (succès ou message
d'échec honnête) — jamais de silence pour un utilisateur aveugle.

### 4.3 Écran de diagnostic accessible

Nouvel écran (route `/settings/diagnostic`, ou intégré aux réglages) qui affiche et
**annonce au lecteur d'écran** :
- Présence du fichier modèle (chemin, taille) : ✓ / ✗
- État du chargement Gemma (`checkStatus`) : prêt / en chargement / erreur
- Un bouton « Tester la reconnaissance » qui lance une inférence vision sur une **image
  de test embarquée** (petite, ~50–100 Ko, dans un nouveau dossier `assets/images/`
  déclaré au `pubspec` — sans rapport avec le retrait de `assets/models/`) et
  affiche/vocalise le résultat.

But : donner à Charles un retour clair « Modèle chargé ✓ / inférence vision OK ✓ » sans
dépendre de la caméra ni d'une session de débogage.

### 4.4 Accessibilité (obligatoire)

- Tout nouvel écran : `Semantics` descriptifs, contrastes ≥ 4.5:1, cibles tactiles
  ≥ 48×48 (56×56 pour l'action de test), états loading/erreur/succès annoncés.
- Strings françaises **avec accents corrects** (lues par TTS).

## 5. Vérification (le livrable réel)

Sur le téléphone de Charles, par `flutter run` / WiFi :
1. `adb push` du modèle (une fois).
2. `flutter run` (APK petit, rapide).
3. Ouvrir l'écran de diagnostic → confirmer « Modèle chargé ✓ », lancer « Tester la
   reconnaissance » → description de l'image de test vocalisée.
4. Sur l'écran principal : pointer la caméra, dire « décris » → observer les logs
   `[AI.Gemma]` / `[Describe]` → description vocale de la scène réelle.

**Critères de succès :**
- Le modèle se charge depuis le fichier device (pas d'asset dans l'APK).
- `flutter run` par WiFi ne pousse pas 3,5 Go (APK ≪ 3,5 Go).
- « décris » produit une description parlée cohérente de la scène, hors-ligne, sans clé API.
- Un échec (modèle absent, inférence figée) produit un **message vocal honnête**, jamais
  un silence ni un crash.

## 6. Comment on ajoutera les futurs modules (contexte, hors portée)

Chaque futur module = un `KitaAgent` : manifeste (id reverse-domain, permissions,
capacités, commandes vocales) + cycle de vie (`onSpawn`/`handleInput`/`onTerminate`) +
un `plugin.kita.yaml`, enregistré auprès de l'`AgentSupervisor`.

- **Recette-frigo** : réutilise la reconnaissance (caméra → Gemma identifie les aliments)
  puis un appel texte Gemma génère des recettes → TTS. Permissions : `camera`, `ai.vision`,
  `ai.text`. C'est le meilleur premier nouveau module car il prolonge directement la base.
- **Alarmes / rappels hebdo** : agent persistant + `Clock` + notifications ; permissions
  `tts`, éventuellement `memory`.
- **Suivi calories** : caméra + reconnaissance d'aliments + `memory` pour l'historique.

Une fois la reconnaissance validée, on documentera « comment ajouter un module » et on
attaquera la recette-frigo dans son propre cycle.

## 7. Risques et hypothèses

- **`.litertlm` en vision mobile** : format correct pour l'API, mais le support mobile du
  `.litertlm` a une issue ouverte en amont (#150). Repli si nécessaire : basculer sur la
  variante `.task` du même modèle (même code, `fileType` inchangé). À confirmer sur device.
- **Capacité du téléphone** : Gemma 3n E2B exige un appareil correct ; validé seulement
  au run réel (d'où `flutter run`/WiFi avec logs).
- **Fuite mémoire #348** : atténuée par le recyclage de session ; à mesurer, pas éliminée
  tant qu'on reste en 0.12.4 (montée en 1.x = Flutter 3.44+, hors portée).
