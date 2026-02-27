import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/multi_modal/profile_adapter_impl.dart';
import '../../../shared/multi_modal/profile_adapter_provider.dart';
import '../../../core/utils/sentence_buffer.dart';
import '../../ai/data/providers/gemma_bridge.dart';
import '../../ai/domain/ai_request.dart';
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

  /// Timer for AI probe poll interval (so it can be cancelled on dispose).
  Timer? _probeTimer;

  /// Completer for the current probe poll delay (so dispose can unblock it).
  Completer<void>? _probePollCompleter;

  /// Whether the greeting step has been initiated.
  bool _greetingStarted = false;

  /// Captured user name (may be null if skipped).
  String? _capturedName;

  /// Whether AI pipeline is available for AI-driven conversation.
  bool _llmAvailable = false;

  /// Pre-generated "ready" message — computed while the AI pipeline is free,
  /// before the describe vision request occupies it.
  String? _pendingReadyMessage;

  /// Status message displayed in the viewport.
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initAndGreet();
    });
  }

  Future<void> _initAndGreet() async {
    // Always start with LLM disabled — greeting uses hardcoded text for
    // instant, reliable UX. We probe the AI pipeline in background; by the
    // time mic permission + greeting finish (~15s), Gemma warmup (~13s)
    // should be done and subsequent steps can use AI.
    _llmAvailable = false;
    _log.info('Starting onboarding with LLM disabled (will probe in background)');

    // Launch AI probe concurrently with the greeting flow.
    unawaited(_probeAIPipeline());

    if (mounted) unawaited(_startGreeting());
  }

  /// Probe the AI pipeline in background to check actual readiness.
  ///
  /// This runs concurrently with the greeting. It waits for Gemma warmup
  /// to complete (polling checkStatus), then sends a tiny request through
  /// the full pipeline (AIRouter → FallbackChain → Provider).
  /// If it succeeds, we enable LLM for subsequent onboarding steps.
  /// If it fails (Gemma still warming up, no providers), LLM stays disabled.
  Future<void> _probeAIPipeline() async {
    try {
      final aiRouter = ref.read(aiRouterProvider);
      if (aiRouter.availableProviders.isEmpty) {
        _log.info('AI probe: no providers registered');
        return;
      }

      // Wait for Gemma warmup to finish before probing.
      // Gemma warmup takes ~8s; if we send a request while _processing is
      // true, it throws "already processing". Poll with a 20s global timeout.
      final gemmaBridge = ref.read(gemmaBridgeProvider);
      const pollInterval = Duration(milliseconds: 500);
      const maxWait = Duration(seconds: 20);
      final deadline = DateTime.now().add(maxWait);

      var gemmaReady = false;
      while (DateTime.now().isBefore(deadline)) {
        final status = await gemmaBridge.checkStatus();
        if (status == GemmaModelStatus.ready) {
          _log.info('AI probe: Gemma is ready');
          gemmaReady = true;
          break;
        }
        if (status == GemmaModelStatus.error) {
          _log.info('AI probe: Gemma in error state, skipping');
          return;
        }
        // Still loading — wait before polling again.
        // Use a cancellable Timer + tracked Completer so dispose() can both
        // cancel the timer AND unblock the awaiting future.
        final completer = Completer<void>();
        _probePollCompleter = completer;
        _probeTimer?.cancel();
        _probeTimer = Timer(pollInterval, () {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        _probeTimer = null;
        _probePollCompleter = null;
        if (!mounted) return;
      }

      if (!mounted) return;

      if (!gemmaReady) {
        _log.info('AI probe: Gemma warmup timed out after 20s, skipping');
        return;
      }

      // Send a minimal request through the pipeline.
      final result = await aiRouter.route(
        const AIRequest(prompt: 'Dis bonjour.', maxTokens: 32),
      );

      if (!mounted) return;

      final success = result.map((r) {
        // Check it's not a brute alert (all providers failed).
        if (_isBruteAlert(r.content)) return false;
        return r.content.trim().isNotEmpty;
      }).getOrElse((_) => false);

      if (success) {
        _llmAvailable = true;
        _log.info('AI probe succeeded — LLM enabled for next steps');
      } else {
        _log.info('AI probe returned empty/brute-alert — LLM stays disabled');
      }
    } on Exception catch (e) {
      _log.warning('AI probe failed — LLM stays disabled', error: e);
    }
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _speechSub = null;
    _listenTimer?.cancel();
    _listenTimer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
    // Unblock any awaiting probe poll so the future doesn't hang.
    if (_probePollCompleter != null && !_probePollCompleter!.isCompleted) {
      _probePollCompleter!.complete();
    }
    _probePollCompleter = null;
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

    // Track the last partial result so we can use it on timeout.
    String lastPartial = '';

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

        _listenTimer?.cancel();
        _listenTimer = Timer(timeout, () {
          unawaited(stt.stopRecognition());
          _voiceActive = false;
          if (mounted) {
            // Use the last partial result if available, otherwise timeout.
            if (lastPartial.isNotEmpty) {
              _log.info('STT timeout, using last partial: "$lastPartial"');
              onTranscript(lastPartial);
            } else {
              onTimeout?.call();
            }
          }
        });

        _log.info('TTS completed, starting STT...');
        unawaited(stt.startRecognition(onResult: (transcript, isFinal) {
          _log.info('STT result: "$transcript" (final=$isFinal)');
          if (transcript.isNotEmpty) {
            lastPartial = transcript;
          }
          if (isFinal && transcript.isNotEmpty && mounted) {
            _listenTimer?.cancel();
            _listenTimer = null;
            unawaited(stt.stopRecognition());
            _voiceActive = false;
            onTranscript(transcript);
          }
        }).then((result) {
          if (result.isFailure) {
            _log.error('STT startRecognition failed: $result');
            _voiceActive = false;
          }
        }).catchError((Object e) {
          _log.error('STT failed during onboarding', error: e);
          _voiceActive = false;
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

  /// Stream LLM tokens → TTS sentence by sentence, then start STT.
  ///
  /// This is the streaming equivalent of [_speakThenListen]:
  /// - Streams LLM response token by token
  /// - Each complete sentence is spoken via TTS immediately (~1.5s to first)
  /// - When stream ends and last sentence is spoken, starts STT
  /// - Falls back to [_speakThenListen] if LLM is unavailable
  void _speakStreamThenListen({
    required String llmContext,
    required String fallbackPrompt,
    required void Function(String transcript) onTranscript,
    VoidCallback? onTimeout,
    Duration timeout = const Duration(seconds: 8),
  }) {
    if (_voiceActive) return;

    // If LLM is not available, fall back to the non-streaming path.
    if (!_llmAvailable) {
      _speakThenListen(
        prompt: fallbackPrompt,
        onTranscript: onTranscript,
        onTimeout: onTimeout,
        timeout: timeout,
      );
      setState(() {
        _statusMessage = fallbackPrompt;
      });
      return;
    }

    _voiceActive = true;

    final aiRouter = ref.read(aiRouterProvider);
    final tts = ref.read(ttsServiceProvider);

    final fullText = StringBuffer();
    String? lastSentence;

    final buffer = SentenceBuffer(
      onSentence: (sentence) {
        lastSentence = sentence;
        unawaited(tts.speak(sentence, priority: TTSPriority.urgent));
      },
    );

    const systemPrompt = '$_systemBase\n'
        'Genere UNIQUEMENT la phrase a dire a voix haute. '
        'Pas de JSON, pas de guillemets, juste la phrase.';

    // Track the last partial result so we can use it on timeout.
    String lastPartial = '';

    // Start streaming. When done, wait for last TTS sentence, then STT.
    unawaited(() async {
      try {
        final mergedPrompt = '$systemPrompt\n\n$llmContext';
        final request = AIRequest(prompt: mergedPrompt, maxTokens: 512);
        await for (final token in aiRouter.routeStream(request)) {
          // Skip brute alert tokens (all providers failed).
          if (_isBruteAlert(token)) break;

          fullText.write(token);
          buffer.add(token);

          // Update status message with accumulated text.
          if (mounted) {
            final current = _cleanLlmText(fullText.toString().trim());
            if (current.isNotEmpty) {
              setState(() {
                _statusMessage = current;
              });
            }
          }
        }
        buffer.flush();
      } on Exception catch (e) {
        _log.warning('LLM streaming failed, using fallback', error: e);
        // Disable LLM to avoid retrying on subsequent steps.
        _llmAvailable = false;
        // Fall back to non-streaming: speak the fallback prompt.
        if (mounted) {
          _voiceActive = false;
          _speakThenListen(
            prompt: fallbackPrompt,
            onTranscript: onTranscript,
            onTimeout: onTimeout,
            timeout: timeout,
          );
          setState(() {
            _statusMessage = fallbackPrompt;
          });
        }
        return;
      }

      if (!mounted) {
        _voiceActive = false;
        return;
      }

      final generatedText = _cleanLlmText(fullText.toString().trim());
      if (generatedText.isEmpty || _isBruteAlert(generatedText)) {
        // LLM returned empty or brute alert (all providers failed) — fall back.
        _llmAvailable = false;
        _voiceActive = false;
        _speakThenListen(
          prompt: fallbackPrompt,
          onTranscript: onTranscript,
          onTimeout: onTimeout,
          timeout: timeout,
        );
        setState(() {
          _statusMessage = fallbackPrompt;
        });
        return;
      }

      setState(() {
        _statusMessage = generatedText;
      });

      // Wait for the last sentence to finish being spoken, then start STT.
      if (lastSentence != null) {
        unawaited(_speechSub?.cancel());
        _speechSub = tts.speechEvents.listen((event) {
          if (event.type == TtsSpeechEventType.completed &&
              event.text == lastSentence) {
            _speechSub?.cancel();
            _speechSub = null;

            if (!mounted) {
              _voiceActive = false;
              return;
            }

            _startListening(
              onTranscript: onTranscript,
              onTimeout: onTimeout,
              timeout: timeout,
              lastPartialRef: () => lastPartial,
              setLastPartial: (v) => lastPartial = v,
            );
          }
        });
      } else {
        // No sentences were spoken (shouldn't happen). Start STT immediately.
        _startListening(
          onTranscript: onTranscript,
          onTimeout: onTimeout,
          timeout: timeout,
          lastPartialRef: () => lastPartial,
          setLastPartial: (v) => lastPartial = v,
        );
      }
    }());
  }

  /// Start STT listening with timeout. Extracted from _speakThenListen
  /// to share with _speakStreamThenListen.
  void _startListening({
    required void Function(String transcript) onTranscript,
    required VoidCallback? onTimeout,
    required Duration timeout,
    required String Function() lastPartialRef,
    required void Function(String) setLastPartial,
  }) {
    final stt = ref.read(sttServiceProvider);

    _listenTimer?.cancel();
    _listenTimer = Timer(timeout, () {
      unawaited(stt.stopRecognition());
      _voiceActive = false;
      if (mounted) {
        final partial = lastPartialRef();
        if (partial.isNotEmpty) {
          _log.info('STT timeout, using last partial: "$partial"');
          onTranscript(partial);
        } else {
          onTimeout?.call();
        }
      }
    });

    _log.info('TTS completed, starting STT...');
    unawaited(stt.startRecognition(onResult: (transcript, isFinal) {
      _log.info('STT result: "$transcript" (final=$isFinal)');
      if (transcript.isNotEmpty) {
        setLastPartial(transcript);
      }
      if (isFinal && transcript.isNotEmpty && mounted) {
        _listenTimer?.cancel();
        _listenTimer = null;
        unawaited(stt.stopRecognition());
        _voiceActive = false;
        onTranscript(transcript);
      }
    }).then((result) {
      if (result.isFailure) {
        _log.error('STT startRecognition failed: $result');
        _voiceActive = false;
      }
    }).catchError((Object e) {
      _log.error('STT failed during onboarding', error: e);
      _voiceActive = false;
    }));
  }

  // ---------------------------------------------------------------------------
  // LLM interaction helpers
  // ---------------------------------------------------------------------------

  /// System prompt shared across all onboarding LLM calls.
  static const _systemBase = 'Tu es Kita, une assistante IA chaleureuse et '
      'bienveillante pour personnes aveugles ou malvoyantes. '
      'Tu tutoies l\'utilisateur. Tu parles en francais simple et naturel. '
      'Tes phrases sont courtes (max 2 phrases) car elles seront lues par '
      'synthese vocale. Sois spontanee, chaque conversation est unique.';

  /// Detect the FallbackChain brute alert response (all providers failed).
  /// When this is returned, we should treat it as a failure and use fallback text.
  static bool _isBruteAlert(String text) {
    return text.contains('Attention') &&
        text.contains('impossible de fournir');
  }

  /// Clean LLM-generated text: trim and strip wrapping quotes.
  static String _cleanLlmText(String text) {
    if (text.isEmpty) return '';
    final trimmed = text.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Ask the LLM to generate a speech prompt for a given onboarding step.
  ///
  /// Non-streaming: waits for full completion, returns the text.
  /// Used only where the full text is needed before acting (e.g. _askLLM,
  /// pre-generating the ready message). For speak-then-listen, use
  /// [_speakStreamThenListen] instead.
  Future<String?> _generateSpeech(String context) async {
    if (!_llmAvailable) return null;

    try {
      final aiRouter = ref.read(aiRouterProvider);

      const systemPrompt = '$_systemBase\n'
          'Genere UNIQUEMENT la phrase a dire a voix haute. '
          'Pas de JSON, pas de guillemets, juste la phrase.';
      final mergedPrompt = '$systemPrompt\n\n$context';

      final result = await aiRouter.route(
        AIRequest(prompt: mergedPrompt, maxTokens: 256),
      );

      return result.map((r) {
        final text = _cleanLlmText(r.content);
        if (text.isEmpty || _isBruteAlert(text)) return null;
        return text;
      }).getOrElse((_) => null);
    } on Exception catch (e) {
      _log.warning('LLM speech generation failed', error: e);
      return null;
    }
  }

  /// Ask the LLM to interpret a user transcript and return structured data
  /// plus the next phrase to say.
  ///
  /// Returns parsed JSON map with `data` and `next_speech` fields,
  /// or null if LLM is unavailable or fails.
  Future<Map<String, dynamic>?> _askLLM(
    String systemPrompt,
    String userTranscript,
  ) async {
    if (!_llmAvailable) return null;

    try {
      final aiRouter = ref.read(aiRouterProvider);
      final mergedPrompt =
          '$systemPrompt\n\nL\'utilisateur dit: "$userTranscript"';

      final result = await aiRouter.route(
        AIRequest(prompt: mergedPrompt, maxTokens: 256),
      );

      final text = result
          .map((r) => r.content.trim())
          .getOrElse((_) => '');
      if (text.isEmpty || _isBruteAlert(text)) return null;

      // Try to extract JSON from the response (it may be wrapped in markdown).
      final jsonStr = _extractJson(text);
      if (jsonStr == null) {
        _log.warning('LLM response is not valid JSON');
        return null;
      }

      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } on Exception catch (e) {
      _log.warning('LLM onboarding call failed', error: e);
      return null;
    }
  }

  /// Extract a JSON object from text that may contain markdown fences.
  String? _extractJson(String text) {
    // Try direct parse first.
    if (text.startsWith('{')) {
      try {
        jsonDecode(text);
        return text;
      } catch (_) {
        // Not valid JSON, try extraction.
      }
    }

    // Extract from ```json ... ``` or ``` ... ``` blocks.
    final fencePattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = fencePattern.firstMatch(text);
    if (match != null) return match.group(1);

    // Last resort: find first { ... } in the text.
    final bracePattern = RegExp(r'\{[\s\S]*\}');
    final braceMatch = bracePattern.firstMatch(text);
    return braceMatch?.group(0);
  }

  /// Handle greeting response: extract name using LLM or keyword fallback.
  Future<void> _handleGreetingResponse(String transcript) async {
    final llmResult = await _askLLM(
      '$_systemBase\n'
      'Etape: accueil. L\'utilisateur vient de se presenter ou de repondre '
      'a ta question "comment tu t\'appelles". '
      'Extrais son prenom. S\'il veut passer ou ne dit pas de prenom, note-le. '
      'Genere une phrase de transition chaleureuse pour lui demander la '
      'permission camera (car tu as besoin de voir pour l\'aider). '
      'Reponds UNIQUEMENT en JSON:\n'
      '{"name": "prenom ou null", "skip": false, '
      '"next_speech": "ta phrase de transition"}',
      transcript,
    );

    String? transitionSpeech;

    if (llmResult != null) {
      final skip = llmResult['skip'] == true;
      final name = llmResult['name'] as String?;
      transitionSpeech = llmResult['next_speech'] as String?;

      if (skip || name == null || name.isEmpty || name == 'null') {
        _log.info('Name skipped (LLM-parsed)');
      } else {
        _capturedName = name[0].toUpperCase() + name.substring(1);
        _log.info('Name captured via LLM');
        ref
            .read(onboardingNotifierProvider.notifier)
            .setUserName(_capturedName!);
      }
      unawaited(_advanceToCameraPermission(customPrompt: transitionSpeech));
      return;
    }

    // Keyword fallback.
    final lower = transcript.toLowerCase().trim();
    if (lower.contains('passer') || lower.contains('passe')) {
      _log.info('Name skipped via voice');
    } else {
      final extracted = _extractNameFromTranscript(transcript);
      if (extracted != null) {
        _capturedName = extracted[0].toUpperCase() + extracted.substring(1);
        _log.info('Name captured via voice');
        ref
            .read(onboardingNotifierProvider.notifier)
            .setUserName(_capturedName!);
      } else {
        _log.info('No name found in transcript, skipping');
      }
    }
    unawaited(_advanceToCameraPermission());
  }

  /// Common French filler words and conversational noise that are not names.
  static const _fillerWords = <String>{
    'alors', 'bon', 'euh', 'oui', 'bah', 'ben', 'eh', 'ah', 'oh',
    'ok', "d'accord", 'salut', 'bonjour', 'bonsoir', 'hey', 'he',
    'donc', 'moi', 'je', 'suis', "c'est", 'mon', 'nom', 'appelle',
    "m'appelle", 'ca', 'est', 'non', 'merci',
  };

  /// Extract a name from a transcript using simple patterns and filler filtering.
  ///
  /// Tries known patterns first ("je m'appelle X", "moi c'est X", "c'est X"),
  /// then falls back to filtering out filler words and returning the first
  /// remaining word. Returns null if no plausible name is found.
  static String? _extractNameFromTranscript(String transcript) {
    final lower = transcript.toLowerCase().trim();

    // Pattern: "je m'appelle X" or "m'appelle X"
    final mappelleMatch =
        RegExp(r"(?:je\s+)?m'appelle\s+(\w+)", caseSensitive: false)
            .firstMatch(lower);
    if (mappelleMatch != null) {
      return mappelleMatch.group(1);
    }

    // Pattern: "moi c'est X"
    final moiCestMatch =
        RegExp(r"moi\s+c'est\s+(\w+)", caseSensitive: false)
            .firstMatch(lower);
    if (moiCestMatch != null) {
      return moiCestMatch.group(1);
    }

    // Pattern: "c'est X" (only if short — avoids "c'est OK" etc.)
    final cestMatch =
        RegExp(r"c'est\s+(\w+)$", caseSensitive: false).firstMatch(lower);
    if (cestMatch != null) {
      final candidate = cestMatch.group(1)!;
      if (!_fillerWords.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }

    // Fallback: filter filler words, take first remaining word.
    final words = lower.split(RegExp(r'\s+'));
    final candidates =
        words.where((w) => !_fillerWords.contains(w)).toList();
    if (candidates.isEmpty) return null;

    // Use original casing from the transcript for the matched word.
    final originalWords = transcript.trim().split(RegExp(r'\s+'));
    for (final word in originalWords) {
      if (word.toLowerCase() == candidates.first) {
        return word.toLowerCase();
      }
    }
    return candidates.first;
  }

  /// Handle camera permission response using LLM or keyword fallback.
  Future<void> _handleCameraResponse(String transcript) async {
    final llmResult = await _askLLM(
      '$_systemBase\n'
      'Etape: permission camera. L\'utilisateur repond a ta demande d\'acceder '
      'a la camera. Determine s\'il accepte ou refuse. '
      'Si il accepte, genere une courte phrase d\'encouragement. '
      'Si il refuse, genere une phrase rassurante (il pourra activer plus tard). '
      'Puis genere la phrase pour l\'inviter a essayer la commande "decris" '
      '(le moment magique ou tu lui montres ce que tu sais faire). '
      'Reponds UNIQUEMENT en JSON:\n'
      '{"accepted": true/false, "reaction_speech": "ta reaction", '
      '"magic_speech": "ta phrase pour inviter a dire decris"}',
      transcript,
    );

    if (llmResult != null) {
      final accepted = llmResult['accepted'] == true;
      final reaction = llmResult['reaction_speech'] as String?;
      final magicSpeech = llmResult['magic_speech'] as String?;

      if (accepted) {
        _log.info('Camera permission accepted (LLM-parsed)');
        unawaited(_requestCameraPermission(
          customMagicPrompt: magicSpeech,
        ));
      } else {
        _log.info('Camera permission declined (LLM-parsed)');
        final declineMsg = reaction ??
            'Pas de souci, tu pourras l\'activer plus tard dans les reglages.';
        _speakOnly(declineMsg);
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _advanceToMagicMoment(customPrompt: magicSpeech);
        });
      }
      return;
    }

    // Keyword fallback.
    final lower = transcript.toLowerCase();
    if (lower.contains('oui') ||
        lower.contains('d\'accord') ||
        lower.contains('accord') ||
        lower.contains('ok') ||
        lower.contains('bien sur') ||
        lower.contains('vas-y') ||
        lower.contains('permets')) {
      _log.info('Camera permission accepted via voice');
      unawaited(_requestCameraPermission());
    } else {
      _log.info('Camera permission declined via voice');
      _speakOnly(
        'Pas de souci, tu pourras l\'activer plus tard dans les reglages.',
      );
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _advanceToMagicMoment();
      });
    }
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

    // Generate greeting via streaming LLM → TTS, then listen for name.
    // User hears first sentence at ~1.5s instead of waiting ~8s.
    const fallbackGreeting =
        'Parfait ! Je suis Kita, ton assistante. Comment tu t\'appelles ?';

    if (!mounted) return;

    _speakStreamThenListen(
      llmContext: 'L\'utilisateur vient d\'autoriser le micro. '
          'Presente-toi (tu es Kita) et demande-lui son prenom. '
          'Sois chaleureuse et naturelle.',
      fallbackPrompt: fallbackGreeting,
      onTranscript: (transcript) =>
          unawaited(_handleGreetingResponse(transcript)),
      onTimeout: () {
        _log.info('Name capture timed out, skipping');
        _advanceToCameraPermission();
      },
    );
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

  Future<void> _advanceToCameraPermission({String? customPrompt}) async {
    if (!mounted) return;
    _cancelVoice();

    setState(() {
      _step = _ConversationStep.cameraPermission;
    });

    // Use LLM-generated transition or generate one, or fallback.
    final fallbackGreeting = _capturedName != null
        ? 'Enchantee $_capturedName. '
        : '';
    final fallbackPrompt = '${fallbackGreeting}Pour t\'aider, j\'ai besoin '
        'd\'acceder a ta camera. Tu permets ?';

    if (!mounted) return;

    if (customPrompt != null) {
      // Already have LLM-generated text (from _handleGreetingResponse).
      _speakThenListen(
        prompt: customPrompt,
        onTranscript: (transcript) =>
            unawaited(_handleCameraResponse(transcript)),
        onTimeout: () {
          _log.info('Camera permission timed out, skipping');
          unawaited(_advanceToMagicMoment());
        },
      );
      setState(() {
        _statusMessage = customPrompt;
      });
    } else {
      // No pre-generated text — stream from LLM.
      _speakStreamThenListen(
        llmContext: 'Tu viens de faire connaissance avec l\'utilisateur'
            '${_capturedName != null ? " qui s'appelle $_capturedName" : ""}. '
            'Demande-lui la permission d\'acceder a sa camera. '
            'Explique brievement pourquoi (pour decrire ce qu\'il y a autour). '
            'Sois naturelle.',
        fallbackPrompt: fallbackPrompt,
        onTranscript: (transcript) =>
            unawaited(_handleCameraResponse(transcript)),
        onTimeout: () {
          _log.info('Camera permission timed out, skipping');
          unawaited(_advanceToMagicMoment());
        },
      );
    }
  }

  Future<void> _requestCameraPermission({String? customMagicPrompt}) async {
    // Camera announcement is short + we MUST wait for it before showing OS dialog.
    // Non-streaming is fine here — it's a ~1-sentence generation (~2s).
    const fallbackAnnouncement = 'Je lance la demande. Appuie sur Autoriser.';
    final cameraAnnouncement = await _generateSpeech(
          'Tu vas lancer le dialog systeme pour la permission camera. '
          'Previens l\'utilisateur qu\'il doit appuyer sur Autoriser '
          'quand le dialog apparait. Sois breve.',
        ) ??
        fallbackAnnouncement;

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

    if (mounted) unawaited(_advanceToMagicMoment(customPrompt: customMagicPrompt));
  }

  // ---------------------------------------------------------------------------
  // Step 3: Magic moment
  // ---------------------------------------------------------------------------

  Future<void> _advanceToMagicMoment({String? customPrompt}) async {
    if (!mounted) return;
    _cancelVoice();

    setState(() {
      _step = _ConversationStep.magicMoment;
    });

    const fallbackPrompt =
        'Parfait ! Essaie : dis decris et je te decrirai ce que je vois.';

    if (!mounted) return;

    if (customPrompt != null) {
      // Already have LLM-generated text — pre-generate ready message,
      // then speak the custom prompt.
      _pendingReadyMessage = await _generateSpeech(
        'L\'onboarding est presque termine. Tu viens de montrer a l\'utilisateur '
        'ce que tu sais faire. Genere un message court et enthousiaste pour '
        'lui dire que tu es prete et qu\'il peut te demander ce qu\'il veut.',
      );

      if (!mounted) return;

      _speakThenListen(
        prompt: customPrompt,
        timeout: const Duration(seconds: 10),
        onTranscript: (transcript) {
          _log.info('Magic moment: routing "$transcript" to orchestrator');
          _triggerDescribeViaOrchestrator(transcript);
        },
        onTimeout: () {
          _log.info('Magic moment timed out, completing');
          _completeOnboarding();
        },
      );
      setState(() {
        _statusMessage = customPrompt;
      });
    } else {
      // No pre-generated text. Stream the magic moment invite from LLM,
      // but first pre-generate the ready message while the AI pipeline is free.
      _pendingReadyMessage = await _generateSpeech(
        'L\'onboarding est presque termine. Tu viens de montrer a l\'utilisateur '
        'ce que tu sais faire. Genere un message court et enthousiaste pour '
        'lui dire que tu es prete et qu\'il peut te demander ce qu\'il veut.',
      );

      if (!mounted) return;

      _speakStreamThenListen(
        llmContext: 'C\'est le moment magique de l\'onboarding. '
            'Invite l\'utilisateur a dire le mot "decris" pour que tu lui '
            'montres ce que tu sais faire : decrire ce que la camera voit. '
            'Rends ca excitant et engageant.',
        fallbackPrompt: fallbackPrompt,
        timeout: const Duration(seconds: 10),
        onTranscript: (transcript) {
          _log.info('Magic moment: routing "$transcript" to orchestrator');
          _triggerDescribeViaOrchestrator(transcript);
        },
        onTimeout: () {
          _log.info('Magic moment timed out, completing');
          _completeOnboarding();
        },
      );
    }
  }

  /// Routes the user's transcript through the orchestrator.
  /// The orchestrator's InputRouter + VoiceCommandHandler will figure out
  /// the intent (describe, help, etc.) and act accordingly.
  void _triggerDescribeViaOrchestrator(String transcript) {
    setState(() {
      _statusMessage = 'Je regarde...';
    });

    try {
      final orchestrator = ref.read(kitaOrchestratorProvider);
      final clock = ref.read(clockProvider);
      _log.info('Routing to orchestrator: "$transcript"');
      unawaited(orchestrator
          .handleInput(RawInput.voice(transcript, clock: clock))
          .then((_) => _log.info('Orchestrator handled: "$transcript"'))
          .catchError((Object e) {
        _log.error('Orchestrator failed for "$transcript"', error: e);
      }));
    } catch (e) {
      _log.error('Could not access orchestrator', error: e);
    }

    // Complete onboarding after a delay, regardless of orchestrator result.
    // The describe agent runs independently via the orchestrator lifecycle.
    // NOTE: Do NOT call _generateSpeech here — the AI pipeline may be busy
    // processing the vision request from the orchestrator. Use a pre-generated message instead.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      // Use the pre-generated magic speech or fallback.
      // We can't call LLM here because it's processing the describe request.
      final readyMsg = _pendingReadyMessage ??
          'Voila ! Je suis prete. Demande-moi ce que tu veux.';
      _speakOnly(readyMsg);
      setState(() {
        _statusMessage = readyMsg;
      });
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _completeOnboarding();
      });
    });
  }

  void _triggerDescribe() {
    setState(() {
      _statusMessage = 'Je regarde...';
    });

    // Route "decris" through the orchestrator (fire-and-forget).
    try {
      final orchestrator = ref.read(kitaOrchestratorProvider);
      final clock = ref.read(clockProvider);
      _log.info('Triggering describe via orchestrator');
      unawaited(orchestrator
          .handleInput(RawInput.voice('decris', clock: clock))
          .then((_) => _log.info('Describe pipeline completed'))
          .catchError((Object e) {
        _log.error('Describe via orchestrator failed', error: e);
      }));
    } catch (e) {
      _log.error('Could not access orchestrator', error: e);
    }

    // Complete onboarding after a short delay.
    // NOTE: Do NOT call _generateSpeech here — same reason as above.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final readyMsg = _pendingReadyMessage ??
          'Voila ! Je suis prete. Demande-moi ce que tu veux.';
      _speakOnly(readyMsg);
      setState(() {
        _statusMessage = readyMsg;
      });
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _completeOnboarding();
      });
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
        unawaited(_advanceToCameraPermission());
      case _ConversationStep.cameraPermission:
        unawaited(_requestCameraPermission());
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
        unawaited(_advanceToCameraPermission());
      case _ConversationStep.cameraPermission:
        unawaited(_advanceToMagicMoment());
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
      child: SingleChildScrollView(
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
