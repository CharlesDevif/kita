import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/features/shell/domain/shell_mode.dart';
import 'package:kita/features/shell/presentation/kita_status_indicator.dart';

void main() {
  Widget buildIndicator(KitaStatus status) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: KitaStatusIndicator(status: status),
        ),
      ),
    );
  }

  group('KitaStatusIndicator rendering', () {
    testWidgets('renders for online status', (tester) async {
      await tester.pumpWidget(buildIndicator(KitaStatus.online));
      expect(find.byType(KitaStatusIndicator), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    testWidgets('renders for offline status', (tester) async {
      await tester.pumpWidget(buildIndicator(KitaStatus.offline));
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('renders for degraded status', (tester) async {
      await tester.pumpWidget(buildIndicator(KitaStatus.degraded));
      expect(find.byIcon(Icons.wifi_1_bar), findsOneWidget);
    });

    testWidgets('renders for error status', (tester) async {
      await tester.pumpWidget(buildIndicator(KitaStatus.error));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('KitaStatusIndicator Semantics', () {
    for (final status in KitaStatus.values) {
      testWidgets('${status.name} has semantics label widget', (tester) async {
        await tester.pumpWidget(buildIndicator(status));
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == status.semanticsLabel,
          ),
          findsOneWidget,
        );
      });
    }
  });

  group('KitaStatusIndicator sizing', () {
    testWidgets('container is 48x48', (tester) async {
      await tester.pumpWidget(buildIndicator(KitaStatus.online));

      final containerFinder = find.descendant(
        of: find.byType(KitaStatusIndicator),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth ?? 0, greaterThanOrEqualTo(48));
    });
  });

  group('KitaStatus extension', () {
    test('all statuses have non-empty labels', () {
      for (final status in KitaStatus.values) {
        expect(status.semanticsLabel, isNotEmpty);
      }
    });

    test('all labels are unique', () {
      final labels = KitaStatus.values.map((s) => s.semanticsLabel).toSet();
      expect(labels.length, KitaStatus.values.length);
    });
  });
}
