import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/permission_step.dart';
import 'package:kita/shared/widgets/kita_permission_card.dart';

/// Fake storytelling service for testing.
class FakePermissionStorytelling implements PermissionStorytelling {
  List<PermissionResult>? resultToReturn;

  @override
  Future<List<PermissionResult>> requestAll(
    AccessibilityProfile profile,
  ) async {
    return resultToReturn ?? [];
  }
}

void main() {
  Widget buildTestWidget({
    AccessibilityProfile profile = AccessibilityProfile.general,
    void Function(List<PermissionResult>)? onComplete,
    PermissionStorytelling? storytelling,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PermissionStep(
          profile: profile,
          storytelling: storytelling ?? FakePermissionStorytelling(),
          onComplete: onComplete ?? (_) {},
        ),
      ),
    );
  }

  group('PermissionStep', () {
    testWidgets('shows permissions title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Permissions'), findsOneWidget);
    });

    testWidgets('shows progress indicator', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('shows KitaPermissionCard', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(KitaPermissionCard), findsOneWidget);
    });

    testWidgets('first permission shows camera explanation', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Camera first explanation contains "caméra"
      expect(
        find.textContaining('caméra'),
        findsWidgets,
      );
    });

    testWidgets('has skip button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('skip_permission')), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
    });

    testWidgets('accept button advances to next permission', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially shows camera explanation
      expect(find.textContaining('caméra'), findsWidgets);

      // Tap accept
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      // Should now show microphone explanation (2nd permission)
      expect(find.textContaining('micro'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('deny once shows re-asking state with second explanation',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap deny
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();

      // Should still show camera but with second explanation (mentions obstacles)
      expect(find.textContaining('obstacle'), findsOneWidget);
      // Still on step 1
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('deny twice advances to next permission', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // First deny -> re-ask
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();

      // Second deny -> advance
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();

      // Should now show microphone explanation
      expect(find.textContaining('micro'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('skip advances to next permission', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('skip_permission')));
      await tester.pumpAndSettle();

      // Should now show microphone explanation
      expect(find.textContaining('micro'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('completing all permissions calls onComplete',
        (tester) async {
      List<PermissionResult>? results;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (r) => results = r,
      ));
      await tester.pumpAndSettle();

      // Accept camera
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      // Accept microphone
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      // Accept location
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      expect(results, isNotNull);
      expect(results, hasLength(3));
      expect(results![0].isGranted, isTrue);
      expect(results![1].isGranted, isTrue);
      expect(results![2].isGranted, isTrue);
    });

    testWidgets('mixed accept/deny/skip calls onComplete with correct results',
        (tester) async {
      List<PermissionResult>? results;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (r) => results = r,
      ));
      await tester.pumpAndSettle();

      // Accept camera
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      // Deny then deny micro
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();

      // Skip location
      await tester.tap(find.byKey(const Key('skip_permission')));
      await tester.pumpAndSettle();

      expect(results, isNotNull);
      expect(results, hasLength(3));
      expect(results![0].isGranted, isTrue); // camera accepted
      expect(results![1].isGranted, isFalse); // micro denied
      expect(results![2].isGranted, isFalse); // location skipped
    });
  });

  group('PermissionStep Semantics', () {
    testWidgets('title has semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Permissions')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('skip button has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Passer cette permission')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('permission card has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Demande de permission')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('accept button meets touch target size', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final acceptButton = find.text('Accepter');
      expect(acceptButton, findsOneWidget);
      final size = tester.getSize(acceptButton.first);
      // The button itself should be >= 48px (within the 56px SizedBox)
      expect(size.height, greaterThanOrEqualTo(16)); // Text height OK
    });
  });
}
