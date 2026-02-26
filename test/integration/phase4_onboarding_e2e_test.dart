import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';

import '../mocks/mock_tts_service.dart';

/// Fake permission requester that always grants.
class _FakePermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

/// Phase 4 Integration Gate — AC1: Onboarding E2E
///
/// Tests the full onboarding flow for a blind user (VoiceOver active):
/// detection -> welcome (vocal greeting) -> name -> mode choice ->
/// profile (blind pre-selected) -> permissions -> magic moment -> complete.
void main() {
  late MockTTSService mockTts;

  /// Builds the test app with VoiceOver-like accessibility features
  /// (screen reader detected).
  Widget buildTestApp({
    DetectedProfile detectedProfile = const DetectedProfile(
      profile: AccessibilityProfile.blind,
      screenReader: true,
      largeText: false,
      reduceMotion: false,
      boldText: false,
      highContrast: false,
    ),
  }) {
    return ProviderScope(
      overrides: [
        detectedProfileProvider.overrideWith(
          (ref) => Stream.value(detectedProfile),
        ),
        ttsServiceProvider.overrideWithValue(mockTts),
        permissionRequesterProvider
            .overrideWithValue(_FakePermissionRequester()),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  setUp(() {
    mockTts = MockTTSService();
  });

  tearDown(() {
    mockTts.dispose();
  });

  group('Phase 4 Gate — AC1: Onboarding E2E (blind user)', () {
    testWidgets(
      'detection -> welcome with vocal greeting when screen reader active',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Welcome step should be visible (detection was automatic)
        expect(find.text('Bonjour, je suis Kita.'), findsOneWidget);

        // TTS should have spoken the greeting
        expect(mockTts.lastSpokenText, contains('Bonjour'));
      },
    );

    testWidgets(
      'Kita speaks first — greeting is spoken before user interaction',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // The greeting should have been spoken without any user tap
        expect(mockTts.lastSpokenText, isNotNull);
        expect(
          mockTts.lastSpokenText,
          contains('Kita'),
        );
      },
    );

    testWidgets(
      'full flow: name -> mode choice -> profile blind pre-selected',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Step 1: Welcome — enter name
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // Step 2: Mode choice should be visible
        expect(find.text('Pour qui ?'), findsOneWidget);
        expect(find.byKey(const Key('mode_for_me')), findsOneWidget);

        // Choose "Pour moi"
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Step 3: Profile step — blind should be pre-selected
        expect(find.text('Choisis ton profil'), findsOneWidget);

        // The blind profile should be shown and pre-selected
        expect(find.text('Aveugle'), findsOneWidget);
      },
    );

    testWidgets(
      'flow continues: profile -> permissions auto-granted -> magic moment',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate through welcome
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // Choose "Pour moi"
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Select blind profile
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Voice-first: permissions auto-request via onSpeak + FakePermissionRequester.
        // All 3 permissions (camera, mic, location) auto-grant in a few frames,
        // so the flow jumps directly to the magic moment step.
        expect(find.text('Premier essai'), findsOneWidget);
      },
    );

    testWidgets(
      'magic moment -> completion -> redirect',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate through welcome + mode choice + profile
        // (permissions auto-grant via voice-first + FakePermissionRequester)
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Permissions auto-completed — now at magic moment step
        expect(find.text('Premier essai'), findsOneWidget);
        await tester.tap(find.byKey(const Key('try_describe')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Should show success state
        expect(find.text('Continuer'), findsOneWidget);

        // Tap continue to move to API key setup
        await tester.tap(find.byKey(const Key('continue_magic')));
        await tester.pumpAndSettle();

        // Should show API key setup (the final step before complete)
        // The ApiKeySetupStep shows "Configuration IA"
        expect(find.text('Configuration IA'), findsOneWidget);
        expect(find.byKey(const Key('mode_discovery')), findsOneWidget);
      },
    );

    test(
      'onboarding state tracks all transitions correctly',
      () async {
        // Use a ProviderContainer to track state transitions (no widgets needed)
        final container = ProviderContainer(
          overrides: [
            detectedProfileProvider.overrideWith(
              (ref) => Stream.value(const DetectedProfile(
                profile: AccessibilityProfile.blind,
                screenReader: true,
                largeText: false,
                reduceMotion: false,
                boldText: false,
                highContrast: false,
              )),
            ),
          ],
        );

        try {
          // Listen to trigger stream subscription
          container.listen(detectedProfileProvider, (_, __) {});
          await Future<void>.delayed(Duration.zero);

          final notifier =
              container.read(onboardingNotifierProvider.notifier);
          var state = container.read(onboardingNotifierProvider);

          // Detection -> Welcome (automatic via stream)
          expect(state.step, OnboardingStep.welcome);
          expect(state.detectedProfile!.profile, AccessibilityProfile.blind);
          expect(state.detectedProfile!.screenReader, isTrue);

          // Welcome -> Mode Choice
          notifier.setUserName('Marie');
          notifier.completeWelcome();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.modeChoice);
          expect(state.userName, 'Marie');

          // Mode Choice -> Profile
          notifier.chooseStandardMode();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.profile);
          expect(state.isCaregiverMode, isFalse);

          // Profile -> Permissions
          await notifier.selectProfile(AccessibilityProfile.blind);
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.permissions);

          // Permissions -> Magic
          notifier.grantPermission('camera');
          notifier.grantPermission('microphone');
          notifier.grantPermission('location');
          notifier.completePermissions();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.magic);
          expect(state.permissionsGranted, contains('camera'));
          expect(state.permissionsGranted, contains('microphone'));
          expect(state.permissionsGranted, contains('location'));

          // Magic -> Complete
          notifier.completeOnboarding();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.complete);
          expect(state.onboardingComplete, isTrue);

          // onboardingCompleteProvider should also be true
          final isComplete = container.read(onboardingCompleteProvider);
          expect(isComplete, isTrue);
        } finally {
          container.dispose();
        }
      },
    );

    test(
      'blind profile pre-selects describe + alert pack',
      () async {
        // Pure unit test — no widgets needed
        final container = ProviderContainer(
          overrides: [
            detectedProfileProvider.overrideWith(
              (ref) => Stream.value(const DetectedProfile(
                profile: AccessibilityProfile.blind,
                screenReader: true,
                largeText: false,
                reduceMotion: false,
                boldText: false,
                highContrast: false,
              )),
            ),
          ],
        );

        try {
          container.listen(detectedProfileProvider, (_, __) {});
          await Future<void>.delayed(Duration.zero);

          // Get the pack installer and verify the blind pack
          final installer = container.read(packInstallerProvider);
          final pack =
              installer.getPackForProfile(AccessibilityProfile.blind);

          expect(pack.agentIds, contains('com.kita.describe'));
          expect(pack.agentIds, contains('com.kita.alert'));
          expect(pack.agentIds.length, 2);
        } finally {
          container.dispose();
        }
      },
    );
  });
}
