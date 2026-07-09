import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/api_key_settings_screen.dart';
import '../../features/settings/presentation/diagnostic_screen.dart';
import '../../features/settings/presentation/forget_screen.dart';
import '../../features/settings/presentation/memory_view_placeholder.dart';
import '../../features/settings/presentation/plugin_manager_placeholder.dart';
import '../../features/settings/presentation/settings_placeholder.dart';
import '../../features/shell/presentation/kita_shell.dart';

/// All app routes — extracted for reuse in tests.
final List<RouteBase> kitaRoutes = [
  GoRoute(
    path: '/',
    builder: (context, state) => const KitaShell(),
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
        builder: (context, state) => const ForgetScreen(),
      ),
      GoRoute(
        path: 'diagnostic',
        builder: (context, state) => const DiagnosticScreen(),
      ),
      GoRoute(
        path: 'api-key',
        builder: (context, state) => const ApiKeySettingsScreen(),
      ),
    ],
  ),
];

/// Router provider — singleton GoRouter instance.
///
/// The Shell (`/`) handles both onboarding and normal operation.
/// When onboarding is not complete, the Shell enters conversational
/// onboarding mode — no redirect to a separate screen.
/// The `/onboarding` route is kept for legacy/test access.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: kitaRoutes,
    onException: (context, state, router) {
      router.go('/');
    },
  );
});
