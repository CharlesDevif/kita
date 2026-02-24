import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/orb_state.dart';

/// Animated signature orb representing Kita's current state.
///
/// Renders a teal/violet gradient sphere via [CustomPainter] with
/// 6 visually distinct animation patterns. Respects `prefers-reduced-motion`.
class KitaOrb extends StatefulWidget {
  const KitaOrb({
    required this.state,
    this.size = OrbSize.large,
    super.key,
  });

  final OrbState state;
  final OrbSize size;

  @override
  State<KitaOrb> createState() => _KitaOrbState();
}

class _KitaOrbState extends State<KitaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(KitaOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final diameter = switch (widget.size) {
      OrbSize.large => screenWidth * 0.5,
      OrbSize.small => screenWidth * 0.15,
    };

    return Semantics(
      label: widget.state.semanticsLabel,
      image: true,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: KitaOrbPainter(
                state: widget.state,
                animationValue: _controller.value,
              ),
              size: Size(diameter, diameter),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the orb based on [state] and [animationValue] (0.0 to 1.0).
///
/// Compatible with Impeller renderer — uses only supported Canvas operations:
/// `drawCircle`, `drawPath`, `RadialGradient.createShader()`.
class KitaOrbPainter extends CustomPainter {
  const KitaOrbPainter({
    required this.state,
    required this.animationValue,
  });

  final OrbState state;
  final double animationValue;

  // Brand colors
  static const _teal = Color(0xFF0D9488);
  static const _violet = Color(0xFF8B5CF6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _greyTeal = Color(0xFF708090);
  static const _grey = Color(0xFF4A5568);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    final colors = _colorsForState();
    final speedMultiplier = _speedMultiplier();
    final animPhase = animationValue * speedMultiplier * 2 * math.pi;

    // Draw outer glow
    _drawGlow(canvas, center, baseRadius, colors, animPhase);

    // Draw main orb body
    _drawOrbBody(canvas, center, baseRadius, colors, animPhase);

    // Draw inner highlight
    _drawHighlight(canvas, center, baseRadius, animPhase);

    // Draw particles
    _drawParticles(canvas, center, baseRadius, colors, animPhase);
  }

  void _drawGlow(
    Canvas canvas,
    Offset center,
    double radius,
    (Color, Color) colors,
    double phase,
  ) {
    final glowRadius = radius * (1.0 + 0.15 * math.sin(phase));
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.$1.withValues(alpha: 0.3),
          colors.$2.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: glowRadius),
      );
    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  void _drawOrbBody(
    Canvas canvas,
    Offset center,
    double radius,
    (Color, Color) colors,
    double phase,
  ) {
    // Scale pulsation for listening/error states
    final scaleModifier = switch (state) {
      OrbState.listening => 1.0 + 0.08 * math.sin(phase),
      OrbState.error => 1.0 + 0.06 * math.sin(phase * 2),
      OrbState.responding => 1.0 + 0.1 * math.sin(phase * 0.5),
      _ => 1.0 + 0.03 * math.sin(phase),
    };

    final orbRadius = radius * 0.75 * scaleModifier;

    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          0.3 * math.cos(phase * 0.7),
          0.3 * math.sin(phase * 0.7),
        ),
        radius: 0.9,
        colors: [colors.$1, colors.$2],
        stops: const [0.2, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: orbRadius),
      );

    canvas.drawCircle(center, orbRadius, orbPaint);
  }

  void _drawHighlight(Canvas canvas, Offset center, double radius, double phase) {
    final highlightOffset = Offset(
      center.dx - radius * 0.2,
      center.dy - radius * 0.2,
    );
    final highlightRadius = radius * 0.25;
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.3 + 0.1 * math.sin(phase)),
          const Color(0xFFFFFFFF).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: highlightOffset, radius: highlightRadius),
      );
    canvas.drawCircle(highlightOffset, highlightRadius, highlightPaint);
  }

  void _drawParticles(
    Canvas canvas,
    Offset center,
    double radius,
    (Color, Color) colors,
    double phase,
  ) {
    const particleCount = 6;
    final particleRadius = radius * 0.03;
    final orbitRadius = radius * 0.6;

    for (var i = 0; i < particleCount; i++) {
      final angle = phase + (i * 2 * math.pi / particleCount);
      final particleOffset = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle),
      );

      final opacity = 0.4 + 0.3 * math.sin(phase + i * 0.5);
      final particlePaint = Paint()
        ..color = colors.$1.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(particleOffset, particleRadius, particlePaint);
    }
  }

  (Color, Color) _colorsForState() => switch (state) {
        OrbState.passive => (_teal, _violet),
        OrbState.listening => (_teal, _violet),
        OrbState.processing => (_teal, _violet),
        OrbState.responding => (_green, _teal),
        OrbState.error => (_red, const Color(0xFFB91C1C)),
        OrbState.offline => (_greyTeal, _grey),
      };

  double _speedMultiplier() => switch (state) {
        OrbState.passive => 0.3,
        OrbState.listening => 1.0,
        OrbState.processing => 2.0,
        OrbState.responding => 1.0,
        OrbState.error => 1.5,
        OrbState.offline => 0.15,
      };

  @override
  bool shouldRepaint(KitaOrbPainter oldDelegate) =>
      state != oldDelegate.state || animationValue != oldDelegate.animationValue;
}
