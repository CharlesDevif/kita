import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/data/providers/stt_providers.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/stt_service.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/shell/presentation/shell_onboarding.dart';

void main() {
  late _FakeTTSService fakeTts;
  late _FakeSTTService fakeStt;
  late _FakePermissionRequester fakePermissions;

  setUp(() {
    fakeTts = _FakeTTSService();
    fakeStt = _FakeSTTService();
    fakePermissions = _FakePermissionRequester();
  });

  tearDown(() {
    fakeTts.dispose();
  });

  Widget buildTestApp({bool sttAvailable = true}) {
    fakeStt.shouldFail = !sttAvailable;

    return ProviderScope(
      overrides: [
        detectedProfileProvider.overrideWith(
          (ref) => Stream.value(DetectedProfile.general),
        ),
        ttsServiceProvider.overrideWithValue(fakeTts),
        sttServiceProvider.overrideWithValue(fakeStt),
        permissionRequesterProvider.overrideWithValue(fakePermissions),
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
      expect(fakeTts.lastSpokenText, contains('camera'));
      expect(fakeTts.lastSpokenText, contains('Enchantee Marie'));
    });

    testWidgets('skips name on voice "passer"', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // TTS completion -> STT starts
      await tester.pump();
      fakeStt.emitTranscript('passer');
      await tester.pumpAndSettle();

      // Should advance to camera permission without name
      expect(fakeTts.lastSpokenText, contains('camera'));
      expect(fakeTts.lastSpokenText, isNot(contains('Marie')));
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

      expect(fakeTts.lastSpokenText, contains('Enchantee Marie'));
      expect(fakeTts.lastSpokenText, contains('camera'));
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
      expect(fakeTts.lastSpokenText, contains('decris'));
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

      expect(fakeTts.lastSpokenText, contains('decris'));
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

      // Wait for completion delays
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

      expect(fakeTts.lastSpokenText, contains('camera'));
    });

    testWidgets('skip button advances from greeting to camera', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();

      expect(fakeTts.lastSpokenText, contains('camera'));
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

      expect(fakeTts.lastSpokenText, contains('decris'));
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

      expect(fakeTts.lastSpokenText, contains('camera'));

      // Continue through camera
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      // Continue through magic moment (triggers describe)
      await tester.tap(find.byKey(const Key('onboarding_continue')));
      await tester.pumpAndSettle();

      // Wait for completion
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
}

// ---------------------------------------------------------------------------
// Fake services
// ---------------------------------------------------------------------------

class _FakePermissionRequester implements PermissionRequester {
  final List<KitaPermission> requestedPermissions = [];

  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    requestedPermissions.add(permission);
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

class _FakeTTSService implements TTSService {
  bool _isSpeaking = false;
  String? lastSpokenText;
  final List<String> spokenTexts = [];
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
      if (!_controller.isClosed) {
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
