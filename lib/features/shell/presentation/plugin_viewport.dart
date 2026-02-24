import 'package:flutter/material.dart';

/// Sandboxed plugin display area in the KitaShell viewport zone.
///
/// Displays the active plugin's widget in a scrollable, constrained container.
/// Falls back to plain text display when no custom viewport is provided.
/// Marked as a live region for VoiceOver automatic announcements.
class PluginViewport extends StatelessWidget {
  const PluginViewport({
    this.pluginWidget,
    this.fallbackText,
    super.key,
  });

  /// Plugin-provided widget to display. If null, [fallbackText] is shown.
  final Widget? pluginWidget;

  /// Plain text fallback when the plugin has no custom viewport.
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Zone de contenu plugin',
      child: ClipRect(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: pluginWidget ?? _buildFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (fallbackText == null || fallbackText!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        label: fallbackText,
        child: Text(
          fallbackText!,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
