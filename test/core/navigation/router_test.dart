import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kita/core/navigation/router.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/memory/di/providers.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/settings/presentation/api_key_settings_screen.dart';
import 'package:kita/features/settings/presentation/forget_screen.dart';
import 'package:kita/features/settings/presentation/memory_view_placeholder.dart';
import 'package:kita/features/settings/presentation/plugin_manager_placeholder.dart';
import 'package:kita/features/settings/presentation/settings_placeholder.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';

import '../../mocks/mock_tts_service.dart';

GoRouter _createRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: kitaRoutes,
  );
}

Widget _createTestApp(GoRouter router) {
  return ProviderScope(
    overrides: [
      hasActiveOnDemandProvider.overrideWithValue(false),
      // Mark onboarding complete so ShellOnboarding doesn't start TTS/STT
      onboardingNotifierProvider.overrideWith(_CompletedOnboarding.new),
      onboardingCompleteProvider
          .overrideWith(_TrueOnboardingComplete.new),
    ],
    // disableAnimations stops KitaOrb infinite animation (prevents pending timers)
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

/// Notifier that starts with onboarding complete.
class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() => const OnboardingState(
        step: OnboardingStep.complete,
        onboardingComplete: true,
      );
}

/// Boolean notifier that starts as true (onboarding already done).
class _TrueOnboardingComplete extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

void main() {
  group('Route resolution', () {
    testWidgets('/ resolves to KitaShell', (tester) async {
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      // KitaShell has repeating orb animation, cannot use pumpAndSettle
      await tester.pump();

      expect(find.byType(KitaShell), findsOneWidget);
    });

    testWidgets('/onboarding resolves to OnboardingScreen', (tester) async {
      final router = _createRouter('/onboarding');
      addTearDown(router.dispose);
      final mockTts = MockTTSService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(mockTts),
            detectedProfileProvider.overrideWith(
              (ref) => Stream.value(DetectedProfile.general),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
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

    testWidgets('/settings/forget resolves to ForgetScreen', (tester) async {
      final router = _createRouter('/settings/forget');
      addTearDown(router.dispose);

      // Keep the route test off the real encrypted DB: the ForgetScreen only
      // needs to render (it degrades gracefully while the vault loads).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasActiveOnDemandProvider.overrideWithValue(false),
            onboardingNotifierProvider.overrideWith(_CompletedOnboarding.new),
            onboardingCompleteProvider.overrideWith(_TrueOnboardingComplete.new),
            memoryVaultProvider.overrideWith(
              (ref) => Completer<MemoryVault>().future,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      // The vault stub never completes, so the screen stays in its loading
      // state (a spinner that would never let pumpAndSettle converge). A
      // single frame is enough to confirm the route resolved to ForgetScreen.
      await tester.pump();

      expect(find.byType(ForgetScreen), findsOneWidget);
    });

    testWidgets('/settings/api-key resolves to ApiKeySettingsScreen',
        (tester) async {
      final router = _createRouter('/settings/api-key');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(ApiKeySettingsScreen), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('navigate from / to /settings via router.go', (tester) async {
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      await tester.pump();

      router.go('/settings');
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
    testWidgets('KitaShell has semantics label', tags: ['accessibility'], (tester) async {
      final handle = tester.ensureSemantics();
      final router = _createRouter('/');
      addTearDown(router.dispose);

      await tester.pumpWidget(_createTestApp(router));
      // KitaShell has repeating orb animation, cannot use pumpAndSettle
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Écran principal Kita',
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
