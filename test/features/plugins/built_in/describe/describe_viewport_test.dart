import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';
import 'package:kita/features/plugins/built_in/describe/describe_viewport.dart';
import 'package:kita/shared/widgets/kita_feedback_bubble.dart';

/// Minimal bytes that trigger the error builder in Image.memory.
Uint8List _testBytes() => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xD9]);

ImageData _testImage() => ImageData(
      bytes: _testBytes(),
      mimeType: 'image/jpeg',
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('DescribeViewport', () {
    testWidgets('shows image widget when imageData present', (tester) async {
      final state = DescribeState.idle.withDescription(
        _testImage(),
        'Un salon lumineux.',
      );

      await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
      await tester.pump(); // Allow error builder to kick in

      // Image.memory is present (even if error builder takes over)
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows description bubble when description present',
        (tester) async {
      final state = DescribeState.idle.withDescription(
        _testImage(),
        'Un salon lumineux avec un canape bleu.',
      );

      await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
      await tester.pump();

      expect(find.byType(KitaFeedbackBubble), findsOneWidget);
      expect(find.text('Un salon lumineux avec un canape bleu.'), findsOneWidget);
    });

    testWidgets('shows both description and detailed bubbles', (tester) async {
      final state = DescribeState.idle
          .withDescription(_testImage(), 'Description initiale.')
          .withDetailedDescription('Description detaillee.');

      await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
      await tester.pump();

      expect(find.byType(KitaFeedbackBubble), findsNWidgets(2));
      expect(find.text('Description initiale.'), findsOneWidget);
      expect(find.text('Description detaillee.'), findsOneWidget);
    });

    testWidgets('shows nothing when state is idle', (tester) async {
      await tester
          .pumpWidget(_wrap(const DescribeViewport(state: DescribeState())));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(KitaFeedbackBubble), findsNothing);
    });

    testWidgets('shows offline indicator when isOffline', (tester) async {
      final state = DescribeState.idle.withDescription(
        _testImage(),
        'Texte OCR.',
        offline: true,
      );

      await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
      await tester.pump();

      expect(find.text('Mode local'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('hides offline indicator when online', (tester) async {
      final state = DescribeState.idle.withDescription(
        _testImage(),
        'Un salon lumineux.',
      );

      await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
      await tester.pump();

      expect(find.text('Mode local'), findsNothing);
    });

    group('Semantics', () {
      testWidgets('image has semantics wrapper with description',
          (tester) async {
        final state = DescribeState.idle.withDescription(
          _testImage(),
          'Un salon lumineux.',
        );

        await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
        await tester.pump();

        // Find the Semantics widget that wraps the image with the description label
        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains('Un salon lumineux.'),
        );
        expect(semanticsFinder, findsAtLeastNWidgets(1));
      });

      testWidgets('image has placeholder label before description',
          (tester) async {
        final state = DescribeState(
          phase: DescribePhase.describing,
          imageData: _testImage(),
        );

        await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
        await tester.pump();

        // Find the Semantics wrapper with the placeholder label
        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Photo en cours de description',
        );
        expect(semanticsFinder, findsAtLeastNWidgets(1));
      });

      testWidgets('description bubble has liveRegion ancestor',
          (tester) async {
        final state = DescribeState.idle.withDescription(
          _testImage(),
          'Un salon lumineux.',
        );

        await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
        await tester.pump();

        // Find the Semantics with liveRegion wrapping the bubble
        final bubbleFinder = find.byType(KitaFeedbackBubble);
        expect(bubbleFinder, findsOneWidget);

        final semanticsFinder = find.ancestor(
          of: bubbleFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        );
        expect(semanticsFinder, findsOneWidget);
      });

      testWidgets('offline indicator has semantics label', (tester) async {
        final state = DescribeState.idle.withDescription(
          _testImage(),
          'Texte.',
          offline: true,
        );

        await tester.pumpWidget(_wrap(DescribeViewport(state: state)));
        await tester.pump();

        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Mode local, description simplifiee',
        );
        expect(semanticsFinder, findsOneWidget);
      });
    });

    group('contrast values', () {
      /// Converts a single sRGB channel (0.0-1.0) to linear RGB.
      double srgbToLinear(double s) {
        return s <= 0.04045
            ? s / 12.92
            : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
      }

      /// Computes the WCAG 2.1 relative luminance of a [Color].
      double relativeLuminance(Color c) {
        final r = srgbToLinear(c.r);
        final g = srgbToLinear(c.g);
        final b = srgbToLinear(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      /// Computes the WCAG 2.1 contrast ratio between two colors.
      /// Returns a value >= 1.0 where higher means more contrast.
      double contrastRatio(Color lighter, Color darker) {
        final l1 = relativeLuminance(lighter);
        final l2 = relativeLuminance(darker);
        final high = l1 > l2 ? l1 : l2;
        final low = l1 > l2 ? l2 : l1;
        return (high + 0.05) / (low + 0.05);
      }

      test('text color (#E2E8F0) meets 4.5:1 on background (#1A1A2E)', () {
        const textColor = Color(0xFFE2E8F0);
        const backgroundColor = Color(0xFF1A1A2E);
        final ratio = contrastRatio(textColor, backgroundColor);

        // Must meet WCAG AA for normal text (>= 4.5:1)
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'Text contrast ratio $ratio should be >= 4.5:1');
      });

      test('text color (#E2E8F0) meets 4.5:1 on bubble (#16213E)', () {
        const textColor = Color(0xFFE2E8F0);
        const bubbleColor = Color(0xFF16213E);
        final ratio = contrastRatio(textColor, bubbleColor);

        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'Bubble text contrast ratio $ratio should be >= 4.5:1');
      });

      test('offline text color (#94A3B8) meets 4.5:1 on background (#1A1A2E)',
          () {
        const offlineTextColor = Color(0xFF94A3B8);
        const backgroundColor = Color(0xFF1A1A2E);
        final ratio = contrastRatio(offlineTextColor, backgroundColor);

        expect(ratio, greaterThanOrEqualTo(4.5),
            reason:
                'Offline text contrast ratio $ratio should be >= 4.5:1');
      });
    });
  });
}
