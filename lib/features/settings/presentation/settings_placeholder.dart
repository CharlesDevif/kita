import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder for Settings screen — will be replaced in E9.
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ecran des parametres Kita',
      child: Scaffold(
        appBar: AppBar(title: const Text('Parametres')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Settings — Placeholder'),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/plugins'),
                  child: const Text('Plugins'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/memory'),
                  child: const Text('Memoire'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/forget'),
                  child: const Text("Droit à l'oubli"),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/api-key'),
                  child: const Text('Configurer l\'intelligence artificielle'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/journal'),
                  child: const Text('Journal de bord'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Retour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
