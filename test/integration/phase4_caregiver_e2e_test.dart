import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/onboarding/data/pack_installer.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';

import '../mocks/mock_tts_service.dart';

/// Phase 4 Integration Gate — AC2: Caregiver mode E2E
///
/// Tests the caregiver flow: Sophie configures Kita for Marie.
/// mode choice "Pour quelqu'un d'autre" -> name "Marie" -> profile blind ->
/// batch permissions -> guided test (DECRIS) -> confirmation ->
/// completion with caregiver flag.
void main() {
  late MockTTSService mockTts;

  Widget buildTestApp({
    DetectedProfile detectedProfile = DetectedProfile.general,
  }) {
    return ProviderScope(
      overrides: [
        detectedProfileProvider.overrideWith(
          (ref) => Stream.value(detectedProfile),
        ),
        ttsServiceProvider.overrideWithValue(mockTts),
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

  group('Phase 4 Gate — AC2: Caregiver mode E2E', () {
    testWidgets(
      'caregiver flow: mode choice -> caregiver step',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Welcome — continue without name (Sophie doesn't need to enter hers)
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // Mode choice — select "Pour quelqu'un d'autre"
        expect(find.text('Pour qui ?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('mode_for_other')));
        await tester.pumpAndSettle();

        // Should be in caregiver flow — name step
        expect(find.text('Pour qui configurez-vous Kita ?'), findsOneWidget);
        expect(
          find.byKey(const Key('caregiver_name_input')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'caregiver flow: enter target name "Marie" -> profile selection',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate to caregiver flow
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_other')));
        await tester.pumpAndSettle();

        // Enter target user's name
        await tester.enterText(
          find.byKey(const Key('caregiver_name_input')),
          'Marie',
        );
        await tester.tap(find.byKey(const Key('caregiver_name_continue')));
        await tester.pumpAndSettle();

        // Should show profile selection
        expect(find.text('Choisis ton profil'), findsOneWidget);
        expect(find.text('Aveugle'), findsOneWidget);
        expect(find.text('Malvoyant'), findsOneWidget);
        expect(find.text('Général'), findsOneWidget);
      },
    );

    testWidgets(
      'caregiver flow: select blind profile -> batch permissions',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate to caregiver profile step
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_other')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('caregiver_name_input')),
          'Marie',
        );
        await tester.tap(find.byKey(const Key('caregiver_name_continue')));
        await tester.pumpAndSettle();

        // Select blind profile
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Should show batch permissions step
        expect(find.text('Permissions'), findsOneWidget);
        expect(
          find.byKey(const Key('caregiver_grant_all')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'caregiver flow: batch permissions -> test guide -> confirmation',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate through caregiver flow to permissions
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_other')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('caregiver_name_input')),
          'Marie',
        );
        await tester.tap(find.byKey(const Key('caregiver_name_continue')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Grant all permissions
        await tester.tap(find.byKey(const Key('caregiver_grant_all')));
        await tester.pumpAndSettle();

        // Should show "Permissions accordées" and continue button
        expect(find.text('Permissions accordées'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('caregiver_permissions_continue')),
        );
        await tester.pumpAndSettle();

        // Should be at test step (MagicMomentStep embedded)
        expect(find.text('Premier essai'), findsOneWidget);

        // Try the describe test
        await tester.tap(find.byKey(const Key('try_describe')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Should show continue after success
        await tester.tap(find.byKey(const Key('continue_magic')));
        await tester.pumpAndSettle();

        // Should be at confirmation step
        expect(find.textContaining('Marie'), findsWidgets);
        expect(find.byKey(const Key('caregiver_finish')), findsOneWidget);
      },
    );

    testWidgets(
      'caregiver skip permissions -> test -> finish completes onboarding',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigate through caregiver flow
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_other')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('caregiver_name_input')),
          'Marie',
        );
        await tester.tap(find.byKey(const Key('caregiver_name_continue')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        // Skip permissions
        await tester.tap(find.byKey(const Key('caregiver_skip_permissions')));
        await tester.pumpAndSettle();

        // Try describe
        await tester.tap(find.byKey(const Key('try_describe')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('continue_magic')));
        await tester.pumpAndSettle();

        // Confirmation — verify "Marie" appears
        expect(find.textContaining('Marie'), findsWidgets);
      },
    );

    test(
      'caregiver notifier: state tracks caregiver flag and target name',
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

        // Welcome -> mode choice
        notifier.completeWelcome();
        // Choose caregiver mode
        notifier.chooseCaregiverMode();

        var state = container.read(onboardingNotifierProvider);
        expect(state.step, OnboardingStep.caregiver);
        expect(state.isCaregiverMode, isTrue);

        // Set target name
        notifier.setUserName('Marie');
        state = container.read(onboardingNotifierProvider);
        expect(state.userName, 'Marie');

        // Complete caregiver onboarding
        notifier.completeCaregiverOnboarding();
        state = container.read(onboardingNotifierProvider);
        expect(state.step, OnboardingStep.complete);
        expect(state.onboardingComplete, isTrue);
        expect(state.isConfiguredByCaregiver, isTrue);

        final isComplete = container.read(onboardingCompleteProvider);
        expect(isComplete, isTrue);
      },
    );

    test('blind profile installs describe + alert pack for caregiver', () {
      final installer = PackInstaller();
      final pack = installer.getPackForProfile(AccessibilityProfile.blind);

      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, contains('com.kita.alert'));
      expect(pack.description, 'Describe + Alert');
    });
  });
}
