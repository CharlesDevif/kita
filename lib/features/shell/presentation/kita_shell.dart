import 'package:flutter/material.dart';

import '../../../core/theme/multi_modal_tokens.dart';
import '../domain/orb_state.dart';
import '../domain/shell_mode.dart';
import 'kita_orb.dart';
import 'kita_status_indicator.dart';

/// Main scaffold of the Kita app — Living Aura design.
///
/// Three zones: header (status + orb), viewport (plugin content), input.
/// Transitions between passive (orb centered) and active (orb header) modes.
///
/// Focus order (VoiceOver): Input (1) -> Viewport (2) -> Header (3)
class KitaShell extends StatefulWidget {
  const KitaShell({
    this.mode = ShellMode.passive,
    this.orbState = OrbState.passive,
    this.status = KitaStatus.online,
    this.viewportChild,
    this.inputChild,
    super.key,
  });

  final ShellMode mode;
  final OrbState orbState;
  final KitaStatus status;

  /// Plugin content displayed in the viewport zone.
  final Widget? viewportChild;

  /// Input zone widget (KitaInput). Placeholder if null.
  final Widget? inputChild;

  @override
  State<KitaShell> createState() => _KitaShellState();
}

class _KitaShellState extends State<KitaShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _modeController;
  late Animation<double> _modeAnimation;

  @override
  void initState() {
    super.initState();
    _modeController = AnimationController(
      vsync: this,
      duration: KitaAnimationDurations.transition,
      value: widget.mode == ShellMode.active ? 1.0 : 0.0,
    );
    _modeAnimation = CurvedAnimation(
      parent: _modeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(KitaShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _animateToMode(widget.mode);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _modeController.duration = KitaAnimationDurations.zero;
    } else {
      _modeController.duration = widget.mode == ShellMode.active
          ? KitaAnimationDurations.transition
          : KitaAnimationDurations.state;
    }
  }

  void _animateToMode(ShellMode mode) {
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ecran principal Kita',
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: AnimatedBuilder(
              animation: _modeAnimation,
              builder: (context, _) {
                return _buildLayout(context, _modeAnimation.value);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, double t) {
    // t = 0.0: passive, t = 1.0: active
    // Focus order: Input (1) -> Viewport (2) -> Header (3)
    return Column(
      children: [
        // --- Header zone (focus order 3) ---
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _buildHeader(context, t),
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

  Widget _buildHeader(BuildContext context, double t) {
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
              state: widget.orbState,
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
            state: widget.orbState,
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

    return Semantics(
      liveRegion: true,
      child: Opacity(
        opacity: 0.3 + 0.7 * viewportOpacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: widget.viewportChild ??
              Center(
                child: Text(
                  'Tout va bien',
                  style: TextStyle(
                    color: const Color(0xFFE2E8F0)
                        .withValues(alpha: 0.5 + 0.5 * viewportOpacity),
                    fontSize: 16,
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.inputChild ??
          Semantics(
            label: 'Parle ou ecris a Kita',
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Parle ou ecris a Kita',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
              ),
            ),
          ),
    );
  }
}
