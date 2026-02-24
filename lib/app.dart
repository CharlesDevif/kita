import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mix/mix.dart';

import 'core/navigation/router.dart';
import 'core/theme/brightness_provider.dart';
import 'core/theme/kita_theme.dart';

/// Root widget — MixTheme + MaterialApp.router with go_router.
class KitaApp extends ConsumerWidget {
  const KitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessModeProvider);
    final router = ref.watch(routerProvider);

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
