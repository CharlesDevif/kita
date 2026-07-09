import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/multi_modal_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../io/data/providers/stt_providers.dart';
import '../../onboarding/di/providers.dart';
import '../../orchestration/di/providers.dart';
import '../../orchestration/domain/models/raw_input.dart';
import '../di/conversation_providers.dart';
import '../di/orb_providers.dart';
import '../domain/conversation_entry.dart';
import '../domain/input_state.dart';
import '../di/shell_mode_providers.dart';
import '../domain/orb_state.dart';
import '../domain/shell_mode.dart';
import 'kita_input.dart';
import 'kita_orb.dart';
import 'kita_status_indicator.dart';
import 'shell_onboarding.dart';

/// Main scaffold of the Kita app — Living Aura design.
///
/// Three zones: header (status + orb), viewport (plugin content), input.
/// Transitions between passive (orb centered) and active (orb header) modes.
///
/// As of Story 12.4, this is a [ConsumerStatefulWidget] wired to the
/// orchestration system:
/// - `ref.watch(shellModeProvider)` drives passive/active mode
/// - `ref.watch(orbStateProvider)` drives the orb visual state
/// - `ref.listen(hasActiveOnDemandProvider)` syncs supervisor → shell mode
/// - KitaInput callbacks route text/voice inputs to the orchestrator
///
/// Focus order (VoiceOver): Input (1) -> Viewport (2) -> Header (3)
class KitaShell extends ConsumerStatefulWidget {
  const KitaShell({
    this.modeOverride,
    this.orbStateOverride,
    this.status = KitaStatus.online,
    this.viewportChild,
    this.inputChild,
    super.key,
  });

  /// Optional mode override (used in tests). If null, reads from provider.
  final ShellMode? modeOverride;

  /// Optional orb state override (used in tests). If null, reads from provider.
  final OrbState? orbStateOverride;

  final KitaStatus status;

  /// Plugin content displayed in the viewport zone.
  final Widget? viewportChild;

  /// Input zone widget (KitaInput). Placeholder if null.
  final Widget? inputChild;

  @override
  ConsumerState<KitaShell> createState() => _KitaShellState();
}

class _KitaShellState extends ConsumerState<KitaShell>
    with SingleTickerProviderStateMixin {
  static final _log = KitaLogger('Shell');

  late final AnimationController _modeController;
  late Animation<double> _modeAnimation;

  ShellMode _currentMode = ShellMode.passive;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.modeOverride ?? ShellMode.passive;
    _modeController = AnimationController(
      vsync: this,
      duration: KitaAnimationDurations.transition,
      value: _currentMode == ShellMode.active ? 1.0 : 0.0,
    );
    _modeAnimation = CurvedAnimation(
      parent: _modeController,
      curve: Curves.easeInOut,
    );

    // Initialize the orchestrator (spawns persistent agents like AlertAgent).
    // This is idempotent — safe to call on every Shell mount.
    unawaited(
      ref
          .read(kitaOrchestratorProvider)
          .initialize()
          .catchError((Object e) {
        _log.error('Orchestrator initialization failed', error: e);
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _modeController.duration = KitaAnimationDurations.zero;
    } else {
      _modeController.duration = _currentMode == ShellMode.active
          ? KitaAnimationDurations.transition
          : KitaAnimationDurations.state;
    }
  }

  void _animateToMode(ShellMode mode) {
    if (mode == _currentMode) return;
    _currentMode = mode;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _modeController.value = mode == ShellMode.active ? 1.0 : 0.0;
    } else {
      if (mode == ShellMode.active) {
        _modeController.duration = KitaAnimationDurations.transition;
        _modeController.forward();
      } else {
        _modeController.duration = KitaAnimationDurations.state;
        _modeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _modeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Input callbacks → Orchestrator
  // ---------------------------------------------------------------------------

  void _onTextSubmit(String text) {
    _log.info('Text submitted, routing to orchestrator');
    ref.read(conversationFeedProvider.notifier).addUser(text);
    final orchestrator = ref.read(kitaOrchestratorProvider);
    final clock = ref.read(clockProvider);
    orchestrator.handleInput(RawInput.text(text, clock: clock));
  }

  void _onMicPressed() {
    _log.info('Mic pressed, toggling STT');
    final stt = ref.read(sttServiceProvider);
    if (stt.isListening) {
      unawaited(stt.stopRecognition().catchError((Object e) {
        _log.error('STT stop failed', error: e);
        return const Result<void>.success(null);
      }));
    } else {
      unawaited(stt.startRecognition(onResult: (transcript, isFinal) {
        if (isFinal && transcript.isNotEmpty) {
          _log.info('STT final result, routing to orchestrator');
          ref.read(conversationFeedProvider.notifier).addUser(transcript);
          final orchestrator = ref.read(kitaOrchestratorProvider);
          final clock = ref.read(clockProvider);
          orchestrator.handleInput(RawInput.voice(transcript, clock: clock));
        }
      }).catchError((Object e) {
        _log.error('STT start failed', error: e);
        return const Result<void>.success(null);
      }));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Read state from providers (or overrides for tests)
    final ShellMode mode =
        widget.modeOverride ?? ref.watch(shellModeProvider);
    final OrbState orbState =
        widget.orbStateOverride ?? ref.watch(orbStateProvider);

    // Side effect: sync supervisor hasActiveOnDemand -> ShellModeNotifier.
    // Using ref.listen inside ConsumerState.build() is the standard Riverpod
    // pattern for side effects. Riverpod automatically handles re-registration
    // on rebuild and cleanup on dispose. This is NOT the same as calling
    // ref.listen in a StatelessWidget (which would leak listeners).
    ref.listen(hasActiveOnDemandProvider, (prev, next) {
      final notifier = ref.read(shellModeProvider.notifier);
      if (next) {
        notifier.activate();
      } else {
        notifier.deactivate();
      }
    });

    // Animate to current mode
    _animateToMode(mode);

    return Semantics(
      container: true,
      label: 'Écran principal Kita',
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: AnimatedBuilder(
              animation: _modeAnimation,
              builder: (context, _) {
                return _buildLayout(context, _modeAnimation.value, orbState);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, double t, OrbState orbState) {
    // t = 0.0: passive, t = 1.0: active
    // Focus order: Input (1) -> Viewport (2) -> Header (3)
    return Column(
      children: [
        // --- Header zone (focus order 3) ---
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _buildHeader(context, t, orbState),
        ),

        // --- Viewport zone (focus order 2) ---
        Expanded(
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: _buildViewport(context, t),
          ),
        ),

        // --- Input zone (focus order 1) ---
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: _buildInput(context),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, double t, OrbState orbState) {
    // In passive mode, orb occupies center space. In active, it's in the header row.
    if (t < 0.5) {
      // Passive-ish: orb is centered and large
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KitaStatusIndicator(status: widget.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: KitaOrb(
              state: orbState,
              size: OrbSize.large,
            ),
          ),
        ],
      );
    }

    // Active mode: compact header with small orb + status
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          KitaOrb(
            state: orbState,
            size: OrbSize.small,
          ),
          const Spacer(),
          KitaStatusIndicator(status: widget.status),
        ],
      ),
    );
  }

  Widget _buildViewport(BuildContext context, double t) {
    // Viewport opacity/visibility scales with active mode
    final viewportOpacity = t.clamp(0.0, 1.0);

    // Check if onboarding is complete — if not, show conversational onboarding
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final conversation = ref.watch(conversationFeedProvider);

    // Default viewport: the conversation feed once a dialogue started,
    // otherwise the calm idle text.
    final Widget defaultViewport = conversation.isEmpty
        ? Center(
            child: Text(
              'Tout va bien',
              style: TextStyle(
                color: const Color(0xFFE2E8F0)
                    .withValues(alpha: 0.5 + 0.5 * viewportOpacity),
                fontSize: 16,
              ),
            ),
          )
        : _ConversationFeedView(entries: conversation);

    // Le fondu passif (0.3) n'est acceptable que pour le texte d'ambiance :
    // une conversation en cours doit rester PLEINEMENT lisible quel que soit
    // le mode (retour terrain : fil invisible sur fond sombre en passif).
    final opacity =
        conversation.isEmpty ? 0.3 + 0.7 * viewportOpacity : 1.0;

    return Semantics(
      liveRegion: true,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: onboardingComplete
              ? (widget.viewportChild ?? defaultViewport)
              : const ShellOnboarding(),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);

    // During onboarding, hide input completely — ShellOnboarding manages its
    // own voice/button interactions. Showing a disabled KitaInput is confusing
    // and the text field is not readable by screen readers in disabled state.
    if (!onboardingComplete && widget.inputChild == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.inputChild ??
          KitaInput(
            state: InputState.idle,
            onTextSubmit: _onTextSubmit,
            onMicPressed: _onMicPressed,
          ),
    );
  }
}

/// Scrollable feed of the current conversation (session-only, never stored).
///
/// User messages align right (teal), Kita messages align left (dark). The
/// list is rendered bottom-up so the latest exchange is always visible.
class _ConversationFeedView extends StatelessWidget {
  const _ConversationFeedView({required this.entries});

  final List<ConversationEntry> entries;

  @override
  Widget build(BuildContext context) {
    // reverse:true keeps the newest message pinned at the bottom without a
    // scroll controller; iterate the list backwards to match.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        final isUser = entry.speaker == ConversationSpeaker.user;
        return Semantics(
          label: isUser ? 'Toi' : 'Kita',
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                // La bulle de Kita doit se détacher NETTEMENT du fond
                // (#1A1A2E) : #16213E en était indiscernable (retour terrain).
                color: isUser
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF2D3A5F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF14B8A6)
                      : const Color(0xFF475D8F),
                ),
              ),
              child: Text(
                entry.text,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
