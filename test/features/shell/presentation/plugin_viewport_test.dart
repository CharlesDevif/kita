import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/features/shell/presentation/plugin_viewport.dart';

void main() {
  Widget buildViewport({Widget? pluginWidget, String? fallbackText}) {
    return MaterialApp(
      home: Scaffold(
        body: PluginViewport(
          pluginWidget: pluginWidget,
          fallbackText: fallbackText,
        ),
      ),
    );
  }

  group('PluginViewport rendering', () {
    testWidgets('renders plugin widget when provided', (tester) async {
      await tester.pumpWidget(
        buildViewport(pluginWidget: const Text('Plugin UI')),
      );
      expect(find.text('Plugin UI'), findsOneWidget);
    });

    testWidgets('renders fallback text when no plugin', (tester) async {
      await tester.pumpWidget(
        buildViewport(fallbackText: 'Description vocale du resultat'),
      );
      expect(find.text('Description vocale du resultat'), findsOneWidget);
    });

    testWidgets('renders empty when no plugin and no fallback', (tester) async {
      await tester.pumpWidget(buildViewport());
      expect(find.byType(PluginViewport), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('is scrollable', (tester) async {
      await tester.pumpWidget(buildViewport());
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('clips content within bounds', (tester) async {
      await tester.pumpWidget(buildViewport());
      // PluginViewport uses ClipRect as its first child for sandbox isolation
      expect(
        find.descendant(
          of: find.byType(PluginViewport),
          matching: find.byType(ClipRect),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('PluginViewport Semantics', () {
    testWidgets('has live region semantics', (tester) async {
      await tester.pumpWidget(buildViewport());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('has container label', (tester) async {
      await tester.pumpWidget(buildViewport());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Zone de contenu plugin',
        ),
        findsOneWidget,
      );
    });

    testWidgets('fallback text has semantics label', (tester) async {
      await tester.pumpWidget(buildViewport(fallbackText: 'Test content'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Test content',
        ),
        findsOneWidget,
      );
    });
  });
}
