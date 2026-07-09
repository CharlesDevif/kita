import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/features/memory/di/providers.dart';
import 'package:kita/features/memory/domain/preferences_repository.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/domain/shell_mode.dart';
import 'package:kita/features/shell/presentation/kita_orb.dart';
import 'package:kita/features/shell/presentation/kita_input.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/features/shell/presentation/kita_status_indicator.dart';

void main() {
  Widget buildShell({
    ShellMode mode = ShellMode.passive,
    OrbState orbState = OrbState.passive,
    KitaStatus status = KitaStatus.online,
    Widget? viewportChild,
    Widget? inputChild,
    bool disableAnimations = false,
  }) {
    return ProviderScope(
      overrides: [
        hasActiveOnDemandProvider.overrideWithValue(false),
        // Mark onboarding as complete so KitaShell shows normal viewport
        onboardingCompleteProvider.overrideWith(_CompletedOnboarding.new),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: disableAnimations,
          ),
          child: KitaShell(
            modeOverride: mode,
            orbStateOverride: orbState,
            status: status,
            viewportChild: viewportChild,
            inputChild: inputChild,
          ),
        ),
      ),
    );
  }

  group('KitaShell rendering', () {
    testWidgets('renders in passive mode', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.byType(KitaShell), findsOneWidget);
      expect(find.byType(KitaOrb), findsOneWidget);
      expect(find.byType(KitaStatusIndicator), findsOneWidget);
    });

    testWidgets('renders in active mode', (tester) async {
      await tester.pumpWidget(buildShell(mode: ShellMode.active));
      await tester.pump();
      expect(find.byType(KitaShell), findsOneWidget);
      expect(find.byType(KitaOrb), findsOneWidget);
    });

    testWidgets('displays default viewport text in passive mode', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.text('Tout va bien'), findsOneWidget);
    });

    testWidgets('displays custom viewport child', (tester) async {
      await tester.pumpWidget(
        buildShell(
          mode: ShellMode.active,
          viewportChild: const Text('Plugin content'),
        ),
      );
      await tester.pump();
      expect(find.text('Plugin content'), findsOneWidget);
    });

    testWidgets('displays custom input child', (tester) async {
      await tester.pumpWidget(
        buildShell(
          inputChild: const Text('Custom input'),
        ),
      );
      expect(find.text('Custom input'), findsOneWidget);
    });

    testWidgets('displays default input placeholder', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.text('Parle ou écris à Kita'), findsOneWidget);
    });
  });

  group('KitaShell Semantics', () {
    testWidgets('has main container semantics', (tester) async {
      await tester.pumpWidget(buildShell());
      // Verify the Semantics widget with the label exists in the tree
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Écran principal Kita',
        ),
        findsOneWidget,
      );
    });

    testWidgets('orb has semantics widget', (tester) async {
      await tester.pumpWidget(buildShell(orbState: OrbState.passive));
      // Verify KitaOrb renders with correct state
      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.state, OrbState.passive);
    });

    testWidgets('status indicator is present', (tester) async {
      await tester.pumpWidget(buildShell(status: KitaStatus.online));
      final indicator = tester.widget<KitaStatusIndicator>(
        find.byType(KitaStatusIndicator),
      );
      expect(indicator.status, KitaStatus.online);
    });

    testWidgets('input has semantics label widget', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Parle ou écris à Kita',
        ),
        findsOneWidget,
      );
    });

    testWidgets('viewport has live region semantics', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    });
  });

  group('KitaShell mode transitions', () {
    testWidgets('passive orb is large', (tester) async {
      await tester.pumpWidget(buildShell(mode: ShellMode.passive));
      await tester.pump();

      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.size, OrbSize.large);
    });

    testWidgets('active orb is small', (tester) async {
      await tester.pumpWidget(buildShell(mode: ShellMode.active));
      await tester.pump();

      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.size, OrbSize.small);
    });

    testWidgets('transition from passive to active', (tester) async {
      await tester.pumpWidget(buildShell(mode: ShellMode.passive));
      await tester.pump();

      // Switch to active
      await tester.pumpWidget(buildShell(mode: ShellMode.active));
      // Pump past the 300ms transition (orb has repeating animation, so no pumpAndSettle)
      await tester.pump(const Duration(milliseconds: 350));

      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.size, OrbSize.small);
    });

    testWidgets('transition from active to passive', (tester) async {
      await tester.pumpWidget(buildShell(mode: ShellMode.active));
      await tester.pump();

      // Switch to passive
      await tester.pumpWidget(buildShell(mode: ShellMode.passive));
      // Pump past the 500ms state transition
      await tester.pump(const Duration(milliseconds: 550));

      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.size, OrbSize.large);
    });

    testWidgets('reduced motion makes instant transition', (tester) async {
      await tester.pumpWidget(
        buildShell(mode: ShellMode.passive, disableAnimations: true),
      );
      await tester.pump();

      await tester.pumpWidget(
        buildShell(mode: ShellMode.active, disableAnimations: true),
      );
      // No animation, should be immediate
      await tester.pump();

      final orbWidget = tester.widget<KitaOrb>(find.byType(KitaOrb));
      expect(orbWidget.size, OrbSize.small);
    });
  });

  group('KitaShell status indicator states', () {
    for (final status in KitaStatus.values) {
      testWidgets('renders with status ${status.name}', (tester) async {
        await tester.pumpWidget(buildShell(status: status));
        final indicator = tester.widget<KitaStatusIndicator>(
          find.byType(KitaStatusIndicator),
        );
        expect(indicator.status, status);
      });
    }
  });

  group('KitaShell focus order', () {
    testWidgets('uses OrderedTraversalPolicy', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FocusTraversalGroup &&
              widget.policy is OrderedTraversalPolicy,
        ),
        findsOneWidget,
      );
    });

    testWidgets('has three FocusTraversalOrder widgets', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.byType(FocusTraversalOrder), findsNWidgets(3));
    });
  });

  group('KitaShell onboarding input visibility', () {
    Widget buildShellWithOnboarding({
      bool onboardingComplete = false,
      Widget? inputChild,
    }) {
      return ProviderScope(
        overrides: [
          hasActiveOnDemandProvider.overrideWithValue(false),
          onboardingCompleteProvider.overrideWith(
            () => onboardingComplete
                ? _CompletedOnboarding()
                : _IncompleteOnboarding(),
          ),
          // Hang the ShellOnboarding returning-user check so no greeting/TTS
          // starts and the real DB is never touched (these tests only exercise
          // the Shell layout during onboarding).
          preferencesRepositoryProvider.overrideWith(
            (ref) => Completer<PreferencesRepository>().future,
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: KitaShell(
              modeOverride: ShellMode.passive,
              orbStateOverride: OrbState.passive,
              inputChild: inputChild,
            ),
          ),
        ),
      );
    }

    testWidgets('hides KitaInput during onboarding', (tester) async {
      await tester.pumpWidget(
        buildShellWithOnboarding(onboardingComplete: false),
      );
      await tester.pump();

      expect(find.byType(KitaInput), findsNothing);
    });

    testWidgets('shows KitaInput after onboarding completes', (tester) async {
      await tester.pumpWidget(
        buildShellWithOnboarding(onboardingComplete: true),
      );
      await tester.pump();

      expect(find.byType(KitaInput), findsOneWidget);
    });

    testWidgets('shows custom inputChild even during onboarding',
        (tester) async {
      await tester.pumpWidget(
        buildShellWithOnboarding(
          onboardingComplete: false,
          inputChild: const Text('Custom input'),
        ),
      );
      await tester.pump();

      expect(find.text('Custom input'), findsOneWidget);
      expect(find.byType(KitaInput), findsNothing);
    });
  });
}

/// Notifier that starts with onboarding already complete.
class _CompletedOnboarding extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

/// Notifier that starts with onboarding NOT complete.
class _IncompleteOnboarding extends OnboardingCompleteNotifier {
  @override
  bool build() => false;
}
