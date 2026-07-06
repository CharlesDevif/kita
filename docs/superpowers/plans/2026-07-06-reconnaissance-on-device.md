# Reconnaissance on-device (Gemma local) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire fonctionner le module de reconnaissance `describe` sur un téléphone Android via Gemma 3n en local, hors-ligne, avec un modèle chargé depuis un fichier device (pas embarqué dans l'APK), et un pipeline qui ne reste jamais silencieux en cas d'échec.

**Architecture:** Le chargement du modèle passe de `fromAsset` à `fromFile` (modèle poussé une fois par `adb push`). On extrait des unités pures testables (localisation du fichier modèle, mapping d'erreur, timeout de stream) hors de `GemmaBridgeImpl`, on les branche dans le bridge (vérifié sur device), et on ajoute un écran de diagnostic accessible.

**Tech Stack:** Flutter 3.41 / Dart 3.11, flutter_gemma 0.12.4, path_provider ^2.1.5, Riverpod 3, Drift (inchangé ici), flutter_test.

## Global Constraints

- flutter_gemma **0.12.4** : `ModelFileType.task` couvre `.task` ET `.litertlm` ; `Message.withImage` (singulier) ; `installModel().fromFile(path)` existe. Ne PAS supposer l'API d'une version plus récente.
- `applicationId` = `com.kita.kita`. Chemin device du modèle : `/sdcard/Android/data/com.kita.kita/files/models/gemma-3n-E2B-it-int4.litertlm` (= `getExternalStorageDirectory()/models/...`).
- **Aucune clé API** requise sur ce chemin (100 % local).
- Error handling : `sealed class KitaFailure` + `Result<T>`, jamais de `throw` non typé qui remonte. Attraper `Object` (Error **et** Exception) aux frontières natives.
- Zéro PII dans les logs, format `[Source] Message`.
- Strings françaises **avec accents corrects** (lues par TTS).
- Accessibilité : `Semantics` descriptifs, contrastes ≥ 4.5:1, cibles tactiles ≥ 48×48 (56×56 action critique), états loading/erreur/succès annoncés.
- Propriété fichiers : ce plan touche `lib/features/ai/**` (E2), `lib/features/settings/**` + route (E8/leader), `pubspec.yaml`/`.gitignore`/docs (leader). Pas d'autres features.
- PATH pour les commandes : `export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"`.

---

## File Structure

- `lib/features/ai/data/providers/gemma_model_locator.dart` (créer) — résout le chemin device du modèle et vérifie sa présence. Pur Dart, testable.
- `lib/features/ai/data/providers/gemma_failure.dart` (créer) — mappe n'importe quelle erreur (Error/Exception) vers `AIProviderFailure` avec message FR. Pur, testable.
- `lib/core/utils/stream_timeout.dart` (créer) — extension `Stream<String>.withInferenceTimeout(...)` qui émet une erreur typée si aucun token n'arrive à temps. Pur, testable.
- `lib/features/ai/data/providers/gemma_bridge.dart` (modifier) — `fromFile` via locator, timeout sur les streams, catch `Object` + mapping. Vérifié sur device.
- `lib/features/settings/presentation/diagnostic_screen.dart` (créer) — écran accessible état modèle + bouton test. Widget-testable.
- `lib/features/settings/di/diagnostic_providers.dart` (créer) — provider d'état du modèle pour l'écran.
- `lib/core/navigation/router.dart` (modifier) — route `/settings/diagnostic`.
- `pubspec.yaml` (modifier) — retirer `assets/models/`, ajouter `assets/images/`.
- `.gitignore` (déjà OK pour `*.litertlm`).
- `docs/SETUP_GUIDE.md` (modifier) — procédure `adb push` + `flutter run` WiFi + validation.
- Tests : un fichier de test par unité créée.

---

## Task 1: GemmaModelLocator — localisation du modèle sur l'appareil

**Files:**
- Create: `lib/features/ai/data/providers/gemma_model_locator.dart`
- Test: `test/features/ai/data/providers/gemma_model_locator_test.dart`

**Interfaces:**
- Produces: `class GemmaModelLocator({Future<Directory?> Function()? externalDirResolver, String modelFileName})`, méthode `Future<String?> locate()` (retourne le chemin absolu si le fichier existe, sinon `null`) et `Future<String> expectedPath()` (chemin attendu même si absent, pour les messages).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ai/data/providers/gemma_model_locator_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_model_locator.dart';

void main() {
  group('GemmaModelLocator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gemma_locator_test');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    GemmaModelLocator locatorFor(Directory dir) => GemmaModelLocator(
          externalDirResolver: () async => dir,
          modelFileName: 'model.litertlm',
        );

    test('locate returns null when the model file is absent', () async {
      final locator = locatorFor(tempDir);
      expect(await locator.locate(), isNull);
    });

    test('locate returns the absolute path when the model file exists', () async {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      final file = File('${modelsDir.path}/model.litertlm')
        ..writeAsBytesSync([1, 2, 3]);
      final locator = locatorFor(tempDir);
      expect(await locator.locate(), file.path);
    });

    test('expectedPath is under models/ even when absent', () async {
      final locator = locatorFor(tempDir);
      expect(await locator.expectedPath(),
          '${tempDir.path}/models/model.litertlm');
    });

    test('locate returns null when external dir is unavailable', () async {
      final locator = GemmaModelLocator(
        externalDirResolver: () async => null,
        modelFileName: 'model.litertlm',
      );
      expect(await locator.locate(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/data/providers/gemma_model_locator_test.dart`
Expected: FAIL — `gemma_model_locator.dart` n'existe pas.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/ai/data/providers/gemma_model_locator.dart
import 'dart:io';

import 'package:path_provider/path_provider.dart' as pp;

/// Locates the Gemma model file on the device filesystem.
///
/// The model is NOT bundled in the APK. It is pushed once to
/// `getExternalStorageDirectory()/models/<modelFileName>` (via `adb push`)
/// and loaded from there with `flutter_gemma`'s `fromFile`.
class GemmaModelLocator {
  GemmaModelLocator({
    Future<Directory?> Function()? externalDirResolver,
    this.modelFileName = 'gemma-3n-E2B-it-int4.litertlm',
  }) : _externalDirResolver =
            externalDirResolver ?? pp.getExternalStorageDirectory;

  final Future<Directory?> Function() _externalDirResolver;
  final String modelFileName;

  /// Absolute path where the model is expected, even if it is not present yet.
  /// Throws [StateError] if external storage is unavailable.
  Future<String> expectedPath() async {
    final dir = await _externalDirResolver();
    if (dir == null) {
      throw StateError('External storage directory unavailable');
    }
    return '${dir.path}/models/$modelFileName';
  }

  /// Returns the absolute path of the model file if it exists, else `null`.
  Future<String?> locate() async {
    final dir = await _externalDirResolver();
    if (dir == null) return null;
    final path = '${dir.path}/models/$modelFileName';
    return File(path).existsSync() ? path : null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ai/data/providers/gemma_model_locator_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze + commit**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos lib/features/ai/data/providers/gemma_model_locator.dart test/features/ai/data/providers/gemma_model_locator_test.dart
git add lib/features/ai/data/providers/gemma_model_locator.dart test/features/ai/data/providers/gemma_model_locator_test.dart
git commit -m "feat(ai): GemmaModelLocator pour chargement du modèle depuis l'appareil"
```

---

## Task 2: gemmaFailure — mapping d'erreur typé (Error ET Exception)

**Files:**
- Create: `lib/features/ai/data/providers/gemma_failure.dart`
- Test: `test/features/ai/data/providers/gemma_failure_test.dart`

**Interfaces:**
- Produces: `AIProviderFailure gemmaFailure(Object error, {String? userMessage, StackTrace? stackTrace})` — mappe n'importe quel `Object` lancé (y compris `StateError`, `Error`) vers un `AIProviderFailure` avec `providerId: 'gemma'` et un message utilisateur FR par défaut accentué.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ai/data/providers/gemma_failure_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/features/ai/data/providers/gemma_failure.dart';

void main() {
  group('gemmaFailure', () {
    test('maps a StateError (an Error, not an Exception) to AIProviderFailure', () {
      final failure = gemmaFailure(StateError('already processing'));
      expect(failure, isA<AIProviderFailure>());
      expect(failure.providerId, 'gemma');
      // Message user par défaut, accentué, sans détail technique.
      expect(failure.userMessage, contains('reconnaissance'));
      expect(failure.userMessage, isNot(contains('StateError')));
      // Le détail technique est conservé côté log.
      expect(failure.logMessage, contains('already processing'));
    });

    test('maps an Exception too', () {
      final failure = gemmaFailure(Exception('boom'));
      expect(failure.providerId, 'gemma');
      expect(failure.logMessage, contains('boom'));
    });

    test('honours a custom user message', () {
      final failure = gemmaFailure(
        Exception('x'),
        userMessage: 'Le modèle IA est indisponible.',
      );
      expect(failure.userMessage, 'Le modèle IA est indisponible.');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ai/data/providers/gemma_failure_test.dart`
Expected: FAIL — `gemma_failure.dart` n'existe pas.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/ai/data/providers/gemma_failure.dart
import '../../../../core/errors/kita_failure.dart';

/// Maps ANY thrown object (Exception or Error, e.g. [StateError]) coming out
/// of the native Gemma layer into a typed [AIProviderFailure].
///
/// Native/plugin code can throw `Error` subtypes that would otherwise slip
/// through `catch (Exception)` clauses. Always route Gemma failures here so a
/// user (Marie, blind) hears an honest spoken message instead of a raw crash.
AIProviderFailure gemmaFailure(
  Object error, {
  String? userMessage,
  StackTrace? stackTrace,
}) {
  return AIProviderFailure(
    userMessage:
        userMessage ?? "La reconnaissance n'a pas pu aboutir. Réessaie.",
    logMessage: 'Gemma failure: $error',
    providerId: 'gemma',
    cause: error,
    stackTrace: stackTrace,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ai/data/providers/gemma_failure_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyze + commit**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos lib/features/ai/data/providers/gemma_failure.dart test/features/ai/data/providers/gemma_failure_test.dart
git add lib/features/ai/data/providers/gemma_failure.dart test/features/ai/data/providers/gemma_failure_test.dart
git commit -m "feat(ai): gemmaFailure mappe Error et Exception vers KitaFailure typé"
```

---

## Task 3: withInferenceTimeout — timeout de stream d'inférence

**Files:**
- Create: `lib/core/utils/stream_timeout.dart`
- Test: `test/core/utils/stream_timeout_test.dart`

**Interfaces:**
- Produces: extension `InferenceTimeout on Stream<String>` avec `Stream<String> withInferenceTimeout(Duration timeout)` — relaie les tokens ; si l'écart entre deux tokens (ou avant le premier) dépasse `timeout`, ajoute une `TimeoutException` dans le flux puis le termine.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/stream_timeout_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/stream_timeout.dart';

void main() {
  group('withInferenceTimeout', () {
    test('relays tokens that arrive in time', () async {
      final source = Stream<String>.fromIterable(['a', 'b', 'c']);
      final result =
          await source.withInferenceTimeout(const Duration(seconds: 1)).toList();
      expect(result, ['a', 'b', 'c']);
    });

    test('emits a TimeoutException when the stream stalls', () async {
      final controller = StreamController<String>();
      final events = <String>[];
      Object? error;
      final done = Completer<void>();

      controller.stream
          .withInferenceTimeout(const Duration(milliseconds: 50))
          .listen(
        events.add,
        onError: (Object e) => error = e,
        onDone: done.complete,
      );

      controller.add('first');
      // Then never add another token → should time out.
      await done.future;
      expect(events, ['first']);
      expect(error, isA<TimeoutException>());
      await controller.close();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/stream_timeout_test.dart`
Expected: FAIL — `stream_timeout.dart` n'existe pas.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/stream_timeout.dart
import 'dart:async';

/// Adds an inactivity timeout to an inference token stream.
extension InferenceTimeout on Stream<String> {
  /// Relays tokens; if no token arrives within [timeout] (before the first
  /// token or between two tokens), surfaces a [TimeoutException] and ends the
  /// stream. Prevents a stalled on-device inference from hanging forever with
  /// no spoken feedback.
  Stream<String> withInferenceTimeout(Duration timeout) {
    return this.timeout(
      timeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException('Inference produced no token within $timeout'),
        );
        sink.close();
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/stream_timeout_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze + commit**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos lib/core/utils/stream_timeout.dart test/core/utils/stream_timeout_test.dart
git add lib/core/utils/stream_timeout.dart test/core/utils/stream_timeout_test.dart
git commit -m "feat(core): withInferenceTimeout pour flux d'inférence figé"
```

> **Note ownership :** `lib/core/**` est propriété du leader. Si l'exécutant n'est pas le leader, signaler cet ajout ; sinon placer plutôt le helper dans `lib/features/ai/data/providers/stream_timeout.dart` (même code, import ajusté dans la Task 4).

---

## Task 4: Brancher fromFile + timeout + catch Object dans GemmaBridgeImpl

**Files:**
- Modify: `lib/features/ai/data/providers/gemma_bridge.dart`
- Verification: sur device (les appels `FlutterGemma.*` sont natifs, pas de test unitaire). Les tests existants `test/features/ai/data/providers/gemma_bridge_test.dart` (MockGemmaBridge) doivent continuer à passer.

**Interfaces:**
- Consumes: `GemmaModelLocator` (Task 1), `gemmaFailure` (Task 2), `withInferenceTimeout` (Task 3).
- Produces: `GemmaBridgeImpl({GemmaModelLocator? locator, Duration inferenceTimeout})` — le paramètre `modelAssetPath` est remplacé par le chargement `fromFile` via le locator.

- [ ] **Step 1: Remplacer le champ de constructeur et le chargement**

Dans `lib/features/ai/data/providers/gemma_bridge.dart`, remplacer le constructeur et le champ :

```dart
  GemmaBridgeImpl({
    GemmaModelLocator? locator,
    this.inferenceTimeout = const Duration(seconds: 30),
  }) : _locator = locator ?? GemmaModelLocator();

  final GemmaModelLocator _locator;
  final Duration inferenceTimeout;
```

Ajouter en tête de fichier :

```dart
import 'gemma_failure.dart';
import 'gemma_model_locator.dart';
import '../../../../core/utils/stream_timeout.dart';
```

- [ ] **Step 2: Charger via fromFile dans `_ensureInitialized`**

Remplacer le corps de `_ensureInitialized()` (bloc `installModel().fromAsset(...)`) par :

```dart
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    _log.info('Initializing Gemma model from device file');
    _status = GemmaModelStatus.loading;

    try {
      final path = await _locator.locate();
      if (path == null) {
        _status = GemmaModelStatus.error;
        throw gemmaFailure(
          StateError('model file not found'),
          userMessage:
              "Le modèle IA est introuvable sur l'appareil. Voir l'installation.",
        );
      }

      await FlutterGemma.initialize();

      final installed = await FlutterGemma.isModelInstalled(path);
      if (!installed) {
        _log.info('Installing Gemma model from device file');
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.task, // couvre .task ET .litertlm en 0.12.4
        ).fromFile(path).install();
      }

      _textModel = await FlutterGemma.getActiveModel(
        maxTokens: 512,
        preferredBackend: PreferredBackend.gpu,
      );

      _initialized = true;
      _status = GemmaModelStatus.ready;
      _log.info('Gemma model ready');
    } on Object catch (e, stack) {
      _log.error('Gemma initialization failed', error: e, stackTrace: stack);
      _status = GemmaModelStatus.error;
      rethrow;
    }
  }
```

- [ ] **Step 3: Timeout + catch Object sur les streams**

Dans `completeStream`, envelopper la boucle de tokens avec le timeout et attraper `Object`. Remplacer le corps `try { ... } finally { _processing = false; }` par :

```dart
    _processing = true;
    try {
      await _ensureInitialized();
      final chat = await _getOrCreateTextChat();
      final mergedPrompt = systemPrompt != null
          ? '[Instructions]\n$systemPrompt\n\n[Message]\n$prompt'
          : prompt;
      await chat.addQueryChunk(Message.text(text: mergedPrompt, isUser: true));

      final tokens = chat
          .generateChatResponseAsync()
          .where((r) => r is TextResponse)
          .map((r) => (r as TextResponse).token)
          .withInferenceTimeout(inferenceTimeout);
      yield* tokens;
    } on Object catch (e, stack) {
      _log.error('Gemma completeStream failed', error: e, stackTrace: stack);
      throw gemmaFailure(e, stackTrace: stack);
    } finally {
      _processing = false;
    }
```

Appliquer le MÊME motif à `describeImageStream` (envelopper le flux vision avec `.withInferenceTimeout(inferenceTimeout)` et `on Object catch` → `throw gemmaFailure(...)`).

**Mémoire (#348) :** `describeImageStream` crée déjà un `chat` vision neuf à chaque appel (pas de session vision persistante) — le conserver ainsi. Pour libérer au plus tôt, appeler `await _visionModel?.close()` puis remettre `_visionModel = null` dans le `finally` de `describeImageStream` afin que la session native soit recréée (et donc libérée) à chaque description. L'ampleur réelle de la fuite se mesure sur device (Task 7, observer le RSS sur plusieurs inférences).

- [ ] **Step 4: Retirer le champ `modelAssetPath` mort**

Supprimer toute référence restante à `modelAssetPath` (champ, constructeur, usages). Vérifier qu'aucun autre fichier ne l'utilise :

```bash
grep -rn "modelAssetPath" lib/ test/
```
Expected: aucun résultat.

- [ ] **Step 5: Vérifier que les tests existants passent + analyze**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
flutter test test/features/ai/data/providers/gemma_bridge_test.dart
dart analyze --fatal-infos lib/features/ai/data/providers/gemma_bridge.dart
```
Expected: tests PASS (le mock n'est pas affecté), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai/data/providers/gemma_bridge.dart
git commit -m "feat(ai): GemmaBridge charge le modèle via fromFile + timeout + catch Error"
```

---

## Task 5: Sortir le modèle de l'APK (pubspec) + documenter adb push

**Files:**
- Modify: `pubspec.yaml`
- Modify: `docs/SETUP_GUIDE.md`

**Interfaces:** aucun code consommateur ; change le packaging + la doc.

- [ ] **Step 1: Retirer `assets/models/` et ajouter `assets/images/` dans pubspec**

Dans `pubspec.yaml`, section `assets:`, remplacer :

```yaml
  assets:
    - assets/sounds/
    - assets/models/
```
par :
```yaml
  assets:
    - assets/sounds/
    - assets/images/
```

Créer le dossier et un placeholder pour l'image de test (remplacée en Task 6) :

```bash
mkdir -p assets/images
# Placeholder : une petite image de test sera ajoutée en Task 6.
```

- [ ] **Step 2: Vérifier que le build ne référence plus le modèle en asset**

```bash
grep -rn "assets/models" lib/ pubspec.yaml
```
Expected: aucun résultat (le modèle est chargé via fromFile).

- [ ] **Step 3: Documenter la procédure dans SETUP_GUIDE**

Dans `docs/SETUP_GUIDE.md`, section 5 (IA locale), remplacer la sous-section « 5.3 Placer le modèle dans le projet » par une sous-section « 5.3 Pousser le modèle sur l'appareil (dev) » contenant :

```markdown
### 5.3 Pousser le modèle sur l'appareil (dev)

Le modèle n'est PAS embarqué dans l'APK (il ferait 3,5 Go). On le pousse une
fois sur le téléphone de test ; l'app le charge depuis ce fichier.

```bash
# Créer le dossier cible (accessible sans root)
adb shell mkdir -p /sdcard/Android/data/com.kita.kita/files/models

# Pousser le modèle (une seule fois par appareil)
adb push gemma-3n-E2B-it-int4.litertlm \
  /sdcard/Android/data/com.kita.kita/files/models/

# Vérifier
adb shell ls -lh /sdcard/Android/data/com.kita.kita/files/models/
```

Le modèle survit aux réinstallations de l'app tant que le dossier `files/`
n'est pas effacé. Pour la distribution finale (utilisateur réel), la stratégie
sera décidée dans un cycle dédié (bundled / téléchargement in-app).
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml docs/SETUP_GUIDE.md assets/images
git commit -m "chore: sortir le modèle Gemma de l'APK, documenter adb push (dev)"
```

---

## Task 6: Écran de diagnostic accessible

**Files:**
- Create: `lib/features/settings/di/diagnostic_providers.dart`
- Create: `lib/features/settings/presentation/diagnostic_screen.dart`
- Create: `assets/images/test_scene.jpg` (petite image, ~50–100 Ko)
- Modify: `lib/core/navigation/router.dart`
- Test: `test/features/settings/presentation/diagnostic_screen_test.dart`

**Interfaces:**
- Consumes: `gemmaBridgeProvider` (lib/features/orchestration/di/providers.dart) → `GemmaBridge` avec `checkStatus()` / `describeImage(Uint8List)`.
- Produces: `diagnosticScreen` route `/settings/diagnostic`, `class DiagnosticScreen extends ConsumerStatefulWidget`.

- [ ] **Step 1: Provider d'état modèle**

```dart
// lib/features/settings/di/diagnostic_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/providers/gemma_bridge.dart';
import '../../orchestration/di/providers.dart';

/// Exposes the current Gemma model status for the diagnostic screen.
final gemmaStatusProvider = FutureProvider.autoDispose<GemmaModelStatus>((ref) {
  final bridge = ref.watch(gemmaBridgeProvider);
  return bridge.checkStatus();
});
```

- [ ] **Step 2: Write the failing widget test**

```dart
// test/features/settings/presentation/diagnostic_screen_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/settings/presentation/diagnostic_screen.dart';

class _FakeBridge implements GemmaBridge {
  _FakeBridge(this._status);
  final GemmaModelStatus _status;
  @override
  Future<GemmaModelStatus> checkStatus() async => _status;
  @override
  Future<GemmaVisionResult> describeImage(Uint8List bytes, {String? prompt}) async =>
      const GemmaVisionResult(description: 'une scène de test');
  @override
  Future<GemmaCompletionResult> complete(String p,
          {String? systemPrompt, int? maxTokens}) async =>
      const GemmaCompletionResult(text: '');
  @override
  Stream<String> completeStream(String p, {String? systemPrompt, int? maxTokens}) =>
      const Stream.empty();
  @override
  Stream<String> describeImageStream(Uint8List b, {String? prompt}) =>
      Stream.value('une scène de test');
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('affiche « Modèle chargé » quand le statut est ready', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gemmaBridgeProvider.overrideWithValue(_FakeBridge(GemmaModelStatus.ready)),
        ],
        child: const MaterialApp(home: DiagnosticScreen()),
      ),
    );
    await tester.pump(); // résout le FutureProvider
    expect(find.textContaining('Modèle chargé'), findsOneWidget);
  });

  testWidgets('a des Semantics descriptifs sur l\'état', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gemmaBridgeProvider.overrideWithValue(_FakeBridge(GemmaModelStatus.error)),
        ],
        child: const MaterialApp(home: DiagnosticScreen()),
      ),
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp("État du modèle")),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/diagnostic_screen_test.dart`
Expected: FAIL — `diagnostic_screen.dart` n'existe pas.

- [ ] **Step 4: Implémenter l'écran**

```dart
// lib/features/settings/presentation/diagnostic_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SemanticsService, TextDirection, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/providers/gemma_bridge.dart';
import '../../orchestration/di/providers.dart';
import '../di/diagnostic_providers.dart';

/// Accessible diagnostic screen: shows the on-device model status and lets the
/// user run a vision inference on a bundled test image, so recognition can be
/// verified without the camera.
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  String? _testResult;
  bool _testing = false;

  Future<void> _runVisionTest() async {
    setState(() => _testing = true);
    try {
      final bytes = (await rootBundle.load('assets/images/test_scene.jpg'))
          .buffer
          .asUint8List();
      final bridge = ref.read(gemmaBridgeProvider);
      final result = await bridge.describeImage(bytes);
      if (!mounted) return;
      setState(() => _testResult = result.description);
      await SemanticsService.announce(
          'Test réussi. $result', TextDirection.ltr);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _testResult = "Le test de reconnaissance a échoué.");
      await SemanticsService.announce(
          'Le test de reconnaissance a échoué.', TextDirection.ltr);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _statusLabel(GemmaModelStatus s) => switch (s) {
        GemmaModelStatus.ready => 'Modèle chargé et prêt',
        GemmaModelStatus.loading => 'Modèle en cours de chargement',
        GemmaModelStatus.error => 'Modèle indisponible',
      };

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(gemmaStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'État du modèle de reconnaissance',
              child: statusAsync.when(
                data: (s) => Text(_statusLabel(s),
                    style: Theme.of(context).textTheme.titleMedium),
                loading: () => const Text('Vérification du modèle…'),
                error: (_, __) => const Text('Modèle indisponible'),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Tester la reconnaissance sur une image de test',
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _testing ? null : _runVisionTest,
                  child: Text(_testing ? 'Test en cours…' : 'Tester la reconnaissance'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_testResult != null)
              Semantics(
                label: 'Résultat du test',
                child: Text(_testResult!),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Ajouter l'image de test**

Placer une petite image JPEG (~50–100 Ko) représentant une scène simple dans `assets/images/test_scene.jpg`. (Réutiliser `bus.jpg` téléchargée pendant la validation YOLO, ou toute photo libre de droits.)

```bash
ls -lh assets/images/test_scene.jpg
```
Expected: le fichier existe (< 200 Ko).

- [ ] **Step 6: Câbler la route**

Dans `lib/core/navigation/router.dart`, ajouter l'import et la route enfant sous `/settings` :

```dart
import '../../features/settings/presentation/diagnostic_screen.dart';
```
```dart
      GoRoute(
        path: 'diagnostic',
        builder: (context, state) => const DiagnosticScreen(),
      ),
```

- [ ] **Step 7: Run tests + analyze**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
flutter test test/features/settings/presentation/diagnostic_screen_test.dart
dart analyze --fatal-infos lib/features/settings/ lib/core/navigation/router.dart
```
Expected: tests PASS, analyze clean.

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/di/diagnostic_providers.dart lib/features/settings/presentation/diagnostic_screen.dart test/features/settings/presentation/diagnostic_screen_test.dart lib/core/navigation/router.dart assets/images/test_scene.jpg
git commit -m "feat(settings): écran de diagnostic accessible (état modèle + test vision)"
```

---

## Task 7: Validation sur device (flutter run / WiFi) — manuelle

**Files:** aucun (procédure de vérification avec Charles).

**Interfaces:** consomme tout ce qui précède ; produit la preuve que la reconnaissance marche.

- [ ] **Step 1: Vérifier la suite complète + analyze avant device**

```bash
export PATH="$HOME/development/flutter/bin:/usr/bin:/bin:$PATH"
dart analyze --fatal-infos
flutter test
```
Expected: analyze clean, tous les tests PASS.

- [ ] **Step 2: Pousser le modèle sur l'appareil (une fois)**

```bash
adb shell mkdir -p /sdcard/Android/data/com.kita.kita/files/models
adb push gemma-3n-E2B-it-int4.litertlm /sdcard/Android/data/com.kita.kita/files/models/
adb shell ls -lh /sdcard/Android/data/com.kita.kita/files/models/
```
Expected: le fichier ~3,5 Go est présent sur l'appareil.

- [ ] **Step 3: Lancer l'app par WiFi et vérifier le diagnostic**

```bash
flutter run   # appareil connecté en débogage sans fil
```
Naviguer vers `/settings/diagnostic` → confirmer « Modèle chargé et prêt » → appuyer « Tester la reconnaissance » → une description de l'image de test est affichée/vocalisée. Observer les logs `[AI.Gemma]`.

Expected: statut ready, description non vide, aucun crash.

- [ ] **Step 4: Vérifier « décris » sur une vraie scène**

Sur l'écran principal, pointer la caméra vers une scène simple, dire « décris ». Observer `[Describe]` / `[AI.Gemma]`.

Expected: description parlée cohérente de la scène, hors-ligne, sans clé API. Un échec éventuel (ex. modèle absent) produit un message vocal honnête, jamais un silence.

- [ ] **Step 5: Consigner le résultat**

Noter dans le fichier spec (section validation) : appareil testé, temps de réponse observé, succès/échecs, et tout ajustement nécessaire (timeout, backend GPU/CPU). Commit du spec mis à jour.

```bash
git add docs/superpowers/specs/2026-07-06-reconnaissance-on-device-design.md
git commit -m "docs: résultats de validation on-device de la reconnaissance"
```
