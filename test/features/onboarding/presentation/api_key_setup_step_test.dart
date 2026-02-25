import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/presentation/api_key_setup_step.dart';

void main() {
  Widget buildTestWidget({
    void Function(ProviderMode)? onComplete,
    ValidateKeyCallback? onValidateKey,
    StoreKeyCallback? onStoreKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ApiKeySetupStep(
          onComplete: onComplete ?? (_) {},
          onValidateKey: onValidateKey,
          onStoreKey: onStoreKey,
        ),
      ),
    );
  }

  group('ApiKeySetupStep mode selection', () {
    testWidgets('shows configuration title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Configuration IA'), findsOneWidget);
    });

    testWidgets('shows discovery and BYOK buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mode_discovery')), findsOneWidget);
      expect(find.byKey(const Key('mode_byok')), findsOneWidget);
      expect(find.text('Découverte gratuite'), findsOneWidget);
      expect(find.text('J\'ai mes propres clés'), findsOneWidget);
    });

    testWidgets('discovery button calls onComplete with discovery mode',
        (tester) async {
      ProviderMode? selectedMode;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (mode) => selectedMode = mode,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mode_discovery')));
      expect(selectedMode, ProviderMode.discovery);
    });

    testWidgets('BYOK button shows API key input', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      expect(find.text('Clé API'), findsWidgets);
      expect(find.byKey(const Key('api_key_input')), findsOneWidget);
    });
  });

  group('ApiKeySetupStep BYOK', () {
    testWidgets('validates and stores key on submit', (tester) async {
      String? storedProvider;
      String? storedKey;

      await tester.pumpWidget(buildTestWidget(
        onValidateKey: (provider, key) async => true,
        onStoreKey: (provider, key) async {
          storedProvider = provider;
          storedKey = key;
        },
      ));
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Enter a key
      await tester.enterText(
        find.byKey(const Key('api_key_input')),
        'sk-ant-test123',
      );
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(storedProvider, 'anthropic');
      expect(storedKey, 'sk-ant-test123');
    });

    testWidgets('shows error for invalid key', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onValidateKey: (provider, key) async => false,
      ));
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Enter an invalid key
      await tester.enterText(
        find.byKey(const Key('api_key_input')),
        'invalid-key',
      );
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(find.textContaining('invalide'), findsOneWidget);
    });

    testWidgets('shows error for empty key', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Submit without entering a key
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Veuillez entrer'), findsOneWidget);
    });

    testWidgets('shows check mark after successful storage', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onValidateKey: (_, __) async => true,
        onStoreKey: (_, __) async {},
      ));
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Enter a valid key
      await tester.enterText(
        find.byKey(const Key('api_key_input')),
        'sk-ant-test123',
      );
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('continue button calls onComplete with BYOK mode',
        (tester) async {
      ProviderMode? selectedMode;

      await tester.pumpWidget(buildTestWidget(
        onComplete: (mode) => selectedMode = mode,
        onValidateKey: (_, __) async => true,
        onStoreKey: (_, __) async {},
      ));
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Enter and validate a key
      await tester.enterText(
        find.byKey(const Key('api_key_input')),
        'sk-ant-test123',
      );
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      // Tap continue
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(selectedMode, ProviderMode.byok);
    });

    testWidgets('back button returns to mode selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('api_key_input')), findsOneWidget);

      // Go back
      await tester.tap(find.byKey(const Key('back_to_modes')));
      await tester.pumpAndSettle();

      expect(find.text('Configuration IA'), findsOneWidget);
      expect(find.byKey(const Key('mode_discovery')), findsOneWidget);
    });

    testWidgets('detects OpenAI key prefix', (tester) async {
      String? storedProvider;

      await tester.pumpWidget(buildTestWidget(
        onValidateKey: (_, __) async => true,
        onStoreKey: (provider, _) async {
          storedProvider = provider;
        },
      ));
      await tester.pumpAndSettle();

      // Navigate to BYOK
      await tester.tap(find.byKey(const Key('mode_byok')));
      await tester.pumpAndSettle();

      // Enter an OpenAI key
      await tester.enterText(
        find.byKey(const Key('api_key_input')),
        'sk-openai-key-12345',
      );
      await tester.tap(find.byKey(const Key('validate_key')));
      await tester.pumpAndSettle();

      expect(storedProvider, 'openai');
    });
  });

  group('ApiKeySetupStep Semantics', () {
    testWidgets('title has semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Configuration IA')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('discovery button has semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('découverte gratuit')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('discovery button meets touch target size', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('mode_discovery'));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
