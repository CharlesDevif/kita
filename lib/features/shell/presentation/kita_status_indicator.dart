import 'package:flutter/material.dart';

import '../domain/shell_mode.dart';

/// Compact status indicator for the KitaShell header.
///
/// Displays connection state with a colored dot and icon.
/// Color-coded: online (teal), offline (grey), degraded (orange), error (red).
/// Accessible: Semantics label describes the status in French.
class KitaStatusIndicator extends StatelessWidget {
  const KitaStatusIndicator({
    required this.status,
    super.key,
  });

  final KitaStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _visualsForStatus();

    return Semantics(
      label: status.semanticsLabel,
      child: Tooltip(
        message: status.semanticsLabel,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: color,
            size: 20,
            semanticLabel: null, // Handled by parent Semantics
          ),
        ),
      ),
    );
  }

  (Color, IconData) _visualsForStatus() => switch (status) {
        KitaStatus.online => (const Color(0xFF0D9488), Icons.wifi),
        KitaStatus.offline => (const Color(0xFF708090), Icons.wifi_off),
        KitaStatus.degraded => (const Color(0xFFF97316), Icons.wifi_1_bar),
        KitaStatus.error => (const Color(0xFFEF4444), Icons.error_outline),
      };
}
