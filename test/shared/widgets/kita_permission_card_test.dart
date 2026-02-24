import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/shared/widgets/kita_permission_card.dart';

void main() {
  Widget buildCard({
    String permissionName = 'Camera',
    IconData icon = Icons.camera_alt,
    String story = 'Pour decrire ce qui t\'entoure, j\'ai besoin de ta camera',
    PermissionCardState state = PermissionCardState.asking,
    VoidCallback? onAccept,
    VoidCallback? onDeny,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: KitaPermissionCard(
            permissionName: permissionName,
            icon: icon,
            story: story,
            state: state,
            onAccept: onAccept,
            onDeny: onDeny,
          ),
        ),
      ),
    );
  }

  group('KitaPermissionCard rendering', () {
    testWidgets('renders in asking state', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.byType(KitaPermissionCard), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('displays storytelling text', (tester) async {
      await tester.pumpWidget(
        buildCard(story: 'Pour ecouter, j\'ai besoin du micro'),
      );
      expect(
        find.text('Pour ecouter, j\'ai besoin du micro'),
        findsOneWidget,
      );
    });

    testWidgets('shows accept/deny buttons in asking state', (tester) async {
      await tester.pumpWidget(buildCard(state: PermissionCardState.asking));
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('shows accept/deny buttons in reAsking state', (tester) async {
      await tester.pumpWidget(buildCard(state: PermissionCardState.reAsking));
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('hides buttons in granted state', (tester) async {
      await tester.pumpWidget(buildCard(state: PermissionCardState.granted));
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
      expect(find.text('Merci !'), findsOneWidget);
    });

    testWidgets('hides buttons in denied state', (tester) async {
      await tester.pumpWidget(buildCard(state: PermissionCardState.denied));
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
      expect(find.text('Permission refusee'), findsOneWidget);
    });
  });

  group('KitaPermissionCard interactions', () {
    testWidgets('calls onAccept when accept tapped', (tester) async {
      var accepted = false;
      await tester.pumpWidget(
        buildCard(onAccept: () => accepted = true),
      );

      await tester.tap(find.text('Accepter'));
      await tester.pump();

      expect(accepted, isTrue);
    });

    testWidgets('calls onDeny when deny tapped', (tester) async {
      var denied = false;
      await tester.pumpWidget(
        buildCard(onDeny: () => denied = true),
      );

      await tester.tap(find.text('Refuser'));
      await tester.pump();

      expect(denied, isTrue);
    });
  });

  group('KitaPermissionCard Semantics', () {
    testWidgets('has permission semantics label', (tester) async {
      await tester.pumpWidget(
        buildCard(permissionName: 'Camera', story: 'Test story'),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Demande de permission : Camera. Test story',
        ),
        findsOneWidget,
      );
    });

    testWidgets('accept button has semantics', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Accepter',
        ),
        findsOneWidget,
      );
    });

    testWidgets('deny button has semantics', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Refuser',
        ),
        findsOneWidget,
      );
    });
  });

  group('KitaPermissionCard states', () {
    for (final cardState in PermissionCardState.values) {
      testWidgets('renders in ${cardState.name} state', (tester) async {
        await tester.pumpWidget(buildCard(state: cardState));
        expect(find.byType(KitaPermissionCard), findsOneWidget);
      });
    }
  });
}
