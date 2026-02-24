import 'package:flutter/material.dart';

/// Severity levels for KitaAlert.
enum AlertSeverity {
  /// Red background, 3x heavy vibration — obstacle, danger.
  immediate,

  /// Orange background, 1x medium vibration — preventive warning.
  preventive,
}

/// Full-viewport critical alert widget.
///
/// Takes over the entire viewport for immediate visibility.
/// Auto-announced by VoiceOver via live region semantics.
/// Disappears after 5s or when dismissed.
class KitaAlert extends StatelessWidget {
  const KitaAlert({
    required this.message,
    required this.severity,
    this.onDismiss,
    super.key,
  });

  final String message;
  final AlertSeverity severity;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (bgColor, iconData) = _visualsForSeverity();

    return Semantics(
      liveRegion: true,
      label: 'Alerte : $message',
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  size: 80,
                  color: const Color(0xFFF8FAFC),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),
                if (onDismiss != null)
                  Semantics(
                    button: true,
                    label: 'Fermer alerte',
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Material(
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.2),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onDismiss,
                          customBorder: const CircleBorder(),
                          child: const Center(
                            child: Icon(
                              Icons.close,
                              color: Color(0xFFF8FAFC),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData) _visualsForSeverity() => switch (severity) {
        AlertSeverity.immediate => (const Color(0xFFEF4444), Icons.warning_amber),
        AlertSeverity.preventive => (const Color(0xFFF97316), Icons.info_outline),
      };
}
