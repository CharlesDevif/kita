import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kita/core/navigation/router.dart';
import 'package:kita/features/onboarding/presentation/onboarding_placeholder.dart';
import 'package:kita/features/settings/presentation/forget_placeholder.dart';
import 'package:kita/features/settings/presentation/memory_view_placeholder.dart';
import 'package:kita/features/settings/presentation/plugin_manager_placeholder.dart';
import 'package:kita/features/settings/presentation/settings_placeholder.dart';
import 'package:kita/features/shell/presentation/kita_shell_placeholder.dart';

GoRouter _createRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: kitaRoutes,
  );
}

Widget _createTestApp(GoRouter router) {
  return ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('Route resolution', () {
    testWidgets('/ resolves to KitaShellPlaceholder', (tester) async {
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(KitaShellPlaceholder), findsOneWidget);
      expect(find.text('Kita Shell — Placeholder'), findsOneWidget);
    });

    testWidgets('/onboarding resolves to OnboardingPlaceholder', (tester) async {
      final router = _createRouter('/onboarding');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPlaceholder), findsOneWidget);
      expect(find.text('Onboarding — Placeholder'), findsOneWidget);
    });

    testWidgets('/settings resolves to SettingsPlaceholder', (tester) async {
      final router = _createRouter('/settings');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPlaceholder), findsOneWidget);
      expect(find.text('Settings — Placeholder'), findsOneWidget);
    });

    testWidgets('/settings/plugins resolves to PluginManagerPlaceholder', (tester) async {
      final router = _createRouter('/settings/plugins');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(PluginManagerPlaceholder), findsOneWidget);
      expect(find.text('Plugin Manager — Placeholder'), findsOneWidget);
    });

    testWidgets('/settings/memory resolves to MemoryViewPlaceholder', (tester) async {
      final router = _createRouter('/settings/memory');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryViewPlaceholder), findsOneWidget);
      expect(find.text('Memory View — Placeholder'), findsOneWidget);
    });

    testWidgets('/settings/forget resolves to ForgetPlaceholder', (tester) async {
      final router = _createRouter('/settings/forget');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(ForgetPlaceholder), findsOneWidget);
      expect(find.text('Forget — Placeholder'), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('navigate from / to /settings', (tester) async {
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parametres'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPlaceholder), findsOneWidget);
    });

    testWidgets('navigate from /settings to /settings/plugins via push', (tester) async {
      final router = _createRouter('/settings');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plugins'));
      await tester.pumpAndSettle();

      expect(find.byType(PluginManagerPlaceholder), findsOneWidget);
    });
  });

  group('Semantics', () {
    testWidgets('KitaShellPlaceholder has semantics label', tags: ['accessibility'], (tester) async {
      final handle = tester.ensureSemantics();
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Ecran principal Kita',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('SettingsPlaceholder has semantics label', tags: ['accessibility'], (tester) async {
      final handle = tester.ensureSemantics();
      final router = _createRouter('/settings');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Ecran des parametres Kita',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
