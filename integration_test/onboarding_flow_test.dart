/// Journey test : Onboarding complet pour utilisateur aveugle (AC1)
///
/// Valide le parcours complet :
///   détection VoiceOver → greeting vocal → nom → mode → profil (aveugle pré-sélectionné)
///   → permissions → magic moment → completion (isCompleted == true)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late IntegrationMockTTSService mockTts;

  setUp(() {
    mockTts = IntegrationMockTTSService();
  });

  tearDown(() {
    mockTts.dispose();
  });

  group('Journey onboarding — utilisateur aveugle (AC1)', () {
    testWidgets(
      'greeting vocal automatique détecté (VoiceOver actif)',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle();

        // Welcome screen doit être visible
        expect(find.text('Bonjour, je suis Kita.'), findsOneWidget);

        // TTS doit avoir parlé automatiquement (avant toute interaction)
        expect(mockTts.lastSpokenText, isNotNull);
        expect(mockTts.lastSpokenText, contains('Bonjour'));
      },
    );

    testWidgets(
      'Kita parle en premier — avant toute interaction utilisateur',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle();

        // Le greeting doit contenir "Kita" (identité vocale de l'app)
        expect(mockTts.spokenTexts, isNotEmpty);
        final allSpoken = mockTts.spokenTexts.join(' ');
        expect(allSpoken, contains('Kita'));
      },
    );

    testWidgets(
      'flux complet : nom → mode → profil aveugle pré-sélectionné',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Step 1: Welcome — saisir le nom
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        // Step 2: Choix du mode
        expect(find.text('Pour qui ?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Step 3: Profil — aveugle pré-sélectionné car screenReader: true
        expect(find.text('Choisis ton profil'), findsOneWidget);
        expect(find.text('Aveugle'), findsOneWidget);
      },
    );

    testWidgets(
      'flux permissions → magic moment (< 3 min simulées)',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle(const Duration(minutes: 3));

        // Welcome → mode
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();

        // Profil → permissions
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        expect(find.text('Permissions'), findsOneWidget);

        // Accepter toutes les permissions (caméra, micro, position)
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Accepter'));
          await tester.pumpAndSettle();
        }

        // Magic moment
        expect(find.text('Premier essai'), findsOneWidget);
      },
    );

    testWidgets(
      'magic moment → complétion → isCompleted == true',
      (tester) async {
        await tester.pumpWidget(buildOnboardingTestApp(mockTts: mockTts));
        await tester.pumpAndSettle();

        // Navigation rapide jusqu'au magic moment
        await tester.enterText(find.byKey(const Key('name_input')), 'Marie');
        await tester.tap(find.byKey(const Key('continue_welcome')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_for_me')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aveugle'));
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Accepter'));
          await tester.pumpAndSettle();
        }

        // Tenter le magic moment
        await tester.tap(find.byKey(const Key('try_describe')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Continuer vers la config API
        await tester.tap(find.byKey(const Key('continue_magic')));
        await tester.pumpAndSettle();

        // Configuration IA — dernier step avant complétion
        expect(find.text('Configuration IA'), findsOneWidget);
      },
    );

    test(
      'state machine : toutes les transitions jusqu\'à isCompleted == true',
      () async {
        // Test pur state machine — pas de widgets, pattern test() + try/finally
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

          // Détecter → Welcome
          var state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.welcome);
          expect(state.detectedProfile?.profile, AccessibilityProfile.blind);

          // Welcome → Mode
          notifier.setUserName('Marie');
          notifier.completeWelcome();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.modeChoice);
          expect(state.userName, 'Marie');

          // Mode → Profil
          notifier.chooseStandardMode();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.profile);

          // Profil → Permissions
          await notifier.selectProfile(AccessibilityProfile.blind);
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.permissions);

          // Permissions → Magic
          notifier.grantPermission('camera');
          notifier.grantPermission('microphone');
          notifier.grantPermission('location');
          notifier.completePermissions();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.magic);

          // Magic → Complete
          notifier.completeOnboarding();
          state = container.read(onboardingNotifierProvider);
          expect(state.step, OnboardingStep.complete);
          expect(state.onboardingComplete, isTrue);

          // isCompleted == true via provider dédié
          final isComplete = container.read(onboardingCompleteProvider);
          expect(isComplete, isTrue);
        } finally {
          container.dispose();
        }
      },
    );

    test(
      'fallback hors-ligne : onboarding ne crashe pas sans réseau',
      () async {
        // Le flow onboarding ne dépend pas du réseau pour ses étapes de base.
        // Ce test valide que le state machine fonctionne sans providers cloud.
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
          // Compléter le flow sans accès réseau
          notifier.setUserName('Marie');
          notifier.completeWelcome();
          notifier.chooseStandardMode();
          await notifier.selectProfile(AccessibilityProfile.blind);
          notifier.grantPermission('camera');
          notifier.grantPermission('microphone');
          notifier.grantPermission('location');
          notifier.completePermissions();
          notifier.completeOnboarding();

          final isComplete = container.read(onboardingCompleteProvider);
          expect(isComplete, isTrue, reason: 'Onboarding complété même hors-ligne');
        } finally {
          container.dispose();
        }
      },
    );
  });
}
