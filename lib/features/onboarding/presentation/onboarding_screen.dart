import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/multi_modal/profile_adapter_impl.dart';
import '../../../shared/multi_modal/profile_adapter_provider.dart';
import '../../io/data/providers/stt_providers.dart';
import '../../io/data/providers/tts_providers.dart';
import '../../io/domain/speech_event.dart';
import '../../io/domain/tts_service.dart';
import '../di/providers.dart';
import '../domain/onboarding_state.dart';
import '../domain/permission_storytelling.dart';
import '../domain/profile_detection.dart';
import 'api_key_setup_step.dart';
import 'caregiver_flow.dart';
import 'magic_moment_step.dart';
import 'permission_step.dart';
import 'profile_selector.dart';

final _log = KitaLogger('Onboarding');

/// Main onboarding screen — vocal-first flow.
///
/// Steps: welcome -> modeChoice -> profile -> permissions -> magic -> complete.
/// Each step is accessible with Semantics wrappers.
/// Kita speaks unconditionally (voice-first, regardless of screen reader).
///
/// Voice pattern: TTS speaks prompt -> waits for TTS completion event ->
/// auto-starts STT -> parses transcript for keywords -> advances or retries.
/// Buttons remain as visual fallback for sighted users.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  /// Guard against concurrent voice cycles.
  bool _voiceActive = false;

  /// TTS completion listener for the speak-then-listen pattern.
  StreamSubscription<TtsSpeechEvent>? _speechSub;

  /// Timeout for STT listening.
  Timer? _listenTimer;

  /// Prevents re-triggering voice for the same step on rebuilds.
  OnboardingStep? _lastSpokenStep;

  /// Signal for MagicMomentStep to auto-trigger describe.
  bool _magicDescribeTriggered = false;

  bool _showApiKeySetup = false;
  bool _navigatedToHome = false;

  @override
  void dispose() {
    // Clean up voice state directly (ref is unavailable during unmount).
    // STT/TTS lifecycle is managed by their providers via ref.onDispose.
    _speechSub?.cancel();
    _speechSub = null;
    _listenTimer?.cancel();
    _listenTimer = null;
    _voiceActive = false;
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Voice-first: _speakThenListen pattern
  // ---------------------------------------------------------------------------

  /// Cancel all active voice operations (TTS listener, STT, timer).
  void _cancelVoice() {
    _speechSub?.cancel();
    _speechSub = null;
    _listenTimer?.cancel();
    _listenTimer = null;
    final stt = ref.read(sttServiceProvider);
    if (stt.isListening) {
      unawaited(stt.stopRecognition());
    }
    _voiceActive = false;
  }

  /// Central voice-first pattern:
  /// 1. TTS speaks [prompt]
  /// 2. Waits for TTS completion event (matched by text)
  /// 3. Auto-starts STT
  /// 4. Calls [onTranscript] with the final transcript
  /// 5. On timeout, retries up to [maxRetries] times
  /// 6. If STT unavailable, falls back to buttons (no-op).
  void _speakThenListen({
    required String prompt,
    required void Function(String transcript) onTranscript,
    Duration timeout = const Duration(seconds: 8),
    int maxRetries = 2,
  }) {
    if (_voiceActive) return;
    _voiceActive = true;
    _speakThenListenLoop(
      prompt: prompt,
      onTranscript: onTranscript,
      timeout: timeout,
      maxRetries: maxRetries,
      attempt: 0,
    );
  }

  void _speakThenListenLoop({
    required String prompt,
    required void Function(String transcript) onTranscript,
    required Duration timeout,
    required int maxRetries,
    required int attempt,
  }) {
    if (!mounted) {
      _voiceActive = false;
      return;
    }

    final tts = ref.read(ttsServiceProvider);
    final stt = ref.read(sttServiceProvider);

    // Listen for TTS completion before starting STT.
    // Text matching prevents reacting to stale events from a previous step.
    _speechSub?.cancel();
    _speechSub = tts.speechEvents.listen((event) {
      if (event.type == TtsSpeechEventType.completed &&
          event.text == prompt) {
        _speechSub?.cancel();
        _speechSub = null;

        if (!mounted || !stt.isAvailable) {
          _voiceActive = false;
          return; // STT unavailable — buttons remain as fallback
        }

        // Start STT with timeout
        _listenTimer?.cancel();
        _listenTimer = Timer(timeout, () {
          unawaited(stt.stopRecognition());
          if (attempt < maxRetries && mounted) {
            _speakThenListenLoop(
              prompt: prompt,
              onTranscript: onTranscript,
              timeout: timeout,
              maxRetries: maxRetries,
              attempt: attempt + 1,
            );
          } else {
            _voiceActive = false;
          }
        });

        unawaited(stt.startRecognition(onResult: (transcript, isFinal) {
          if (isFinal && transcript.isNotEmpty && mounted) {
            _listenTimer?.cancel();
            _listenTimer = null;
            unawaited(stt.stopRecognition());
            _voiceActive = false;
            onTranscript(transcript);
          }
        }).catchError((Object e) {
          _log.error('STT failed during voice flow', error: e);
          _voiceActive = false;
          return const Result<void>.success(null);
        }));
      }
    });

    // Speak the prompt
    unawaited(tts.speak(prompt, priority: TTSPriority.urgent));
  }

  // ---------------------------------------------------------------------------
  // Per-step voice triggers
  // ---------------------------------------------------------------------------

  /// Called from build() — dispatches voice flow for the current step.
  /// Guarded by [_lastSpokenStep] to prevent re-triggering on rebuild.
  void _triggerVoiceForStep(OnboardingStep step) {
    if (_lastSpokenStep == step) return;
    _lastSpokenStep = step;
    _cancelVoice();

    switch (step) {
      case OnboardingStep.welcome:
        unawaited(_startWelcomeVoice());
      case OnboardingStep.modeChoice:
        _startModeChoiceVoice();
      case OnboardingStep.profile:
        _startProfileVoice();
      case OnboardingStep.magic:
        _log.info('Voice flow: magic moment');
        // Voice setup happens in _buildMagicMoment's onSpeak callback
        // via _setupMagicVoiceListener().
      case OnboardingStep.detecting:
      case OnboardingStep.permissions:
      case OnboardingStep.caregiver:
      case OnboardingStep.complete:
        break; // These steps handle their own voice or don't need it
    }
  }

  Future<void> _startWelcomeVoice() async {
    _log.info('Voice flow: welcome — requesting mic permission');

    // Request microphone permission early so STT can work from step 1.
    // The permissions step will see it already granted and skip the OS dialog.
    try {
      final requester = ref.read(permissionRequesterProvider);
      final status = await requester.request(KitaPermission.microphone);
      _log.info('Early mic permission: ${status.name}');
    } catch (e) {
      _log.error('Early mic permission request failed', error: e);
    }

    if (!mounted) return;

    _speakThenListen(
      prompt: 'Bonjour, je suis Kita. Comment tu t\'appelles ? '
          'Dis ton prénom, ou dis passer.',
      onTranscript: (transcript) {
        final lower = transcript.toLowerCase().trim();
        if (lower.contains('passer') ||
            lower.contains('passe') ||
            lower == 'skip') {
          _submitName();
        } else {
          final words = transcript.trim().split(RegExp(r'\s+'));
          final first = words.first;
          _nameController.text = first[0].toUpperCase() + first.substring(1);
          _submitName();
        }
      },
    );
  }

  void _startModeChoiceVoice() {
    _log.info('Voice flow: mode choice');
    final name = ref.read(onboardingNotifierProvider).userName;
    final greeting =
        name != null && name.isNotEmpty ? 'Enchanté $name. ' : '';
    _speakThenListen(
      prompt: '${greeting}C\'est pour toi ou pour quelqu\'un d\'autre ? '
          'Dis pour moi, ou pour quelqu\'un.',
      onTranscript: (transcript) {
        _cancelVoice();
        final lower = transcript.toLowerCase();
        if (lower.contains('autre') || lower.contains('quelqu')) {
          _log.info('Voice: caregiver mode');
          ref.read(onboardingNotifierProvider.notifier).chooseCaregiverMode();
        } else {
          _log.info('Voice: standard mode');
          ref.read(onboardingNotifierProvider.notifier).chooseStandardMode();
        }
      },
    );
  }

  void _startProfileVoice() {
    _log.info('Voice flow: profile');
    _speakThenListen(
      prompt: 'Quel est ton profil ? Dis aveugle, malvoyant, ou général.',
      onTranscript: (transcript) {
        final lower = transcript.toLowerCase();
        AccessibilityProfile profile;
        if (lower.contains('aveugle')) {
          profile = AccessibilityProfile.blind;
        } else if (lower.contains('malvoyant')) {
          profile = AccessibilityProfile.lowVision;
        } else {
          profile = AccessibilityProfile.general;
        }
        _log.info('Voice: profile ${profile.name}');
        _cancelVoice();
        _selectProfile(profile);
      },
    );
  }

  /// Set up STT listener for "décris" after MagicMomentStep speaks.
  /// Called from the onSpeak callback in _buildMagicMoment.
  void _setupMagicVoiceListener(String spokenText) {
    final tts = ref.read(ttsServiceProvider);
    final stt = ref.read(sttServiceProvider);
    if (_voiceActive || !stt.isAvailable) return;
    _voiceActive = true;

    _speechSub?.cancel();
    _speechSub = tts.speechEvents.listen((event) {
      if (event.type == TtsSpeechEventType.completed &&
          event.text == spokenText) {
        _speechSub?.cancel();
        _speechSub = null;

        if (!mounted) {
          _voiceActive = false;
          return;
        }

        _listenTimer?.cancel();
        _listenTimer = Timer(const Duration(seconds: 10), () {
          unawaited(stt.stopRecognition());
          _voiceActive = false;
        });

        unawaited(stt.startRecognition(onResult: (transcript, isFinal) {
          if (isFinal && transcript.isNotEmpty && mounted) {
            final lower = transcript.toLowerCase();
            if (lower.contains('décris') ||
                lower.contains('decris') ||
                lower.contains('describe')) {
              _listenTimer?.cancel();
              _listenTimer = null;
              unawaited(stt.stopRecognition());
              _voiceActive = false;
              setState(() => _magicDescribeTriggered = true);
            }
          }
        }).catchError((Object e) {
          _log.error('STT failed during magic moment', error: e);
          _voiceActive = false;
          return const Result<void>.success(null);
        }));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingNotifierProvider);
    // Watch to keep the stream subscription alive (triggers detecting -> welcome)
    ref.watch(detectedProfileProvider);
    final theme = Theme.of(context);

    // Voice-first: trigger voice flow for current step
    _triggerVoiceForStep(onboardingState.step);

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
            'Comment tu t\'appelles ?',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // --- Voice-first: large mic button for name ---
        Center(
          child: SizedBox(
            width: 80,
            height: 80,
            child: Semantics(
              button: true,
              label: _voiceActive
                  ? 'Écoute en cours. Dis ton prénom.'
                  : 'Appuie pour dire ton prénom',
              child: FilledButton(
                key: const Key('mic_name'),
                onPressed: _voiceActive
                    ? null
                    : () {
                        _cancelVoice();
                        _lastSpokenStep = null; // Allow re-trigger
                        _startWelcomeVoice();
                      },
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: _voiceActive
                      ? Colors.redAccent
                      : theme.colorScheme.primary,
                ),
                child: Icon(
                  _voiceActive ? Icons.hearing : Icons.mic,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        if (_voiceActive)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Je t\'écoute...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        const SizedBox(height: 24),

        // --- Fallback: text field for sighted users ---
        Semantics(
          label: 'Ou tape ton prénom ici. Champ de saisie.',
          textField: true,
          child: TextField(
            key: const Key('name_input'),
            controller: _nameController,
            focusNode: _nameFocusNode,
            decoration: const InputDecoration(
              labelText: 'Ou tape ton prénom',
              hintText: 'Comment tu t\'appelles ?',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitName(),
          ),
        ),
        const SizedBox(height: 16),

        // --- Two buttons: Continue + Skip ---
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: KitaAccessibility.touchTargetCritical,
                child: Semantics(
                  button: true,
                  label: 'Continuer avec ce prénom',
                  child: FilledButton(
                    key: const Key('continue_welcome'),
                    onPressed: _submitName,
                    child: const Text('Continuer'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: KitaAccessibility.touchTargetCritical,
              child: Semantics(
                button: true,
                label: 'Passer cette étape',
                child: OutlinedButton(
                  key: const Key('skip_name'),
                  onPressed: _submitName,
                  child: const Text('Passer'),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  void _submitName() {
    _cancelVoice();
    final name = _nameController.text.trim();
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    if (name.isNotEmpty) {
      notifier.setUserName(name);
    }
    notifier.completeWelcome();
    // Greeting is included in the mode choice voice prompt.
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
                _cancelVoice();
                _log.info('Mode choice: standard (for self)');
                ref
                    .read(onboardingNotifierProvider.notifier)
                    .chooseStandardMode();
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
            label:
                'Pour quelqu\'un d\'autre. Configurer Kita en tant qu\'aidant.',
            child: OutlinedButton(
              key: const Key('mode_for_other'),
              onPressed: () {
                _cancelVoice();
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

  /// Maps an onboarding [AccessibilityProfile] to a [UserProfile]
  /// for the ProfileAdapter output routing.
  static UserProfile _mapToUserProfile(AccessibilityProfile profile) {
    return switch (profile) {
      AccessibilityProfile.blind => UserProfile.aveugle,
      AccessibilityProfile.lowVision => UserProfile.standard,
      AccessibilityProfile.general => UserProfile.standard,
    };
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
          // Propagate to ProfileAdapter so output routing matches
          ref
              .read(userProfileProvider.notifier)
              .setProfile(_mapToUserProfile(profile));
          notifier.completeCaregiverOnboarding();
        }).catchError((Object e) {
          _log.error('Profile selection failed in caregiver flow', error: e);
          // Still propagate profile and continue — pack install may fail
          // but Kita remains usable with fallback defaults.
          ref
              .read(userProfileProvider.notifier)
              .setProfile(_mapToUserProfile(profile));
          notifier.completeCaregiverOnboarding();
        });
      },
      onSpeak: (text) async {
        unawaited(tts.speak(text, priority: TTSPriority.standard));
      },
    );
  }

  /// Selects a profile and propagates to ProfileAdapter.
  Future<void> _selectProfile(AccessibilityProfile profile) async {
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    try {
      await notifier.selectProfile(profile);
    } catch (e) {
      _log.error('Profile selection failed', error: e);
      // Continue — pack install may fail but Kita remains usable.
    }

    if (!mounted) return;

    // Propagate to ProfileAdapter so output routing matches
    ref
        .read(userProfileProvider.notifier)
        .setProfile(_mapToUserProfile(profile));

    // Speak confirmation — voice-first
    final tts = ref.read(ttsServiceProvider);
    unawaited(tts.speak(
      'Profil ${profile.name} sélectionné. Configuration en cours.',
      priority: TTSPriority.standard,
    ));
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
          onProfileSelected: (profile) {
            _cancelVoice();
            _selectProfile(profile);
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
    final requester = ref.read(permissionRequesterProvider);
    final tts = ref.read(ttsServiceProvider);

    return PermissionStep(
      profile: profile,
      storytelling: storytelling,
      permissionRequester: requester,
      onSpeak: (text) async {
        unawaited(tts.speak(text, priority: TTSPriority.standard));
      },
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
      autoTriggerDescribe: _magicDescribeTriggered,
      onComplete: () {
        setState(() => _showApiKeySetup = true);
      },
      onSpeak: (text) async {
        unawaited(tts.speak(text, priority: TTSPriority.standard));
        // Voice-first: listen for "décris" after TTS completes
        _setupMagicVoiceListener(text);
      },
    );
  }

  Widget _buildComplete(
    BuildContext context,
    OnboardingState state,
    ThemeData theme,
  ) {
    // Navigate to main app (guarded to prevent accumulating callbacks)
    if (!_navigatedToHome) {
      _navigatedToHome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
    }

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
