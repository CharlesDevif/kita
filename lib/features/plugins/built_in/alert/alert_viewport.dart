import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/kita_alert.dart';

/// State for the alert viewport.
class AlertViewportState {
  const AlertViewportState({
    required this.message,
    required this.severity,
  });

  final String message;
  final AlertSeverity severity;
}

/// Wrapper widget around [KitaAlert] for the plugin viewport.
///
/// Provides a Semantics live region for automatic VoiceOver/TalkBack
/// announcement, a dismiss callback, and a fade-out animation (300ms)
/// when the alert is dismissed. Respects `prefers-reduced-motion` via
/// [MediaQuery.disableAnimations].
class AlertViewport extends StatefulWidget {
  const AlertViewport({
    required this.message,
    required this.severity,
    this.onDismiss,
    super.key,
  });

  final String message;
  final AlertSeverity severity;
  final VoidCallback? onDismiss;

  /// Duration of the fade-out animation.
  static const fadeOutDuration = Duration(milliseconds: 300);

  @override
  State<AlertViewport> createState() => _AlertViewportState();
}

class _AlertViewportState extends State<AlertViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AlertViewport.fadeOutDuration,
      value: 1.0, // Start fully visible
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (reduceMotion) {
      // Skip animation when prefers-reduced-motion is set
      widget.onDismiss?.call();
    } else {
      _controller.reverse().then((_) {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Alerte : ${widget.message}',
      child: FadeTransition(
        opacity: _controller,
        child: KitaAlert(
          message: widget.message,
          severity: widget.severity,
          onDismiss: widget.onDismiss != null ? _handleDismiss : null,
        ),
      ),
    );
  }
}
