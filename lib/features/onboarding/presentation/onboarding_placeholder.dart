import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder for Onboarding flow — will be replaced in E9.
class OnboardingPlaceholder extends StatelessWidget {
  const OnboardingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Ecran d'accueil et configuration initiale",
      child: Scaffold(
        appBar: AppBar(title: const Text('Onboarding')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Onboarding — Placeholder'),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
