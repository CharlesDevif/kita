import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/presentation/magic_moment_step.dart';

void main() {
  Widget buildTestWidget({
    VoidCallback? onComplete,
    DescribeCallback? onDescribe,
    Future<void> Function(String)? onSpeak,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MagicMomentStep(
          onComplete: onComplete ?? () {},
          onDescribe: onDescribe,
          onSpeak: onSpeak,
        ),
      ),
    );
  }

  group('MagicMomentStep', () {
    testWidgets('shows invitation text initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Premier essai'), findsOneWidget);
      expect(find.textContaining('décris'), findsWidgets);
    });

    testWidgets('shows try button initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('try_describe')), findsOneWidget);
      expect(find.text('Essayer'), findsOneWidget);
    });

    testWidgets('shows processing state when try tapped', (tester) async {
      final completer = Completer<bool>();

      await tester.pumpWidget(buildTestWidget(
        onDescribe: () => completer.future,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pump();

      expect(find.text('Je regarde...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer
      completer.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('shows success state after describe completes',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      expect(find.textContaining('prête'), findsOneWidget);
      expect(find.byKey(const Key('continue_magic')), findsOneWidget);
    });

    testWidgets('shows failure state when describe fails', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      expect(find.textContaining('réessayera'), findsOneWidget);
      expect(find.byKey(const Key('continue_magic')), findsOneWidget);
    });

    testWidgets('shows failure state when describe throws', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => throw Exception('camera error'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      expect(find.textContaining('réessayera'), findsOneWidget);
    });

    testWidgets('calls onComplete when continue tapped after success',
        (tester) async {
      bool completed = false;

      await tester.pumpWidget(buildTestWidget(
        onComplete: () => completed = true,
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_magic')));
      expect(completed, isTrue);
    });

    testWidgets('calls onComplete when continue tapped after failure',
        (tester) async {
      bool completed = false;

      await tester.pumpWidget(buildTestWidget(
        onComplete: () => completed = true,
        onDescribe: () async => false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_magic')));
      expect(completed, isTrue);
    });

    testWidgets('speaks invitation on init', (tester) async {
      final spokenTexts = <String>[];

      await tester.pumpWidget(buildTestWidget(
        onSpeak: (text) async => spokenTexts.add(text),
      ));
      await tester.pumpAndSettle();

      expect(spokenTexts, hasLength(1));
      expect(spokenTexts.first, contains('décris'));
    });

    testWidgets('speaks success message after describe', (tester) async {
      final spokenTexts = <String>[];

      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => true,
        onSpeak: (text) async => spokenTexts.add(text),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pumpAndSettle();

      expect(spokenTexts, hasLength(2));
      expect(spokenTexts[1], contains('prête'));
    });

    testWidgets('default onDescribe simulates success', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('try_describe')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.textContaining('prête'), findsOneWidget);
    });
  });

  group('MagicMomentStep Semantics', () {
    testWidgets('title has semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Premier essai')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('try button has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Essayer la commande décris')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('try button meets touch target size', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('try_describe'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
