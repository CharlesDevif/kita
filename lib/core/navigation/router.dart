import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/onboarding_placeholder.dart';
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
    builder: (context, state) => const OnboardingPlaceholder(),
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

/// Provider that controls whether onboarding redirect is active.
///
/// Override this in your onboarding feature to wire the actual logic.
/// Default: onboarding is considered complete (no redirect).
final onboardingCompleteProvider = Provider<bool>((ref) => true);

/// Router provider — singleton GoRouter instance with onboarding redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final isOnboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
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
