import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/caregiver_flow.dart';

void main() {
  Widget buildTestWidget({
    void Function(String, AccessibilityProfile)? onComplete,
    Future<void> Function(String)? onSpeak,
    BatchPermissionCallback? onBatchPermissions,
    Future<bool> Function()? onDescribe,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CaregiverFlow(
          onComplete: onComplete ?? (_, __) {},
          onSpeak: onSpeak,
          onBatchPermissions: onBatchPermissions,
          onDescribe: onDescribe,
        ),
      ),
    );
  }

  /// Navigate through name step by entering a name and tapping continue.
  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(
      find.byKey(const Key('caregiver_name_input')),
      name,
    );
    await tester.tap(find.byKey(const Key('caregiver_name_continue')));
    await tester.pumpAndSettle();
  }

  /// Navigate through profile step by tapping a profile option.
  Future<void> selectProfile(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Navigate through permissions step.
  Future<void> grantPermissions(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('caregiver_grant_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('caregiver_permissions_continue')));
    await tester.pumpAndSettle();
  }

  /// Navigate through test step (magic moment).
  Future<void> completeTest(WidgetTester tester) async {
    // Tap "Essayer" to trigger describe
    await tester.tap(find.byKey(const Key('try_describe')));
    await tester.pumpAndSettle();
    // Tap "Continuer" after describe completes
    await tester.tap(find.byKey(const Key('continue_magic')));
    await tester.pumpAndSettle();
  }

  group('CaregiverFlow name step', () {
    testWidgets('shows name input initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('Pour qui configurez-vous Kita ?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('caregiver_name_input')),
        findsOneWidget,
      );
    });

    testWidgets('empty name does not advance', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('caregiver_name_continue')));
      await tester.pumpAndSettle();

      // Still on name step
      expect(
        find.text('Pour qui configurez-vous Kita ?'),
        findsOneWidget,
      );
    });

    testWidgets('entering name advances to profile step', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');

      // Should show profile selector
      expect(find.text('Choisis ton profil'), findsOneWidget);
    });
  });

  group('CaregiverFlow profile step', () {
    testWidgets('shows profile options after name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');

      expect(find.text('Aveugle'), findsOneWidget);
      expect(find.text('Malvoyant'), findsOneWidget);
      expect(find.text('Général'), findsOneWidget);
    });

    testWidgets('selecting profile advances to permissions', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      expect(find.text('Permissions'), findsOneWidget);
      expect(
        find.byKey(const Key('caregiver_grant_all')),
        findsOneWidget,
      );
    });
  });

  group('CaregiverFlow permissions step', () {
    testWidgets('shows batch grant button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      expect(find.text('Autoriser tout'), findsOneWidget);
    });

    testWidgets('grant all calls batch callback', (tester) async {
      bool batchCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onBatchPermissions: () async {
          batchCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      await tester.tap(find.byKey(const Key('caregiver_grant_all')));
      await tester.pumpAndSettle();

      expect(batchCalled, isTrue);
      expect(find.text('Permissions accordées'), findsOneWidget);
    });

    testWidgets('skip advances to test step', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      await tester.tap(find.byKey(const Key('caregiver_skip_permissions')));
      await tester.pumpAndSettle();

      // Should show magic moment test step
      expect(find.text('Premier essai'), findsOneWidget);
    });

    testWidgets('continue after grant advances to test step', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      await grantPermissions(tester);

      // Should show magic moment test step
      expect(find.text('Premier essai'), findsOneWidget);
    });
  });

  group('CaregiverFlow test step', () {
    testWidgets('shows magic moment for guided test', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);

      // Should display the magic moment step
      expect(find.text('Premier essai'), findsOneWidget);
      expect(find.byKey(const Key('try_describe')), findsOneWidget);
    });

    testWidgets('completing test advances to confirmation', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);
      await completeTest(tester);

      // Should show confirmation
      expect(find.textContaining('prêt pour Marie'), findsOneWidget);
    });
  });

  group('CaregiverFlow confirmation step', () {
    testWidgets('shows personalized confirmation message', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);
      await completeTest(tester);

      expect(
        find.text('Tout est prêt pour Marie !'),
        findsOneWidget,
      );
      expect(
        find.textContaining('accueillera'),
        findsOneWidget,
      );
    });

    testWidgets('finish button calls onComplete with name and profile',
        (tester) async {
      String? completedName;
      AccessibilityProfile? completedProfile;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (name, profile) {
          completedName = name;
          completedProfile = profile;
        },
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);
      await completeTest(tester);

      await tester.tap(find.byKey(const Key('caregiver_finish')));
      await tester.pumpAndSettle();

      expect(completedName, 'Marie');
      expect(completedProfile, AccessibilityProfile.blind);
    });

    testWidgets('speaks confirmation via TTS', (tester) async {
      final spokenTexts = <String>[];

      await tester.pumpWidget(buildTestWidget(
        onSpeak: (text) async => spokenTexts.add(text),
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);
      await completeTest(tester);

      // Confirmation TTS should include the target name
      expect(
        spokenTexts.any((t) => t.contains('Marie')),
        isTrue,
      );
    });
  });

  group('CaregiverFlow full journey', () {
    testWidgets('complete flow from name to finish', (tester) async {
      String? completedName;
      AccessibilityProfile? completedProfile;
      bool batchCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (name, profile) {
          completedName = name;
          completedProfile = profile;
        },
        onBatchPermissions: () async {
          batchCalled = true;
        },
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      // Step 1: Enter name
      await enterName(tester, 'Marie');

      // Step 2: Select profile
      await selectProfile(tester, 'Aveugle');

      // Step 3: Grant permissions
      await grantPermissions(tester);
      expect(batchCalled, isTrue);

      // Step 4: Complete test
      await completeTest(tester);

      // Step 5: Finish
      await tester.tap(find.byKey(const Key('caregiver_finish')));
      await tester.pumpAndSettle();

      expect(completedName, 'Marie');
      expect(completedProfile, AccessibilityProfile.blind);
    });

    testWidgets('flow works with general profile', (tester) async {
      String? completedName;
      AccessibilityProfile? completedProfile;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (name, profile) {
          completedName = name;
          completedProfile = profile;
        },
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Jean');
      await selectProfile(tester, 'Général');

      // Skip permissions
      await tester.tap(find.byKey(const Key('caregiver_skip_permissions')));
      await tester.pumpAndSettle();

      await completeTest(tester);

      await tester.tap(find.byKey(const Key('caregiver_finish')));
      await tester.pumpAndSettle();

      expect(completedName, 'Jean');
      expect(completedProfile, AccessibilityProfile.general);
    });
  });

  group('CaregiverFlow Semantics', () {
    testWidgets('name input has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Prénom de l\'utilisateur')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('grant all button has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      expect(
        find.bySemanticsLabel(RegExp('Autoriser toutes les permissions')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('finish button has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget(
        onDescribe: () async => true,
      ));
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');
      await grantPermissions(tester);
      await completeTest(tester);

      expect(
        find.bySemanticsLabel(RegExp('Terminer la configuration')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('name continue button meets touch target size', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('caregiver_name_continue'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('grant all button meets touch target size', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await enterName(tester, 'Marie');
      await selectProfile(tester, 'Aveugle');

      final button = find.byKey(const Key('caregiver_grant_all'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
