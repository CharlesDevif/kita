import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../io/data/providers/tts_providers.dart';
import '../../io/domain/tts_service.dart';
import '../di/providers.dart';
import '../domain/onboarding_state.dart';
import '../domain/profile_detection.dart';
import 'api_key_setup_step.dart';
import 'caregiver_flow.dart';
import 'magic_moment_step.dart';
import 'permission_step.dart';
import 'profile_selector.dart';

final _log = KitaLogger('Onboarding');

/// Main onboarding screen — vocal-first flow.
///
/// Steps: welcome -> name -> profile -> installing
/// Each step is accessible with Semantics wrappers.
/// Kita speaks first if a screen reader is active.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _hasSpoken = false;
  bool _showApiKeySetup = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// Speak a greeting when screen reader is active.
  void _speakGreeting(TTSService tts, bool screenReaderActive) {
    if (_hasSpoken) return;
    _hasSpoken = true;

    if (screenReaderActive) {
      _log.info('Screen reader active, speaking greeting');
      unawaited(tts.speak(
        'Bonjour, je suis Kita. Je suis là pour t\'aider.',
        priority: TTSPriority.urgent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingNotifierProvider);
    final detectedProfile = ref.watch(detectedProfileProvider);
    final theme = Theme.of(context);

    // Speak greeting on welcome step when screen reader is active
    if (onboardingState.step == OnboardingStep.welcome) {
      final screenReaderActive =
          detectedProfile.asData?.value.screenReader ?? false;
      final tts = ref.read(ttsServiceProvider);
      _speakGreeting(tts, screenReaderActive);
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildStep(context, onboardingState, theme),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    return switch (state.step) {
      OnboardingStep.detecting => _buildDetecting(theme),
      OnboardingStep.welcome => _buildWelcome(context, state, theme),
      OnboardingStep.modeChoice => _buildModeChoice(context, state, theme),
      OnboardingStep.profile => _buildProfile(context, state, theme),
      OnboardingStep.permissions => _buildPermissions(context, state, theme),
      OnboardingStep.magic => _buildMagicMoment(context, state, theme),
      OnboardingStep.caregiver => _buildCaregiverFlow(context, state, theme),
      OnboardingStep.complete => _buildComplete(context, state, theme),
    };
  }

  Widget _buildDetecting(ThemeData theme) {
    return Semantics(
      label: 'Détection de l\'accessibilité en cours',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Préparation...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Bonjour, je suis Kita.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          child: Text(
            'Je suis là pour t\'aider au quotidien.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        // Name input field
        Semantics(
          label: 'Ton prénom. Champ de saisie.',
          textField: true,
          child: TextField(
            key: const Key('name_input'),
            controller: _nameController,
            focusNode: _nameFocusNode,
            decoration: const InputDecoration(
              labelText: 'Ton prénom',
              hintText: 'Comment tu t\'appelles ?',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitName(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Continuer',
            child: FilledButton(
              key: const Key('continue_welcome'),
              onPressed: _submitName,
              child: const Text('Continuer'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  void _submitName() {
    final name = _nameController.text.trim();
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    if (name.isNotEmpty) {
      notifier.setUserName(name);
    }
    notifier.completeWelcome();

    // Speak transition if screen reader is active
    final screenReaderActive =
        ref.read(detectedProfileProvider).asData?.value.screenReader ?? false;
    if (screenReaderActive) {
      final tts = ref.read(ttsServiceProvider);
      final greeting =
          name.isNotEmpty ? 'Enchanté $name.' : '';
      unawaited(tts.speak(
        '$greeting Choisis ton profil d\'accessibilité.',
        priority: TTSPriority.standard,
      ));
    }
  }

  Widget _buildModeChoice(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Pour qui ?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          child: Text(
            'Tu configures Kita pour toi ou pour quelqu\'un d\'autre ?',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Pour moi. Configurer Kita pour moi-même.',
            child: FilledButton(
              key: const Key('mode_for_me'),
              onPressed: () {
                _log.info('Mode choice: standard (for self)');
                ref.read(onboardingNotifierProvider.notifier).chooseStandardMode();
              },
              child: const Text('Pour moi'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: KitaAccessibility.touchTargetMin,
          child: Semantics(
            button: true,
            label: 'Pour quelqu\'un d\'autre. Configurer Kita en tant qu\'aidant.',
            child: OutlinedButton(
              key: const Key('mode_for_other'),
              onPressed: () {
                _log.info('Mode choice: caregiver (for someone else)');
                ref
                    .read(onboardingNotifierProvider.notifier)
                    .chooseCaregiverMode();
              },
              child: const Text('Pour quelqu\'un d\'autre'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildCaregiverFlow(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    final tts = ref.read(ttsServiceProvider);
    return CaregiverFlow(
      onComplete: (userName, profile) {
        final notifier = ref.read(onboardingNotifierProvider.notifier);
        notifier.setUserName(userName);
        notifier.selectProfile(profile).then((_) {
          notifier.completeCaregiverOnboarding();
        });
      },
      onSpeak: (text) async {
        unawaited(tts.speak(text, priority: TTSPriority.standard));
      },
    );
  }

  Widget _buildProfile(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    final detectedProfile =
        state.detectedProfile?.profile ?? AccessibilityProfile.general;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        ProfileSelector(
          selectedProfile: detectedProfile,
          onProfileSelected: (profile) async {
            final notifier = ref.read(onboardingNotifierProvider.notifier);
            await notifier.selectProfile(profile);

            // Speak confirmation
            final screenReaderActive =
                state.detectedProfile?.screenReader ?? false;
            if (screenReaderActive) {
              final tts = ref.read(ttsServiceProvider);
              unawaited(tts.speak(
                'Profil ${profile.name} sélectionné. Configuration en cours.',
                priority: TTSPriority.standard,
              ));
            }
          },
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPermissions(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    final profile =
        state.detectedProfile?.profile ?? AccessibilityProfile.general;
    final storytelling = ref.read(permissionStorytellingProvider);

    return PermissionStep(
      profile: profile,
      storytelling: storytelling,
      onComplete: (results) {
        final notifier = ref.read(onboardingNotifierProvider.notifier);
        // Record granted permissions in state
        for (final result in results) {
          if (result.isGranted) {
            notifier.grantPermission(result.permission.name);
          }
        }
        notifier.completePermissions();
      },
    );
  }

  Widget _buildMagicMoment(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    if (_showApiKeySetup) {
      return ApiKeySetupStep(
        onComplete: (mode) {
          _log.info('Provider mode selected: ${mode.name}');
          final notifier = ref.read(onboardingNotifierProvider.notifier);
          notifier.completeOnboarding();
        },
      );
    }

    final tts = ref.read(ttsServiceProvider);

    return MagicMomentStep(
      onComplete: () {
        setState(() => _showApiKeySetup = true);
      },
      onSpeak: (text) async {
        unawaited(tts.speak(text, priority: TTSPriority.standard));
      },
    );
  }

  Widget _buildComplete(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    // Navigate to main app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/');
      }
    });

    return Semantics(
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Configuration terminée...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
