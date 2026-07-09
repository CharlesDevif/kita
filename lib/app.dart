import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mix/mix.dart';

import 'core/navigation/router.dart';
import 'core/theme/brightness_provider.dart';
import 'core/theme/kita_theme.dart';
import 'features/memory/di/providers.dart';
import 'features/orchestration/di/providers.dart';

/// Root widget — MixTheme + MaterialApp.router with go_router.
class KitaApp extends ConsumerWidget {
  const KitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessModeProvider);
    final router = ref.watch(routerProvider);

    // Kick off non-blocking, app-wide background initialization once at the
    // root (not in KitaShell, so widget tests of the Shell stay DB-free):
    // - register cloud AI providers from any stored API keys (local-first:
    //   no-op when none are configured);
    // - start the automatic data-retention cleanup (30-day policy);
    // - grant the storage consent required by saveEpisode/setPreference
    //   (without it, every memory write fails silently at runtime).
    // These are keepAlive providers; reading them is enough to trigger them
    // and any errors stay contained in their AsyncValue.
    ref.read(cloudProvidersInitProvider);
    ref.read(autoCleanupProvider);
    ref.read(memoryConsentBootstrapProvider);

    return MixTheme(
      data: buildKitaMixTheme(brightness),
      child: MaterialApp.router(
        title: 'Kita',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          brightness: brightness,
          scaffoldBackgroundColor: brightness == Brightness.dark
              ? const Color(0xFF1A1A2E)
              : const Color(0xFFF8FAFC),
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}
