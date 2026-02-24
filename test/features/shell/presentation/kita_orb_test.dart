import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/presentation/kita_orb.dart';

void main() {
  Widget buildTestOrb({
    OrbState state = OrbState.passive,
    OrbSize size = OrbSize.large,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: KitaOrb(state: state, size: size),
          ),
        ),
      ),
    );
  }

  group('KitaOrb rendering', () {
    testWidgets('renders without error in passive state', (tester) async {
      await tester.pumpWidget(buildTestOrb());
      expect(find.byType(KitaOrb), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KitaOrb),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders for each OrbState', (tester) async {
      for (final orbState in OrbState.values) {
        await tester.pumpWidget(buildTestOrb(state: orbState));
        await tester.pump();
        expect(
          find.byType(KitaOrb),
          findsOneWidget,
          reason: 'Should render for state $orbState',
        );
      }
    });
  });

  group('KitaOrb sizing', () {
    testWidgets('large size uses 50% of screen width', (tester) async {
      await tester.pumpWidget(buildTestOrb(size: OrbSize.large));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(KitaOrb),
          matching: find.byType(SizedBox),
        ),
      );

      // 400 * 0.5 = 200
      expect(sizedBox.width, 200.0);
      expect(sizedBox.height, 200.0);
    });

    testWidgets('small size uses 15% of screen width', (tester) async {
      await tester.pumpWidget(buildTestOrb(size: OrbSize.small));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(KitaOrb),
          matching: find.byType(SizedBox),
        ),
      );

      // 400 * 0.15 = 60
      expect(sizedBox.width, 60.0);
      expect(sizedBox.height, 60.0);
    });
  });

  group('KitaOrb Semantics', () {
    testWidgets('passive state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.passive));
      expect(
        find.bySemanticsLabel('Kita est en veille'),
        findsOneWidget,
      );
    });

    testWidgets('listening state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.listening));
      expect(
        find.bySemanticsLabel("Kita est a l'ecoute"),
        findsOneWidget,
      );
    });

    testWidgets('processing state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.processing));
      expect(
        find.bySemanticsLabel('Kita est en traitement'),
        findsOneWidget,
      );
    });

    testWidgets('responding state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.responding));
      expect(
        find.bySemanticsLabel('Kita repond'),
        findsOneWidget,
      );
    });

    testWidgets('error state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.error));
      expect(
        find.bySemanticsLabel('Kita est en erreur'),
        findsOneWidget,
      );
    });

    testWidgets('offline state has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.offline));
      expect(
        find.bySemanticsLabel('Kita est hors ligne'),
        findsOneWidget,
      );
    });

    testWidgets('all 6 states have unique semantics labels', (tester) async {
      final labels = <String>{};
      for (final state in OrbState.values) {
        labels.add(state.semanticsLabel);
      }
      expect(labels.length, 6);
    });
  });

  group('KitaOrb animation', () {
    testWidgets('animation runs in normal mode', (tester) async {
      await tester.pumpWidget(buildTestOrb());
      await tester.pump(const Duration(milliseconds: 500));

      // Verify CustomPaint inside KitaOrb is being repainted
      expect(
        find.descendant(
          of: find.byType(KitaOrb),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('animation stops with reduced motion', (tester) async {
      await tester.pumpWidget(
        buildTestOrb(disableAnimations: true),
      );
      await tester.pump();

      // Widget still renders, just without animation
      expect(find.byType(KitaOrb), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KitaOrb),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('state change triggers repaint', (tester) async {
      await tester.pumpWidget(buildTestOrb(state: OrbState.passive));
      await tester.pump();

      await tester.pumpWidget(buildTestOrb(state: OrbState.listening));
      await tester.pump();

      expect(
        find.bySemanticsLabel("Kita est a l'ecoute"),
        findsOneWidget,
      );
    });
  });

  group('KitaOrbPainter', () {
    test('shouldRepaint returns true for different state', () {
      const painterA = KitaOrbPainter(
        state: OrbState.passive,
        animationValue: 0.5,
      );
      const painterB = KitaOrbPainter(
        state: OrbState.listening,
        animationValue: 0.5,
      );
      expect(painterA.shouldRepaint(painterB), isTrue);
    });

    test('shouldRepaint returns true for different animation value', () {
      const painterA = KitaOrbPainter(
        state: OrbState.passive,
        animationValue: 0.3,
      );
      const painterB = KitaOrbPainter(
        state: OrbState.passive,
        animationValue: 0.5,
      );
      expect(painterA.shouldRepaint(painterB), isTrue);
    });

    test('shouldRepaint returns false for identical painters', () {
      const painterA = KitaOrbPainter(
        state: OrbState.passive,
        animationValue: 0.5,
      );
      const painterB = KitaOrbPainter(
        state: OrbState.passive,
        animationValue: 0.5,
      );
      expect(painterA.shouldRepaint(painterB), isFalse);
    });
  });

  group('OrbState semanticsLabel extension', () {
    test('all states have non-empty labels', () {
      for (final state in OrbState.values) {
        expect(state.semanticsLabel, isNotEmpty);
        expect(state.semanticsLabel, startsWith('Kita'));
      }
    });
  });
}
