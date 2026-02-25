import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/di/providers.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/forget_placeholder.dart';
import '../../features/settings/presentation/memory_view_placeholder.dart';
import '../../features/settings/presentation/plugin_manager_placeholder.dart';
import '../../features/settings/presentation/settings_placeholder.dart';
import '../../features/shell/presentation/kita_shell_placeholder.dart';

/// All app routes — extracted for reuse in tests.
final List<RouteBase> kitaRoutes = [
  GoRoute(
    path: '/',
    builder: (context, state) => const KitaShellPlaceholder(),
  ),
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingScreen(),
  ),
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsPlaceholder(),
    routes: [
      GoRoute(
        path: 'plugins',
        builder: (context, state) => const PluginManagerPlaceholder(),
      ),
      GoRoute(
        path: 'memory',
        builder: (context, state) => const MemoryViewPlaceholder(),
      ),
      GoRoute(
        path: 'forget',
        builder: (context, state) => const ForgetPlaceholder(),
      ),
    ],
  ),
];

/// Router provider — singleton GoRouter instance with onboarding redirect.
///
/// Watches [onboardingCompleteProvider] from the onboarding feature.
/// Uses [onboardingRefreshListenableProvider] to trigger re-evaluation
/// of the redirect guard when onboarding state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final isOnboardingComplete = ref.watch(onboardingCompleteProvider);
  final refreshListenable = ref.watch(onboardingRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    routes: kitaRoutes,
    redirect: (context, state) {
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');

      if (!isOnboardingComplete && !isOnboardingRoute) {
        return '/onboarding';
      }
      if (isOnboardingComplete && isOnboardingRoute) {
        return '/';
      }
      return null;
    },
    onException: (context, state, router) {
      router.go('/');
    },
  );
});
