import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/data/database.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/ai_router.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/tool_models.dart';
import 'package:kita/features/io/data/providers/stt_providers.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/stt_service.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/core/di/database_provider.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/di/providers.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/shell/presentation/shell_onboarding.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../../mocks/mock_secure_key_vault.dart';

void main() {
  late _FakeTTSService fakeTts;
  late _FakeSTTService fakeStt;
  late _FakePermissionRequester fakePermissions;
  late _FakeAIRouter fakeAIRouter;
  late _FakeGemmaBridge fakeGemmaBridge;
  late KitaDatabase db;

  setUp(() {
    fakeTts = _FakeTTSService();
    fakeStt = _FakeSTTService();
    fakePermissions = _FakePermissionRequester();
    fakeAIRouter = _FakeAIRouter();
    fakeGemmaBridge = _FakeGemmaBridge();
    // Real in-memory Drift DB so the returning-user check and completion
    // persistence run end-to-end against Drift (integration cover). We override
    // the DB + secure-vault leaves (below) and let the real
    // preferencesRepositoryProvider build on top — this exercises the real
    // provider chain and avoids overriding a provider that watches others.
    db = KitaDatabase(NativeDatabase.opened(sql.sqlite3.openInMemory()));
  });

  tearDown(() async {
    fakeTts.dispose();
    await db.close();
  });

  Widget buildTestApp({
    bool sttAvailable = true,
    bool aiAvailable = false,
  }) {
    fakeStt.shouldFail = !sttAvailable;
    fakeAIRouter.hasProviders = aiAvailable;

    return ProviderScope(
      overrides: [
        detectedProfileProvider.overrideWith(
          (ref) => Stream.value(DetectedProfile.general),
        ),
        ttsServiceProvider.overrideWithValue(fakeTts),
        sttServiceProvider.overrideWithValue(fakeStt),
        permissionRequesterProvider.overrideWithValue(fakePermissions),
        aiRouterProvider.overrideWithValue(fakeAIRouter),
        gemmaBridgeProvider.overrideWithValue(fakeGemmaBridge),
        // Override the two DB-chain leaves with in-memory equivalents and let
        // the REAL preferencesRepositoryProvider (+ memoryVaultProvider) build
        // on top. Overriding leaves (which watch nothing) instead of the
        // repository provider keeps us off the device's encrypted store without
        // tripping riverpod's scoped-provider dependency rule.
        kitaDatabaseProvider.overrideWith((ref) => db),
        secureKeyVaultProvider.overrideWithValue(MockSecureKeyVault()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ShellOnboarding(),
        ),
      ),
    );
  }

  group('ShellOnboarding greeting', () {
    testWidgets('announces mic permission then speaks greeting on mount',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // First: mic announcement, then greeting
      expect(fakeTts.spokenTexts[0], contains('Bonjour'));
      expect(fakeTts.spokenTexts[0], contains('micro'));
      expect(fakeTts.lastSpokenText, contains('Kita'));
      expect(fakeTts.lastSpokenText, contains('appelles'));
    });

    testWidgets('displays greeting message in viewport', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_status')), findsOneWidget);
      // After the full flow, the greeting message is shown
      expect(find.textContaining('Kita'), findsOneWidget);
    });

    testWidgets('requests mic permission after announcement', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(fakePermissions.requestedPermissions,
          contains(KitaPermission.microphone));
    });

    testWidgets('captures name via STT and advances to camera step',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // TTS completion -> STT starts
      await tester.pump();
      expect(fakeStt.isListening, isTrue);

      // User says "Marie"
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();

      // Should have advanced to camera permission step
      expect(fakeTts.lastSpokenText, contains('caméra'));
      expect(fakeTts.lastSpokenText, contains('Enchantée Marie'));
    });

    testWidgets('skips name on voice "passer"', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // TTS completion -> STT starts
      await tester.pump();
      fakeStt.emitTranscript('passer');
      await tester.pumpAndSettle();

      // Should advance to camera permission without name
      expect(fakeTts.lastSpokenText, contains('caméra'));
      expect(fakeTts.lastSpokenText, isNot(contains('Marie')));
    });

    testWidgets('skips name when transcript is only filler words',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.pump();
      fakeStt.emitTranscript("alors ca c'est OK");
      await tester.pumpAndSettle();

      // No name should be captured — camera prompt without "Enchantée"
      expect(fakeTts.lastSpokenText, contains('caméra'));
      expect(fakeTts.lastSpokenText, isNot(contains('Enchantée')));
    });

    testWidgets('extracts name from "je m\'appelle Marie"', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.pump();
      fakeStt.emitTranscript("je m'appelle Marie");
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('Enchantée Marie'));
    });

    testWidgets('extracts name from "bonjour moi c\'est Thomas"',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.pump();
      fakeStt.emitTranscript("bonjour moi c'est Thomas");
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('Enchantée Thomas'));
    });

    testWidgets('extracts simple one-word name "Marie"', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.pump();
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('Enchantée Marie'));
    });
  });

  group('ShellOnboarding camera permission', () {
    Future<void> advanceToCameraStep(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.pump();
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();
    }

    testWidgets('asks camera permission with personalized greeting',
        (tester) async {
      await advanceToCameraStep(tester);

      expect(fakeTts.lastSpokenText, contains('Enchantée Marie'));
      expect(fakeTts.lastSpokenText, contains('caméra'));
    });

    testWidgets('requests camera from OS when user says oui', (tester) async {
      await advanceToCameraStep(tester);

      // TTS completion -> STT starts
      await tester.pump();
      fakeStt.emitTranscript('oui');
      await tester.pumpAndSettle();

      expect(fakePermissions.requestedPermissions,
          contains(KitaPermission.camera));
    });

    testWidgets('advances without camera when user declines', (tester) async {
      await advanceToCameraStep(tester);

      // TTS completion -> STT starts
      await tester.pump();
      fakeStt.emitTranscript('non merci');
      await tester.pumpAndSettle();

      // Should speak "pas de souci"
      expect(fakeTts.spokenTexts, anyElement(contains('Pas de souci')));

      // Wait for delayed advance
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Should have advanced to magic moment
      expect(fakeTts.lastSpokenText, contains('décris'));
    });
  });

  group('ShellOnboarding magic moment', () {
    Future<void> advanceToMagicStep(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      // Greeting: say name
      await tester.pump();
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();
      // Camera: accept
      await tester.pump();
      fakeStt.emitTranscript('oui');
      await tester.pumpAndSettle();
    }

    testWidgets('speaks magic moment invitation', (tester) async {
      await advanceToMagicStep(tester);

      expect(fakeTts.lastSpokenText, contains('décris'));
    });

    testWidgets('shows processing state when user says decris', (tester) async {
      await advanceToMagicStep(tester);

      // TTS completion -> STT starts for magic moment
      await tester.pump();
      fakeStt.emitTranscript('decris');
      await tester.pump();

      // Should show processing message
      expect(find.textContaining('regarde'), findsOneWidget);

      // Pump through the delayed futures to avoid pending timer errors
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('ShellOnboarding completion', () {
    testWidgets('completes after full voice flow', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Greeting
      await tester.pump();
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();

      // Camera
      await tester.pump();
      fakeStt.emitTranscript('oui');
      await tester.pumpAndSettle();

      // Magic moment -> say decris
      await tester.pump();
      fakeStt.emitTranscript('decris');
      await tester.pumpAndSettle();

      // Wait for completion delays (2s + 2s)
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // After completion, the widget should render SizedBox.shrink
      expect(find.byKey(const Key('onboarding_status')), findsNothing);
    });
  });

  group('ShellOnboarding fallback buttons', () {
    testWidgets('shows continue and skip buttons', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_continue')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);
    });

    testWidgets('continue button advances from greeting to camera',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('caméra'));
    });

    testWidgets('skip button advances from greeting to camera', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('caméra'));
    });

    testWidgets('skip button on camera step goes to magic moment',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Skip greeting
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      // Skip camera
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('décris'));
    });

    testWidgets('skip on magic moment completes onboarding', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Skip greeting
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      // Skip camera
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      // Skip magic moment
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      // Should be complete — no more onboarding UI
      expect(find.byKey(const Key('onboarding_continue')), findsNothing);
      expect(find.byKey(const Key('onboarding_skip')), findsNothing);
    });

    testWidgets('full button-only flow works without STT', (tester) async {
      await tester.pumpWidget(buildTestApp(sttAvailable: false));
      await tester.pumpAndSettle();

      // Process TTS completion -> STT unavailable
      await tester.pump();

      // Continue through greeting
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('caméra'));

      // Continue through camera
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      // Continue through magic moment (triggers describe)
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      // Wait for completion delays (2s + 2s)
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_continue')), findsNothing);
    });

    testWidgets('touch targets meet minimum size', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final continueButton = find.byKey(const Key('onboarding_continue'));
      final skipButton = find.byKey(const Key('onboarding_skip'));

      final continueSize = tester.getSize(continueButton);
      final skipSize = tester.getSize(skipButton);

      expect(continueSize.height, greaterThanOrEqualTo(48));
      expect(skipSize.height, greaterThanOrEqualTo(48));
    });
  });

  group('ShellOnboarding accessibility', () {
    testWidgets('status message has liveRegion semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.liveRegion == true),
        findsWidgets,
      );

      handle.dispose();
    });

    testWidgets('buttons have semantic labels', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify the explicit Semantics wrapper has the label
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Continuer'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label != null &&
            w.properties.label!.contains('Passer')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('ShellOnboarding AI probe race condition', () {
    testWidgets('probe waits for Gemma warmup before sending request',
        (tester) async {
      // Gemma starts in loading state, simulating warmup in progress.
      fakeGemmaBridge.status = GemmaModelStatus.loading;
      fakeAIRouter.hasProviders = true;
      fakeAIRouter.probeResponse = 'Bonjour';

      await tester.pumpWidget(buildTestApp(aiAvailable: true));

      // The probe is running but Gemma is still loading.
      // No route call should have been made yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeAIRouter.routeCallCount, 0);

      // Simulate Gemma finishing warmup after ~1s.
      fakeGemmaBridge.status = GemmaModelStatus.ready;

      // Pump past the 500ms poll interval so the probe picks up the ready state.
      await tester.pump(const Duration(milliseconds: 600));
      // Allow the route Future to complete.
      await tester.pump(const Duration(milliseconds: 100));

      // Now the probe should have called aiRouter.route().
      expect(fakeAIRouter.routeCallCount, greaterThan(0));
    });

    testWidgets('probe aborts when Gemma is in error state', (tester) async {
      fakeGemmaBridge.status = GemmaModelStatus.error;
      fakeAIRouter.hasProviders = true;

      await tester.pumpWidget(buildTestApp(aiAvailable: true));
      await tester.pumpAndSettle();

      // Probe should have aborted without calling route.
      expect(fakeAIRouter.routeCallCount, 0);
    });

    testWidgets('probe skips when Gemma warmup times out', (tester) async {
      // Gemma stays in loading state forever — simulates a stalled warmup.
      fakeGemmaBridge.status = GemmaModelStatus.loading;
      fakeAIRouter.hasProviders = true;

      await tester.pumpWidget(buildTestApp(aiAvailable: true));

      // Pump past the 20s probe timeout (poll every 500ms × 40 = 20s).
      // Add extra pumps to clear pending timers from the poll loop.
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Also pump through STT timeouts (8s default) that may be running.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Probe should NOT have sent a route request since Gemma never became ready.
      expect(fakeAIRouter.routeCallCount, 0);
    });
  });

  group('ShellOnboarding progression watchdog', () {
    testWidgets(
        'advances to the camera step even when TTS never emits completed',
        (tester) async {
      // Simulate a TTS engine that speaks but never signals completion.
      fakeTts.emitCompletion = false;

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Without any `completed` event, progress can only come from the
      // watchdog timers (mic-announce timeout + greeting watchdog) and the STT
      // listen timeout. Pump well past all of them.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // The greeting watchdog started STT; the silent STT timed out; the flow
      // reached the camera step — all without a single completion event.
      expect(
        fakeTts.spokenTexts.any((t) => t.contains('caméra')),
        isTrue,
        reason: 'watchdog + STT timeout should advance to the camera step',
      );
    });
  });

  group('ShellOnboarding microphone refused', () {
    testWidgets('announces the button fallback and stays navigable',
        (tester) async {
      fakePermissions.statusToReturn = PermissionRequestStatus.denied;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // The mic-refused message is spoken (TTS works without the mic).
      expect(
        fakeTts.spokenTexts.any((t) => t.contains('pas accès au micro')),
        isTrue,
      );
      // STT is never started in button-only mode.
      expect(fakeStt.isListening, isFalse);
      // The fallback buttons remain available to drive the flow.
      expect(find.byKey(const Key('onboarding_continue')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);
    });

    testWidgets('button navigation still advances when mic is refused',
        (tester) async {
      fakePermissions.statusToReturn = PermissionRequestStatus.denied;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Advance via the button; the camera prompt is spoken (speak-only).
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      expect(
        fakeTts.spokenTexts.any((t) => t.contains('caméra')),
        isTrue,
      );
      // Still no STT even after advancing.
      expect(fakeStt.isListening, isFalse);
    });
  });

  group('ShellOnboarding silent STT', () {
    testWidgets('advances via onTimeout when STT returns no result',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Greeting finished, STT is listening for the name.
      expect(fakeStt.isListening, isTrue);

      // User stays silent — the 8s listen timer must fire onTimeout.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      // onTimeout advanced to the camera step.
      expect(fakeTts.lastSpokenText, contains('caméra'));
    });
  });

  group('ShellOnboarding persistence', () {
    testWidgets('skips onboarding and stays silent when a profile exists',
        (tester) async {
      // Seed a real profile row — the returning-user check must find it via
      // the real repository.
      await ProfileDao(db).insert(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Returning user: no speech at all, onboarding UI gone.
      expect(fakeTts.spokenTexts, isEmpty);
      expect(find.byKey(const Key('onboarding_continue')), findsNothing);
      expect(find.byKey(const Key('onboarding_status')), findsNothing);
    });

    testWidgets('persists a real active profile on completion',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // No profile yet — first run.
      expect((await ProfileDao(db).getActive()).getOrNull(), isNull);

      // Button-only path to completion: skip greeting, camera, magic moment.
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      // Completion persisted a real active profile row (returning-user marker).
      final saved = (await ProfileDao(db).getActive()).getOrNull();
      expect(saved, isNotNull);
      expect(saved!.accessibilityProfile, 'general');
    });
  });
}

// ---------------------------------------------------------------------------
// Fake services
// ---------------------------------------------------------------------------

class _FakePermissionRequester implements PermissionRequester {
  final List<KitaPermission> requestedPermissions = [];

  /// Status returned by [request] — tests set this to simulate a refusal.
  PermissionRequestStatus statusToReturn = PermissionRequestStatus.granted;

  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    requestedPermissions.add(permission);
    return statusToReturn;
  }

  @override
  Future<void> openSettings() async {}
}

class _FakeTTSService implements TTSService {
  bool _isSpeaking = false;
  String? lastSpokenText;
  final List<String> spokenTexts = [];

  /// When false, the fake never emits `completed` events — simulates a TTS
  /// engine that speaks but never signals completion (watchdog test).
  bool emitCompletion = true;
  final _controller = StreamController<TtsSpeechEvent>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _controller.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    lastSpokenText = text;
    spokenTexts.add(text);
    _isSpeaking = true;
    unawaited(Future.microtask(() {
      _isSpeaking = false;
      if (emitCompletion && !_controller.isClosed) {
        _controller.add(TtsSpeechEvent.completed(text: text));
      }
    }));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _isSpeaking = false;
    return const Result.success(null);
  }

  void dispose() => _controller.close();
}

class _FakeSTTService implements STTService {
  STTResultCallback? _pendingCallback;
  bool shouldFail = false;
  bool _isListening = false;

  @override
  bool get isAvailable => !shouldFail;

  @override
  bool get isListening => _isListening;

  @override
  Future<Result<void>> startRecognition({
    required STTResultCallback onResult,
  }) async {
    if (shouldFail) {
      return const Result.failure(
        UnexpectedFailure(logMessage: 'STT unavailable'),
      );
    }
    _isListening = true;
    _pendingCallback = onResult;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopRecognition() async {
    _isListening = false;
    _pendingCallback = null;
    return const Result.success(null);
  }

  void emitTranscript(String text) {
    _pendingCallback?.call(text, true);
  }
}

class _FakeAIRouter implements AIRouter {
  bool hasProviders = false;
  int routeCallCount = 0;
  String? probeResponse;

  @override
  List<AIProvider> get availableProviders =>
      hasProviders ? [_FakeAIProvider()] : [];

  @override
  Future<Result<AIResponse>> route(AIRequest request) async {
    routeCallCount++;
    return Result.success(AIResponse(
      content: probeResponse ?? '',
      meta: const AIResponseMeta(
        providerId: 'fake',
        latency: Duration.zero,
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> routeStream(AIRequest request) async* {
    // Empty stream — onboarding falls back to non-streaming path.
  }

  @override
  Stream<String> routeVisionStream(ImageData image, String prompt,
      {int? maxTokens}) async* {
    yield 'Vision response';
  }

  @override
  Future<Result<AIToolResponse>> routeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    return const Result.success(AIToolResponse(
      text: 'Fake tool response',
      meta: AIResponseMeta(
        providerId: 'fake',
        latency: Duration.zero,
        tier: ProviderTier.local,
      ),
    ));
  }
}

class _FakeAIProvider implements AIProvider {
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  ProviderTier get tier => ProviderTier.local;
  @override
  bool get isAvailable => true;
  @override
  Future<Result<AIResponse>> complete(AIRequest request) async =>
      throw UnimplementedError();
  @override
  Stream<String> completeStream(AIRequest request) => throw UnimplementedError();
  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt,
          {int? maxTokens}) async =>
      throw UnimplementedError();
  @override
  Stream<String> visionStream(ImageData image, String prompt,
          {int? maxTokens}) =>
      throw UnimplementedError();
  @override
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async =>
      throw UnimplementedError();
  @override
  Future<Result<void>> validateApiKey(String key) async =>
      throw UnimplementedError();
}

class _FakeGemmaBridge implements GemmaBridge {
  GemmaModelStatus status = GemmaModelStatus.ready;

  @override
  Future<GemmaModelStatus> checkStatus() async => status;

  @override
  Future<void> warmUp() async {}

  @override
  Future<GemmaCompletionResult> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    return const GemmaCompletionResult(text: '');
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async* {}

  @override
  Future<GemmaVisionResult> describeImage(
    Uint8List bytes, {
    String? prompt,
  }) async {
    return const GemmaVisionResult(description: '');
  }

  @override
  Stream<String> describeImageStream(
    Uint8List bytes, {
    String? prompt,
  }) async* {}

  @override
  Future<void> dispose() async {}
}
