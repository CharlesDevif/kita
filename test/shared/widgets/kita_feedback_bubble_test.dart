import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/shared/widgets/kita_feedback_bubble.dart';

void main() {
  Widget buildBubble({
    String content = 'Voici ce que je vois',
    DateTime? timestamp,
    BubbleVariant variant = BubbleVariant.text,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: KitaFeedbackBubble(
          content: content,
          timestamp: timestamp ?? DateTime(2026, 2, 24, 14, 30),
          variant: variant,
        ),
      ),
    );
  }

  group('KitaFeedbackBubble rendering', () {
    testWidgets('renders text content', (tester) async {
      await tester.pumpWidget(buildBubble(content: 'Hello from Kita'));
      expect(find.text('Hello from Kita'), findsOneWidget);
    });

    testWidgets('renders timestamp', (tester) async {
      await tester.pumpWidget(
        buildBubble(timestamp: DateTime(2026, 2, 24, 9, 5)),
      );
      expect(find.text('09:05'), findsOneWidget);
    });

    testWidgets('renders Kita avatar with K', (tester) async {
      await tester.pumpWidget(buildBubble());
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('renders for text variant', (tester) async {
      await tester.pumpWidget(buildBubble(variant: BubbleVariant.text));
      expect(find.byType(KitaFeedbackBubble), findsOneWidget);
    });

    testWidgets('renders for image variant', (tester) async {
      await tester.pumpWidget(buildBubble(variant: BubbleVariant.image));
      expect(find.byType(KitaFeedbackBubble), findsOneWidget);
    });

    testWidgets('renders for rich variant', (tester) async {
      await tester.pumpWidget(buildBubble(variant: BubbleVariant.rich));
      expect(find.byType(KitaFeedbackBubble), findsOneWidget);
    });
  });

  group('KitaFeedbackBubble Semantics', () {
    testWidgets('has response semantics label', (tester) async {
      await tester.pumpWidget(buildBubble(content: 'Test response'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Reponse de Kita : Test response',
        ),
        findsOneWidget,
      );
    });
  });

  group('KitaFeedbackBubble timestamp formatting', () {
    testWidgets('formats single-digit hours with leading zero', (tester) async {
      await tester.pumpWidget(
        buildBubble(timestamp: DateTime(2026, 1, 1, 8, 3)),
      );
      expect(find.text('08:03'), findsOneWidget);
    });

    testWidgets('formats double-digit hours correctly', (tester) async {
      await tester.pumpWidget(
        buildBubble(timestamp: DateTime(2026, 1, 1, 22, 45)),
      );
      expect(find.text('22:45'), findsOneWidget);
    });
  });
}
