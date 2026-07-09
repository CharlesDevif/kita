import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/data/providers/claude_provider.dart';
import '../../ai/data/providers/openai_provider.dart';
import '../../memory/di/providers.dart';
import '../../onboarding/presentation/api_key_setup_step.dart';
import '../../orchestration/di/providers.dart';

/// Accessible settings screen to configure the AI provider / API key outside
/// the onboarding flow.
///
/// Reuses [ApiKeySetupStep] with the same callbacks as the onboarding path:
/// the key is validated against the real provider API before it is stored in
/// the encrypted vault, and the live AI router is hot-reloaded so cloud
/// providers become available immediately.
class ApiKeySettingsScreen extends ConsumerWidget {
  const ApiKeySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      label: 'Écran de configuration de l\'intelligence artificielle',
      child: Scaffold(
        appBar: AppBar(title: const Text('Intelligence artificielle')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ApiKeySetupStep(
              onComplete: (_) {
                if (context.canPop()) context.pop();
              },
              // Validate the key against the real provider API before accepting
              // it, so the user isn't told "success" for a bad key.
              onValidateKey: (provider, key) async {
                final probe = provider == 'anthropic'
                    ? ClaudeProvider(apiKey: key)
                    : OpenAIProvider(apiKey: key);
                final result = await probe.validateApiKey(key);
                return result.isSuccess;
              },
              // Persist the validated key in the encrypted secure vault and
              // hot-load the matching cloud provider into the live AI router.
              onStoreKey: (provider, key) async {
                final repo =
                    await ref.read(preferencesRepositoryProvider.future);
                await repo.setApiKey(provider, key);
                ref.invalidate(cloudProvidersInitProvider);
              },
            ),
          ),
        ),
      ),
    );
  }
}
