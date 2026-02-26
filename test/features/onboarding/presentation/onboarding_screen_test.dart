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
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kita/features/onboarding/presentation/profile_selector.dart';

/// Builds the onboarding screen wrapped with required providers.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      // Override detectedProfileProvider with a synchronous value
      detectedProfileProvider.overrideWith(
        (ref) => Stream.value(DetectedProfile.general),
      ),
      // Provide fake permission requester so early mic request doesn't
      // hit platform channels in tests.
      permissionRequesterProvider
          .overrideWithValue(_FakePermissionRequester()),
    ],
    child: const MaterialApp(
      home: OnboardingScreen(),
    ),
  );
}

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows welcome step with greeting text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Bonjour, je suis Kita.'), findsOneWidget);
      // Mic button for voice-first name capture
      expect(find.byKey(const Key('mic_name')), findsOneWidget);
      // Skip button for bypassing name entry
      expect(find.byKey(const Key('skip_name')), findsOneWidget);
    });

    testWidgets('welcome step has name input field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name_input')), findsOneWidget);
      expect(find.text('Ou tape ton prénom'), findsOneWidget);
    });

    testWidgets('welcome step has continue button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('continue_welcome'));
      expect(button, findsOneWidget);
    });

    testWidgets('continue button navigates to mode choice step',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();

      // Should show mode choice ("Pour moi" / "Pour quelqu'un d'autre")
      expect(find.text('Pour qui ?'), findsOneWidget);
      expect(find.byKey(const Key('mode_for_me')), findsOneWidget);
      expect(find.byKey(const Key('mode_for_other')), findsOneWidget);
    });

    testWidgets('name can be entered before continuing', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();

      // Mode choice step should be visible
      expect(find.text('Pour qui ?'), findsOneWidget);
    });

    testWidgets('pour moi navigates to profile step', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to mode choice
      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();

      // Choose "Pour moi"
      await tester.tap(find.byKey(const Key('mode_for_me')));
      await tester.pumpAndSettle();

      expect(find.text('Choisis ton profil'), findsOneWidget);
    });

    testWidgets('profile step shows all profile options', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to mode choice then profile
      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode_for_me')));
      await tester.pumpAndSettle();

      expect(find.text('Aveugle'), findsOneWidget);
      expect(find.text('Malvoyant'), findsOneWidget);
      expect(find.text('Général'), findsOneWidget);
    });

    testWidgets('touch targets meet minimum size requirements',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('continue_welcome'));
      final buttonSize = tester.getSize(button);
      expect(buttonSize.height, greaterThanOrEqualTo(48));
    });
  });

  group('OnboardingScreen Semantics', () {
    testWidgets('welcome step has semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find the greeting header
      expect(
        find.bySemanticsLabel(RegExp('Bonjour')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('name input has accessible label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The text field should have a semantic label
      final textField = find.byKey(const Key('name_input'));
      expect(textField, findsOneWidget);

      // Check that there's a Semantics ancestor with the label
      expect(
        find.bySemanticsLabel(RegExp('prénom')),
        findsWidgets,
      );

      handle.dispose();
    });

    testWidgets('profile options have semantic labels', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to mode choice then profile step
      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode_for_me')));
      await tester.pumpAndSettle();

      // Each profile option should have an accessible label
      expect(
        find.bySemanticsLabel(RegExp('Profil aveugle')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Profil malvoyant')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Profil général')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('ProfileSelector', () {
    testWidgets('renders all options', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProfileSelector(
            selectedProfile: AccessibilityProfile.general,
            onProfileSelected: (_) {},
          ),
        ),
      ));

      expect(find.text('Aveugle'), findsOneWidget);
      expect(find.text('Malvoyant'), findsOneWidget);
      expect(find.text('Général'), findsOneWidget);
    });

    testWidgets('pre-selects the given profile', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProfileSelector(
            selectedProfile: AccessibilityProfile.blind,
            onProfileSelected: (_) {},
          ),
        ),
      ));

      // Check icon is displayed for selection
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('calls onProfileSelected when option tapped', (tester) async {
      AccessibilityProfile? selected;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProfileSelector(
            selectedProfile: AccessibilityProfile.general,
            onProfileSelected: (p) => selected = p,
          ),
        ),
      ));

      await tester.tap(find.text('Aveugle'));
      expect(selected, AccessibilityProfile.blind);
    });

    testWidgets('each option meets touch target size', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProfileSelector(
            selectedProfile: AccessibilityProfile.general,
            onProfileSelected: (_) {},
          ),
        ),
      ));

      // Find InkWell widgets (the tappable areas)
      final inkWells = find.byType(InkWell);
      expect(inkWells, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        final size = tester.getSize(inkWells.at(i));
        expect(size.height, greaterThanOrEqualTo(56),
            reason: 'Option $i height should be >= 56px');
      }
    });
  });

  group('OnboardingNotifier', () {
    test('initial state is detecting when no profile available', () {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => const Stream<DetectedProfile>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.detecting);
    });

    test('state moves to welcome when profile detected', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Listen to trigger the stream subscription
      container.listen(detectedProfileProvider, (_, __) {});

      // Wait for Stream.value() microtask to emit
      await Future<void>.delayed(Duration.zero);

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.welcome);
    });

    test('completeWelcome transitions to modeChoice step', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.completeWelcome();

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.modeChoice);
    });

    test('chooseStandardMode transitions to profile step', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.completeWelcome();
      notifier.chooseStandardMode();

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.profile);
      expect(state.isCaregiverMode, isFalse);
    });

    test('chooseCaregiverMode transitions to caregiver step', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.completeWelcome();
      notifier.chooseCaregiverMode();

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.caregiver);
      expect(state.isCaregiverMode, isTrue);
    });

    test('completeCaregiverOnboarding marks as complete with caregiver flag',
        () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.completeCaregiverOnboarding();

      final state = container.read(onboardingNotifierProvider);
      expect(state.step, OnboardingStep.complete);
      expect(state.onboardingComplete, isTrue);
      expect(state.isConfiguredByCaregiver, isTrue);

      final isComplete = container.read(onboardingCompleteProvider);
      expect(isComplete, isTrue);
    });

    test('setUserName stores name in state', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.setUserName('Marie');

      final state = container.read(onboardingNotifierProvider);
      expect(state.userName, 'Marie');
    });

    test('completeOnboarding marks onboarding complete', () async {
      final container = ProviderContainer(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(detectedProfileProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      notifier.completeOnboarding();

      final isComplete = container.read(onboardingCompleteProvider);
      expect(isComplete, isTrue);
    });
  });

  group('Voice flow', () {
    late _FakeTTSService fakeTts;
    late _FakeSTTService fakeStt;

    setUp(() {
      fakeTts = _FakeTTSService();
      fakeStt = _FakeSTTService();
    });

    tearDown(() {
      fakeTts.dispose();
    });

    Widget buildVoiceTestApp() {
      return ProviderScope(
        overrides: [
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
          ttsServiceProvider.overrideWithValue(fakeTts),
          sttServiceProvider.overrideWithValue(fakeStt),
          permissionRequesterProvider
              .overrideWithValue(_FakePermissionRequester()),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
    }

    testWidgets('voice flow speaks welcome greeting', (tester) async {
      await tester.pumpWidget(buildVoiceTestApp());
      await tester.pumpAndSettle();

      // Voice flow should have spoken the greeting
      expect(fakeTts.lastSpokenText, contains('Bonjour'));
      expect(fakeTts.lastSpokenText, contains('prénom'));
    });

    testWidgets('voice flow: user says name -> advances to mode choice',
        (tester) async {
      await tester.pumpWidget(buildVoiceTestApp());
      await tester.pumpAndSettle();

      // TTS spoke greeting; process TTS completion -> STT starts
      await tester.pump();

      expect(fakeStt.isListening, isTrue);

      // Simulate user saying "Marie"
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();

      // Should have advanced to mode choice
      expect(find.text('Pour qui ?'), findsOneWidget);
    });

    testWidgets('voice flow: user says "passer" -> skips name',
        (tester) async {
      await tester.pumpWidget(buildVoiceTestApp());
      await tester.pumpAndSettle();

      // Process TTS completion -> STT starts
      await tester.pump();

      // Simulate user saying "passer"
      fakeStt.emitTranscript('passer');
      await tester.pumpAndSettle();

      // Should have advanced to mode choice (no name set)
      expect(find.text('Pour qui ?'), findsOneWidget);
    });

    testWidgets(
        'voice flow: mode choice -> user says "pour moi" -> advances to profile',
        (tester) async {
      await tester.pumpWidget(buildVoiceTestApp());
      await tester.pumpAndSettle();

      // Welcome: TTS completion -> STT -> user says name
      await tester.pump();
      fakeStt.emitTranscript('Marie');
      await tester.pumpAndSettle();

      // Mode choice: TTS completion -> STT -> user says "pour moi"
      await tester.pump();
      expect(fakeStt.isListening, isTrue);
      fakeStt.emitTranscript('pour moi');
      await tester.pumpAndSettle();

      // Should show profile selection
      expect(find.text('Choisis ton profil'), findsOneWidget);
    });

    testWidgets('buttons still work when voice flow is inactive',
        (tester) async {
      // Disable STT to force buttons-only mode
      fakeStt.shouldFail = true;
      await tester.pumpWidget(buildVoiceTestApp());
      await tester.pumpAndSettle();

      // Process TTS completion -> STT unavailable -> fallback to buttons
      await tester.pump();

      // Tap continue button (buttons fallback)
      await tester.tap(find.byKey(const Key('continue_welcome')));
      await tester.pumpAndSettle();

      expect(find.text('Pour qui ?'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake services for voice flow testing
// ---------------------------------------------------------------------------

/// Fake permission requester that always grants — avoids platform channels.
class _FakePermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

/// Fake TTS that emits [completed] events after each speak call,
/// enabling the voice flow's speak-then-listen pattern in tests.
class _FakeTTSService implements TTSService {
  bool _isSpeaking = false;
  String? lastSpokenText;
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
    _isSpeaking = true;
    // Emit completed event on next microtask so listeners are ready
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

/// Fake STT that allows manual transcript emission for controlled testing.
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

  /// Simulate receiving a final transcript from the user.
  void emitTranscript(String text) {
    _pendingCallback?.call(text, true);
  }
}
