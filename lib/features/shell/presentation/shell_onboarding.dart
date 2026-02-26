import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/multi_modal/profile_adapter_impl.dart';
import '../../../shared/multi_modal/profile_adapter_provider.dart';
import '../../io/data/providers/stt_providers.dart';
import '../../io/data/providers/tts_providers.dart';
import '../../io/domain/speech_event.dart';
import '../../io/domain/tts_service.dart';
import '../../onboarding/di/providers.dart';
import '../../onboarding/domain/permission_storytelling.dart';
import '../../onboarding/domain/profile_detection.dart';
import '../../orchestration/di/providers.dart';
import '../../orchestration/domain/models/raw_input.dart';

/// Conversational onboarding steps within the Shell.
enum _ConversationStep {
  /// Request mic permission silently, then greet.
  greeting,

  /// Ask for camera permission via conversation.
  cameraPermission,

  /// "Magic moment" — user says "décris".
  magicMoment,

  /// Onboarding complete.
  done,
}

/// Conversational onboarding that runs inside the Shell viewport.
///
/// Instead of a separate onboarding screen, Marie opens the app and lands
/// in the Shell. Kita speaks to her, they have a conversation, and the
/// onboarding happens naturally through voice interaction.
///
/// Flow:
/// 1. Request mic permission silently, then greet: "Bonjour, je suis Kita..."
/// 2. STT listens for name -> capture or skip on timeout
/// 3. Ask camera permission conversationally
/// 4. Magic moment: "dis 'décris'" -> route through orchestrator
/// 5. Mark onboarding complete -> Shell returns to normal
///
/// Fallback: if STT is unavailable, buttons appear in the viewport.
class ShellOnboarding extends ConsumerStatefulWidget {
  const ShellOnboarding({super.key});

  @override
  ConsumerState<ShellOnboarding> createState() => _ShellOnboardingState();
}

class _ShellOnboardingState extends ConsumerState<ShellOnboarding> {
  static final _log = KitaLogger('ShellOnboarding');

  _ConversationStep _step = _ConversationStep.greeting;

  /// Guard against concurrent voice cycles.
  bool _voiceActive = false;

  /// TTS completion listener for the speak-then-listen pattern.
  StreamSubscription<TtsSpeechEvent>? _speechSub;

  /// Timeout for STT listening.
  Timer? _listenTimer;

  /// Whether the greeting step has been initiated.
  bool _greetingStarted = false;

  /// Captured user name (may be null if skipped).
  String? _capturedName;

  /// Status message displayed in the viewport.
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startGreeting();
    });
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _speechSub = null;
    _listenTimer?.cancel();
    _listenTimer = null;
    _voiceActive = false;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Voice helpers
  // ---------------------------------------------------------------------------

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

  /// Speak [prompt] via TTS, then auto-start STT when TTS completes.
  /// Calls [onTranscript] with the final transcript.
  /// On [timeout], calls [onTimeout] if provided.
  void _speakThenListen({
    required String prompt,
    required void Function(String transcript) onTranscript,
    VoidCallback? onTimeout,
    Duration timeout = const Duration(seconds: 8),
  }) {
    if (_voiceActive) return;
    _voiceActive = true;

    final tts = ref.read(ttsServiceProvider);
    final stt = ref.read(sttServiceProvider);

    _speechSub?.cancel();
    _speechSub = tts.speechEvents.listen((event) {
      if (event.type == TtsSpeechEventType.completed &&
          event.text == prompt) {
        _speechSub?.cancel();
        _speechSub = null;

        if (!mounted) {
          _voiceActive = false;
          return;
        }

        if (!stt.isAvailable) {
          _voiceActive = false;
          return; // STT unavailable — buttons remain as fallback
        }

        _listenTimer?.cancel();
        _listenTimer = Timer(timeout, () {
          unawaited(stt.stopRecognition());
          _voiceActive = false;
          if (mounted) onTimeout?.call();
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
          _log.error('STT failed during onboarding', error: e);
          _voiceActive = false;
          return const Result<void>.success(null);
        }));
      }
    });

    unawaited(tts.speak(prompt, priority: TTSPriority.urgent));
  }

  /// Speak text via TTS without listening afterwards.
  void _speakOnly(String text) {
    final tts = ref.read(ttsServiceProvider);
    unawaited(tts.speak(text, priority: TTSPriority.urgent));
  }

  // ---------------------------------------------------------------------------
  // Step 1: Greeting
  // ---------------------------------------------------------------------------

  Future<void> _startGreeting() async {
    if (_greetingStarted) return;
    _greetingStarted = true;

    // Silent profile detection (screenReader -> blind profile)
    _detectProfile();

    // Announce mic permission before the OS dialog.
    // We wait for TTS completion so the user hears the full message
    // before the OS dialog pops up.
    final tts = ref.read(ttsServiceProvider);
    const micAnnouncement =
        'Bonjour ! Je vais te demander l\'acces au micro pour pouvoir '
        't\'ecouter. Appuie sur Autoriser quand le dialog apparait.';
    _log.info('Announcing mic permission request');
    setState(() {
      _statusMessage = micAnnouncement;
    });

    // Set up listener BEFORE speaking (broadcast stream — events lost if no listener).
    // Wrapped in try-catch: if TTS engine doesn't emit events or stream closes,
    // we still proceed (the announcement was still spoken).
    try {
      final micAnnounceDone = tts.speechEvents
          .where((e) =>
              e.type == TtsSpeechEventType.completed &&
              e.text == micAnnouncement)
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () {
        return TtsSpeechEvent.completed(text: micAnnouncement);
      });
      unawaited(tts.speak(micAnnouncement, priority: TTSPriority.urgent));
      await micAnnounceDone;
    } catch (e) {
      // TTS may not emit completion events — proceed anyway
      _log.info('TTS completion wait skipped');
      unawaited(tts.speak(micAnnouncement, priority: TTSPriority.urgent));
    }

    if (!mounted) return;

    // Now request mic permission — OS dialog appears
    _log.info('Requesting mic permission');
    try {
      final requester = ref.read(permissionRequesterProvider);
      final status = await requester.request(KitaPermission.microphone);
      _log.info('Mic permission: ${status.name}');
    } catch (e) {
      _log.error('Mic permission request failed', error: e);
    }

    if (!mounted) return;

    _speakThenListen(
      prompt:
          'Parfait ! Je suis Kita, ton assistante. Comment tu t\'appelles ?',
      onTranscript: (transcript) {
        final lower = transcript.toLowerCase().trim();
        if (lower.contains('passer') || lower.contains('passe')) {
          _log.info('Name skipped via voice');
          _advanceToCameraPermission();
        } else {
          final words = transcript.trim().split(RegExp(r'\s+'));
          final first = words.first;
          _capturedName = first[0].toUpperCase() + first.substring(1);
          _log.info('Name captured via voice');
          ref
              .read(onboardingNotifierProvider.notifier)
              .setUserName(_capturedName!);
          _advanceToCameraPermission();
        }
      },
      onTimeout: () {
        _log.info('Name capture timed out, skipping');
        _advanceToCameraPermission();
      },
    );

    setState(() {
      _statusMessage =
          'Parfait ! Je suis Kita, ton assistante. Comment tu t\'appelles ?';
    });
  }

  void _detectProfile() {
    final detected = ref.read(detectedProfileProvider).asData?.value;
    if (detected != null) {
      final userProfile = switch (detected.profile) {
        AccessibilityProfile.blind => UserProfile.aveugle,
        AccessibilityProfile.lowVision => UserProfile.standard,
        AccessibilityProfile.general => UserProfile.standard,
      };
      ref.read(userProfileProvider.notifier).setProfile(userProfile);

      // Also select profile in onboarding notifier (installs pack)
      unawaited(ref
          .read(onboardingNotifierProvider.notifier)
          .selectProfile(detected.profile)
          .catchError((Object e) {
        _log.error('Profile selection failed', error: e);
      }));
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2: Camera permission
  // ---------------------------------------------------------------------------

  void _advanceToCameraPermission() {
    if (!mounted) return;
    _cancelVoice();

    setState(() {
      _step = _ConversationStep.cameraPermission;
    });

    final greeting = _capturedName != null
        ? 'Enchantee $_capturedName. '
        : '';

    final prompt = '${greeting}Pour t\'aider, j\'ai besoin d\'acceder '
        'a ta camera. Tu permets ?';

    _speakThenListen(
      prompt: prompt,
      onTranscript: (transcript) {
        final lower = transcript.toLowerCase();
        if (lower.contains('oui') ||
            lower.contains('d\'accord') ||
            lower.contains('accord') ||
            lower.contains('ok') ||
            lower.contains('bien sur') ||
            lower.contains('vas-y') ||
            lower.contains('permets')) {
          _log.info('Camera permission accepted via voice');
          _requestCameraPermission();
        } else {
          _log.info('Camera permission declined via voice');
          _speakOnly(
            'Pas de souci, tu pourras l\'activer plus tard dans les reglages.',
          );
          // Small delay to let TTS start, then advance
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _advanceToMagicMoment();
          });
        }
      },
      onTimeout: () {
        _log.info('Camera permission timed out, skipping');
        _advanceToMagicMoment();
      },
    );

    setState(() {
      _statusMessage = prompt;
    });
  }

  Future<void> _requestCameraPermission() async {
    // Announce before the OS dialog and wait for TTS to finish.
    const cameraAnnouncement = 'Je lance la demande. Appuie sur Autoriser.';
    final tts = ref.read(ttsServiceProvider);
    try {
      final cameraAnnounceDone = tts.speechEvents
          .where((e) =>
              e.type == TtsSpeechEventType.completed &&
              e.text == cameraAnnouncement)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () {
        return TtsSpeechEvent.completed(text: cameraAnnouncement);
      });
      unawaited(
          tts.speak(cameraAnnouncement, priority: TTSPriority.urgent));
      await cameraAnnounceDone;
    } catch (e) {
      _log.info('TTS completion wait skipped for camera');
      unawaited(
          tts.speak(cameraAnnouncement, priority: TTSPriority.urgent));
    }

    if (!mounted) return;

    try {
      final requester = ref.read(permissionRequesterProvider);
      final status = await requester.request(KitaPermission.camera);
      _log.info('Camera permission: ${status.name}');

      if (status == PermissionRequestStatus.granted) {
        ref
            .read(onboardingNotifierProvider.notifier)
            .grantPermission('camera');
      }
    } catch (e) {
      _log.error('Camera permission request failed', error: e);
    }

    if (mounted) _advanceToMagicMoment();
  }

  // ---------------------------------------------------------------------------
  // Step 3: Magic moment
  // ---------------------------------------------------------------------------

  void _advanceToMagicMoment() {
    if (!mounted) return;
    _cancelVoice();

    setState(() {
      _step = _ConversationStep.magicMoment;
    });

    const prompt =
        'Parfait ! Essaie : dis decris et je te decrirai ce que je vois.';

    _speakThenListen(
      prompt: prompt,
      timeout: const Duration(seconds: 10),
      onTranscript: (transcript) {
        final lower = transcript.toLowerCase();
        if (lower.contains('decris') ||
            lower.contains('décris') ||
            lower.contains('describe')) {
          _log.info('Magic moment: describe triggered via voice');
          _triggerDescribe();
        } else {
          _log.info('Magic moment: unrecognized, completing');
          _completeOnboarding();
        }
      },
      onTimeout: () {
        _log.info('Magic moment timed out, completing');
        _completeOnboarding();
      },
    );

    setState(() {
      _statusMessage = prompt;
    });
  }

  void _triggerDescribe() {
    setState(() {
      _statusMessage = 'Je regarde...';
    });

    // Route "decris" through the orchestrator if available.
    // The orchestrator may not be fully initialized during onboarding,
    // so we guard the call.
    try {
      final orchestrator = ref.read(kitaOrchestratorProvider);
      final clock = ref.read(clockProvider);
      unawaited(orchestrator
          .handleInput(RawInput.voice('decris', clock: clock))
          .catchError((Object e) {
        _log.error('Describe via orchestrator failed', error: e);
      }));
    } catch (e) {
      _log.error('Could not access orchestrator', error: e);
    }

    // After triggering describe, wait a moment then complete
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _speakOnly('Voila ! Je suis prete. Demande-moi ce que tu veux.');
        setState(() {
          _statusMessage =
              'Je suis prete. Demande-moi ce que tu veux.';
        });
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) _completeOnboarding();
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Step 4: Complete
  // ---------------------------------------------------------------------------

  void _completeOnboarding() {
    if (!mounted) return;
    _cancelVoice();
    _log.info('Onboarding complete');

    ref.read(onboardingNotifierProvider.notifier).completeOnboarding();

    setState(() {
      _step = _ConversationStep.done;
      _statusMessage = '';
    });
  }

  // ---------------------------------------------------------------------------
  // Fallback button handlers
  // ---------------------------------------------------------------------------

  void _onContinuePressed() {
    _cancelVoice();
    switch (_step) {
      case _ConversationStep.greeting:
        _advanceToCameraPermission();
      case _ConversationStep.cameraPermission:
        _requestCameraPermission();
      case _ConversationStep.magicMoment:
        _triggerDescribe();
      case _ConversationStep.done:
        break;
    }
  }

  void _onSkipPressed() {
    _cancelVoice();
    switch (_step) {
      case _ConversationStep.greeting:
        _advanceToCameraPermission();
      case _ConversationStep.cameraPermission:
        _advanceToMagicMoment();
      case _ConversationStep.magicMoment:
        _completeOnboarding();
      case _ConversationStep.done:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_step == _ConversationStep.done) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status message (liveRegion for screen readers)
          if (_statusMessage.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                _statusMessage,
                key: const Key('onboarding_status'),
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          // Fallback buttons (always visible — critical for no-STT)
          if (_step != _ConversationStep.done) _buildFallbackButtons(),
        ],
      ),
    );
  }

  Widget _buildFallbackButtons() {
    final continueLabel = switch (_step) {
      _ConversationStep.greeting => 'Continuer',
      _ConversationStep.cameraPermission => 'Autoriser la camera',
      _ConversationStep.magicMoment => 'Essayer decris',
      _ConversationStep.done => '',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: continueLabel,
            child: FilledButton(
              key: const Key('onboarding_continue'),
              onPressed: _onContinuePressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
              ),
              child: Text(continueLabel),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: KitaAccessibility.touchTargetMin,
          child: Semantics(
            button: true,
            label: 'Passer cette etape',
            child: OutlinedButton(
              key: const Key('onboarding_skip'),
              onPressed: _onSkipPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: const BorderSide(color: Color(0xFF94A3B8)),
              ),
              child: const Text('Passer'),
            ),
          ),
        ),
      ],
    );
  }
}
