import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
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
      expect(
        find.text('Je suis là pour t\'aider au quotidien.'),
        findsOneWidget,
      );
    });

    testWidgets('welcome step has name input field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name_input')), findsOneWidget);
      expect(find.text('Ton prénom'), findsOneWidget);
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
}
