import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/plugins/built_in/alert/alert_viewport.dart';
import 'package:kita/shared/widgets/kita_alert.dart';

/// Helper to wrap a widget in a minimal MaterialApp for testing.
Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(body: child),
        );
      },
    ),
  );
}

void main() {
  group('AlertViewport Semantics', () {
    testWidgets('has liveRegion: true in semantics tree', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AlertViewport(
            message: 'Attention ! voiture a 2 metres',
            severity: AlertSeverity.immediate,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(AlertViewport));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('semantics label matches alert message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AlertViewport(
            message: 'travaux a 8 metres',
            severity: AlertSeverity.preventive,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(AlertViewport));
      expect(semantics.label, 'Alerte : travaux a 8 metres');
    });

    testWidgets('dismiss button has Semantics button label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertViewport(
            message: 'voiture a 2 metres',
            severity: AlertSeverity.immediate,
            onDismiss: () {},
          ),
        ),
      );

      // Find the Semantics widget wrapping the dismiss button
      final dismissSemanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Fermer alerte',
      );
      expect(dismissSemanticsFinder, findsOneWidget);

      // Verify the semantics node has button flag
      final buttonSemantics = tester.getSemantics(dismissSemanticsFinder);
      expect(buttonSemantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('focus order: alert label before dismiss button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertViewport(
            message: 'voiture a 2 metres',
            severity: AlertSeverity.immediate,
            onDismiss: () {},
          ),
        ),
      );

      final alertFinder = find.byType(AlertViewport);
      final dismissSemanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Fermer alerte',
      );

      expect(alertFinder, findsOneWidget);
      expect(dismissSemanticsFinder, findsOneWidget);

      // AlertViewport is an ancestor of the dismiss button semantics,
      // ensuring the alert label is encountered first in the tree
      expect(
        find.ancestor(
          of: dismissSemanticsFinder,
          matching: find.byType(AlertViewport),
        ),
        findsOneWidget,
        reason: 'Dismiss button should be a descendant of AlertViewport, '
            'ensuring alert label is read first in focus order',
      );
    });

    testWidgets('renders KitaAlert with correct severity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AlertViewport(
            message: 'test message',
            severity: AlertSeverity.preventive,
          ),
        ),
      );

      expect(find.byType(KitaAlert), findsOneWidget);
    });

    testWidgets('no dismiss button when onDismiss is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AlertViewport(
            message: 'test message',
            severity: AlertSeverity.immediate,
          ),
        ),
      );

      final dismissSemanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Fermer alerte',
      );
      expect(dismissSemanticsFinder, findsNothing);
    });
  });

  group('AlertViewport fade-out animation', () {
    testWidgets('starts fully visible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertViewport(
            message: 'voiture a 2 metres',
            severity: AlertSeverity.immediate,
            onDismiss: () {},
          ),
        ),
      );

      final fadeTransition = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(AlertViewport),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fadeTransition.opacity.value, 1.0);
    });

    testWidgets('fade-out animation on dismiss', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _wrap(
          AlertViewport(
            message: 'voiture a 2 metres',
            severity: AlertSeverity.immediate,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      // Find the dismiss button via its InkWell inside the Semantics wrapper
      final dismissFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Fermer alerte',
      );

      // Tap the dismiss button
      await tester.tap(dismissFinder);
      await tester.pump();

      // Mid-animation: opacity should be between 0 and 1
      await tester.pump(const Duration(milliseconds: 150));
      final fadeTransition = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(AlertViewport),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fadeTransition.opacity.value, greaterThan(0.0));
      expect(fadeTransition.opacity.value, lessThan(1.0));

      // onDismiss not yet called (animation still running)
      expect(dismissed, isFalse);

      // Complete animation and settle all remaining frames/microtasks
      await tester.pumpAndSettle();

      // onDismiss should now be called
      expect(dismissed, isTrue);
    });

    testWidgets('skips animation when prefers-reduced-motion', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _wrap(
          AlertViewport(
            message: 'voiture a 2 metres',
            severity: AlertSeverity.immediate,
            onDismiss: () => dismissed = true,
          ),
          disableAnimations: true,
        ),
      );

      // Find the dismiss button
      final dismissFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Fermer alerte',
      );

      // Tap the dismiss button
      await tester.tap(dismissFinder);
      await tester.pump();

      // onDismiss should be called immediately (no animation)
      expect(dismissed, isTrue);
    });
  });
}
