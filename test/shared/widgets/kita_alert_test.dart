import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/shared/widgets/kita_alert.dart';

void main() {
  Widget buildAlert({
    String message = 'Obstacle detecte !',
    AlertSeverity severity = AlertSeverity.immediate,
    VoidCallback? onDismiss,
  }) {
    return MaterialApp(
      home: KitaAlert(
        message: message,
        severity: severity,
        onDismiss: onDismiss,
      ),
    );
  }

  group('KitaAlert rendering', () {
    testWidgets('renders with immediate severity', (tester) async {
      await tester.pumpWidget(buildAlert(severity: AlertSeverity.immediate));
      expect(find.byType(KitaAlert), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('renders with preventive severity', (tester) async {
      await tester.pumpWidget(buildAlert(severity: AlertSeverity.preventive));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('displays message text', (tester) async {
      await tester.pumpWidget(buildAlert(message: 'Attention devant'));
      expect(find.text('Attention devant'), findsOneWidget);
    });

    testWidgets('shows dismiss button when callback provided', (tester) async {
      await tester.pumpWidget(buildAlert(onDismiss: () {}));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides dismiss button when no callback', (tester) async {
      await tester.pumpWidget(buildAlert());
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onDismiss when close tapped', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        buildAlert(onDismiss: () => dismissed = true),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });

  group('KitaAlert Semantics', () {
    testWidgets('has live region semantics', (tester) async {
      await tester.pumpWidget(buildAlert());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('has alert label', (tester) async {
      await tester.pumpWidget(buildAlert(message: 'Test alert'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Alerte : Test alert',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dismiss button has semantics', (tester) async {
      await tester.pumpWidget(buildAlert(onDismiss: () {}));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Fermer alerte',
        ),
        findsOneWidget,
      );
    });
  });

  group('KitaAlert sizing', () {
    testWidgets('takes full viewport', (tester) async {
      await tester.pumpWidget(buildAlert());
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KitaAlert),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.constraints?.maxWidth, double.infinity);
      expect(container.constraints?.maxHeight, double.infinity);
    });

    testWidgets('dismiss button is 56x56', (tester) async {
      await tester.pumpWidget(buildAlert(onDismiss: () {}));
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, 56.0);
      expect(sizedBox.height, 56.0);
    });
  });
}
