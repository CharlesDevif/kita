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
/// Provides semantics live region and dismiss callback.
class AlertViewport extends StatelessWidget {
  const AlertViewport({
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
    return KitaAlert(
      message: message,
      severity: severity,
      onDismiss: onDismiss,
    );
  }
}
