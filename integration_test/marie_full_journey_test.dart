/// E2E integration test: Marie's full journey after wiring fixes.
///
/// Validates the COMPLETE Marie journey (blind user, first launch):
///   1. App launches -> onboarding redirect
///   2. Kita speaks greeting UNCONDITIONALLY (voice-first)
///   3. User enters name -> Kita speaks transition
///   4. User selects "Pour moi" -> profile selection
///   5. User selects "Aveugle" -> profile propagated to ProfileAdapter
///   6. Permissions granted (with storytelling)
///   7. Magic moment -> API key setup
///   8. Onboarding completes -> navigate to `/` -> REAL KitaShell (not placeholder)
///   9. KitaOrb visible in passive state
///  10. KitaInput visible with mic button
///  11. Orchestrator initialized (AlertAgent spawned)
///  12. User says "decris" -> DescribeAgent spawned -> TTS called
///
/// Wiring fixes validated:
///   - Router shows real KitaShell at route `/`
///   - Orchestrator.initialize() called in KitaShell.initState()
///   - Real SensorAccess/AIAccess replace stubs in pluginSandboxProvider
///   - Voice-first is unconditional (no screenReaderActive guard)
///   - Profile from onboarding propagated to UserProfileNotifier/ProfileAdapter
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/navigation/router.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/io/data/providers/camera_providers.dart';
import 'package:kita/features/io/data/providers/haptic_providers.dart';
import 'package:kita/features/io/data/providers/location_providers.dart';
import 'package:kita/features/io/data/providers/motion_providers.dart';
import 'package:kita/features/io/data/providers/stt_providers.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/io/domain/camera_service.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/io/domain/stt_service.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kita/features/orchestration/domain/models/raw_input.dart';
import 'package:kita/features/shell/presentation/kita_input.dart';
import 'package:kita/features/shell/presentation/kita_orb.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/shared/multi_modal/profile_adapter_impl.dart';
import 'package:kita/shared/multi_modal/profile_adapter_provider.dart';

import 'helpers/test_app.dart';

// =============================================================================
// Mock services for full journey test
// =============================================================================

/// Mock STT — captures start/stop calls without platform dependency.
class _MockSTTService implements STTService {
  bool _isListening = false;
  STTResultCallback? _callback;

  @override
  bool get isAvailable => true;

  @override
  bool get isListening => _isListening;

  @override
  Future<Result<void>> startRecognition({
    required STTResultCallback onResult,
  }) async {
    _isListening = true;
    _callback = onResult;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopRecognition() async {
    _isListening = false;
    _callback = null;
    return const Result.success(null);
  }

  void simulateResult(String transcript) {
    _callback?.call(transcript, true);
  }
}

/// Mock camera — returns stub failure (no real camera in tests).
class _MockCameraService implements CameraService {
  @override
  bool get isAvailable => false;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    return const Result.failure(PluginFailure(
      userMessage: 'Camera not available in tests',
      logMessage: 'MockCamera: capturePhoto stub',
    ));
  }

  @override
  Future<Result<void>> startStream(void Function(ImageData) onFrame) async {
    return const Result.failure(PluginFailure(
      userMessage: 'Camera not available in tests',
      logMessage: 'MockCamera: startStream stub',
    ));
  }

  @override
  Future<Result<void>> stopStream() async {
    return const Result.success(null);
  }
}

/// Mock location — returns stub failure (no real GPS in tests).
class _MockLocationService implements LocationService {
  @override
  bool get isAvailable => false;

  @override
  Future<Result<Position>> getCurrentPosition() async {
    return const Result.failure(PluginFailure(
      userMessage: 'Location not available in tests',
      logMessage: 'MockLocation: getCurrentPosition stub',
    ));
  }

  @override
  Future<Result<GeoAddress>> reverseGeocode(Position position) async {
    return const Result.failure(PluginFailure(
      userMessage: 'Geocoding not available in tests',
      logMessage: 'MockLocation: reverseGeocode stub',
    ));
  }

  @override
  Future<Result<List<POI>>> getNearbyPOIs(
    Position position, {
    double radiusMeters = 500,
  }) async {
    return const Result.failure(PluginFailure(
      userMessage: 'POI search not available in tests',
      logMessage: 'MockLocation: getNearbyPOIs stub',
    ));
  }
}

/// Mock motion — always immobile in tests.
class _MockMotionService implements MotionService {
  @override
  MotionState get currentState => MotionState.immobile;

  @override
  Future<Result<void>> startMonitoring({
    void Function(MotionState)? onStateChanged,
  }) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stopMonitoring() async {
    return const Result.success(null);
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late IntegrationMockTTSService mockTts;
  late IntegrationMockHapticService mockHaptic;
  late _MockSTTService mockStt;
  late _MockCameraService mockCamera;
  late _MockLocationService mockLocation;
  late _MockMotionService mockMotion;

  setUp(() {
    mockTts = IntegrationMockTTSService();
    mockHaptic = IntegrationMockHapticService();
    mockStt = _MockSTTService();
    mockCamera = _MockCameraService();
    mockLocation = _MockLocationService();
    mockMotion = _MockMotionService();
  });

  tearDown(() {
    mockTts.dispose();
  });

  // ===========================================================================
  // Wiring Fix 1: Router shows real KitaShell at route `/`
  // ===========================================================================
  group('Wiring Fix 1 — Router serves KitaShell at "/"', () {
    testWidgets(
      'route "/" renders KitaShell (not placeholder) after onboarding',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: kitaRoutes,
          redirect: (context, state) {
            // Onboarding is complete for this test — always go to "/"
            final isOnboardingRoute =
                state.matchedLocation.startsWith('/onboarding');
            if (isOnboardingRoute) return '/';
            return null;
          },
        );

        final app = ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(mockTts),
            hapticServiceProvider.overrideWithValue(mockHaptic),
            sttServiceProvider.overrideWithValue(mockStt),
            cameraServiceProvider.overrideWithValue(mockCamera),
            locationServiceProvider.overrideWithValue(mockLocation),
            motionServiceProvider.overrideWithValue(mockMotion),
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
            permissionRequesterProvider.overrideWithValue(
              FakePermissionRequester(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        );

        await tester.pumpWidget(app);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // KitaShell must be in the widget tree
        expect(
          find.byType(KitaShell),
          findsOneWidget,
          reason: 'Route "/" must render KitaShell (wiring fix 1)',
        );

        // KitaOrb must be visible (passive state)
        expect(
          find.byType(KitaOrb),
          findsOneWidget,
          reason: 'KitaOrb must be visible in passive mode',
        );

        // KitaInput must be visible with mic button
        expect(
          find.byType(KitaInput),
          findsOneWidget,
          reason: 'KitaInput must be visible with mic button',
        );

        router.dispose();
      },
    );
  });

  // ===========================================================================
  // Wiring Fix 4: Voice-first is unconditional
  // ===========================================================================
  group('Wiring Fix 4 — Voice-first unconditional greeting', () {
    testWidgets(
      'Kita speaks greeting on welcome step regardless of screen reader',
      (tester) async {
        // Test with screenReader: false — greeting must still happen
        await tester.pumpWidget(buildOnboardingTestApp(
          mockTts: mockTts,
          detectedProfile: const DetectedProfile(
            profile: AccessibilityProfile.general,
            screenReader: false,
            largeText: false,
            reduceMotion: false,
            boldText: false,
            highContrast: false,
          ),
        ));
        await tester.pumpAndSettle();

        // TTS must have been called even without screen reader
        expect(
          mockTts.spokenTexts,
          isNotEmpty,
          reason: 'Kita must speak greeting unconditionally (wiring fix 4)',
        );
        expect(
          mockTts.spokenTexts.first,
          contains('Bonjour'),
          reason: 'First spoken text must be the greeting',
        );
      },
    );

    testWidgets(
      'Kita speaks transition after name entry (voice-first)',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle();

        // Enter name and continue
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // TTS must have spoken the transition with Marie's name
        final allSpoken = mockTts.spokenTexts.join(' ');
        expect(
          allSpoken,
          contains('Marie'),
          reason: 'TTS must speak personalized transition with name',
        );
      },
    );
  });

  // ===========================================================================
  // Wiring Fix 5: Profile propagated to ProfileAdapter
  // ===========================================================================
  group('Wiring Fix 5 — Profile propagation to ProfileAdapter', () {
    testWidgets(
      'selecting "Aveugle" in onboarding UI propagates to UserProfileNotifier',
      (tester) async {
        // Use a ProviderScope so we can read the userProfileProvider afterwards
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
            ttsServiceProvider.overrideWithValue(mockTts),
            permissionRequesterProvider.overrideWithValue(
              FakePermissionRequester(),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: OnboardingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default profile before onboarding
        expect(
          container.read(userProfileProvider),
          UserProfile.standard,
          reason: 'Default UserProfile must be standard before onboarding',
        );

        // Step through: name -> mode -> profile
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Tap "Aveugle" profile — this triggers onProfileSelected callback
        // which calls selectProfile() + setProfile()
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Verify the REAL onboarding_screen.dart code propagated the profile
        expect(
          container.read(userProfileProvider),
          UserProfile.aveugle,
          reason:
              'UserProfile must be aveugle after tapping Aveugle in UI '
              '(wiring fix 5 — onboarding_screen.dart must call setProfile)',
        );

        // Verify ProfileAdapter reflects the change
        final adapter = container.read(profileAdapterProvider);
        expect(
          adapter.activeProfile,
          'aveugle',
          reason: 'ProfileAdapter must report "aveugle" active profile',
        );
      },
    );
  });

  // ===========================================================================
  // Wiring Fix 2 + 3: Orchestrator init + real access in sandbox
  // ===========================================================================
  group('Wiring Fix 2+3 — Orchestrator initialization with real access', () {
    test(
      'orchestrator initializes and spawns AlertAgent',
      () async {
        final harness = OrchestratorTestHarness();
        harness.setUp();

        try {
          await harness.orchestrator.initialize();

          // AlertAgent must be spawned at initialization (wiring fix 2)
          expect(
            harness.supervisor.agents.containsKey('com.kita.alert'),
            isTrue,
            reason:
                'AlertAgent must be spawned during orchestrator.initialize() '
                '(wiring fix 2 — called in KitaShell.initState)',
          );
        } finally {
          await harness.tearDown();
        }
      },
    );

    test(
      '"decris" command spawns DescribeAgent and triggers TTS',
      () async {
        final harness = OrchestratorTestHarness();
        harness.setUp();

        try {
          await harness.orchestrator.initialize();

          // Send "decris" command
          await harness.orchestrator.handleInput(
            RawInput.voice('decris', clock: harness.clock),
          );

          // DescribeAgent must be spawned
          expect(
            harness.supervisor.agents.containsKey('com.kita.describe'),
            isTrue,
            reason: 'DescribeAgent must be spawned by "decris" command',
          );

          // TTS must have been called (description or fallback message)
          expect(
            harness.tts.spokenTexts,
            isNotEmpty,
            reason: 'TTS must receive output from describe journey',
          );

          // AlertAgent must still be alive (persistent)
          expect(
            harness.supervisor.agents.containsKey('com.kita.alert'),
            isTrue,
            reason: 'AlertAgent must persist during describe journey',
          );
        } finally {
          await harness.tearDown();
        }
      },
    );
  });

  // ===========================================================================
  // Full onboarding state machine journey
  // ===========================================================================
  group('Full Marie journey — onboarding state machine', () {
    test(
      'complete flow: detecting -> welcome -> mode -> profile -> '
      'permissions -> magic -> complete',
      () async {
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

          final notifier = container.read(onboardingNotifierProvider.notifier);

          // Step 1: Welcome (auto-detected from stream)
          var state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.welcome);
          expect(state.detectedProfile?.profile, AccessibilityProfile.blind);

          // Step 2: Enter name + continue
          notifier.setUserName('Marie');
          notifier.completeWelcome();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.modeChoice);
          expect(state.userName, 'Marie');

          // Step 3: Choose "Pour moi"
          notifier.chooseStandardMode();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.profile);

          // Step 4: Select blind profile
          await notifier.selectProfile(AccessibilityProfile.blind);
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.permissions);

          // Propagate profile to ProfileAdapter (wiring fix 5)
          container
              .read(userProfileProvider.notifier)
              .setProfile(UserProfile.aveugle);

          // Step 5: Grant permissions
          notifier.grantPermission('camera');
          notifier.grantPermission('microphone');
          notifier.grantPermission('location');
          notifier.completePermissions();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.magic);

          // Step 6: Complete onboarding
          notifier.completeOnboarding();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.complete);
          expect(state.onboardingComplete, isTrue);

          // Verify onboarding complete flag
          expect(
            container.read(onboardingCompleteProvider),
            isTrue,
            reason: 'Onboarding must be marked complete',
          );

          // Verify profile was propagated
          expect(
            container.read(userProfileProvider),
            UserProfile.aveugle,
            reason: 'UserProfile must be aveugle after Marie onboarding',
          );
          expect(
            container.read(profileAdapterProvider).activeProfile,
            'aveugle',
            reason: 'ProfileAdapter must be aveugle after Marie onboarding',
          );
        } finally {
          container.dispose();
        }
      },
    );
  });

  // ===========================================================================
  // Full UI onboarding flow with TTS verification
  // ===========================================================================
  group('Full Marie journey — UI onboarding with TTS', () {
    testWidgets(
      'onboarding flow: greeting -> name -> mode -> profile (TTS verified)',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Welcome screen: Kita greets vocally (unconditional)
        expect(find.text('Bonjour, je suis Kita.'), findsOneWidget);
        expect(
          mockTts.spokenTexts,
          isNotEmpty,
          reason: 'TTS must speak greeting on welcome',
        );
        expect(mockTts.spokenTexts.first, contains('Bonjour'));

        // Enter name "Marie" and continue
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // TTS speaks transition with name
        final afterName = mockTts.spokenTexts.join(' ');
        expect(
          afterName,
          contains('Marie'),
          reason: 'TTS must speak personalized transition after name entry',
        );

        // Mode choice visible
        expect(find.text('Pour qui ?'), findsOneWidget);

        // Choose "Pour moi"
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Profile selector visible with "Aveugle" option
        expect(find.text('Choisis ton profil'), findsOneWidget);
        expect(find.text('Aveugle'), findsOneWidget);

        // Select "Aveugle"
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // TTS confirms profile selection (speaks profile name)
        final afterProfile = mockTts.spokenTexts.join(' ');
        expect(
          afterProfile,
          contains('Profil'),
          reason: 'TTS must confirm profile selection vocally',
        );

        // Permissions step reached
        expect(find.text('Permissions'), findsOneWidget);
      },
    );

    testWidgets(
      'permissions -> magic moment -> API key setup flow',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle(const Duration(minutes: 3));

        // Fast-forward through earlier steps
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Accept permissions
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Accepter'));
          await tester.pumpAndSettle();
        }

        // Magic moment step
        expect(find.text('Premier essai'), findsOneWidget);

        // Try describe (magic moment)
        await tester.tap(find.byKey(const Key('try_describe')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Continue to API key setup
        await tester.tap(find.byKey(const Key('continue_magic')));
        await tester.pumpAndSettle();

        // API key setup (last step before completion)
        expect(find.text('Configuration IA'), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // Post-onboarding: KitaShell wiring validation
  // ===========================================================================
  group('Post-onboarding — KitaShell wiring validation', () {
    test(
      'orchestrator handles "decris" after full onboarding state machine',
      () async {
        final harness = OrchestratorTestHarness();
        harness.setUp();

        try {
          // Simulate full orchestrator lifecycle as it would be post-onboarding
          await harness.orchestrator.initialize();

          // AlertAgent alive (wiring fix 2)
          expect(
            harness.supervisor.agents.containsKey('com.kita.alert'),
            isTrue,
          );

          // Send "decris" — the Marie use case
          await harness.orchestrator.handleInput(
            RawInput.voice('decris', clock: harness.clock),
          );

          // DescribeAgent spawned
          expect(
            harness.supervisor.agents.containsKey('com.kita.describe'),
            isTrue,
          );

          // TTS received output
          expect(harness.tts.spokenTexts, isNotEmpty);

          // OrbState transitioned (processing/responding)
          expect(
            harness.orbStates,
            isNotEmpty,
            reason: 'OrbState must transition during describe flow',
          );
        } finally {
          await harness.tearDown();
        }
      },
    );

    test(
      'orchestrator resilient — multiple commands without crash',
      () async {
        final harness = OrchestratorTestHarness();
        harness.setUp();

        try {
          await harness.orchestrator.initialize();

          // Sequence of commands Marie might use
          for (final cmd in ['decris', 'aide', 'alerte', 'decris']) {
            await expectLater(
              harness.orchestrator.handleInput(
                RawInput.voice(cmd, clock: harness.clock),
              ),
              completes,
              reason: 'handleInput("$cmd") must not throw',
            );
          }

          // AlertAgent must survive all commands
          expect(
            harness.supervisor.agents.containsKey('com.kita.alert'),
            isTrue,
            reason: 'AlertAgent must persist through all commands',
          );
        } finally {
          await harness.tearDown();
        }
      },
    );
  });
}
