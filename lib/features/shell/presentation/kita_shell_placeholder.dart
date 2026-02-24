import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder for KitaShell — will be replaced in E8.
class KitaShellPlaceholder extends StatelessWidget {
  const KitaShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ecran principal Kita',
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Kita Shell — Placeholder'),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/settings'),
                  child: const Text('Parametres'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('Onboarding'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
