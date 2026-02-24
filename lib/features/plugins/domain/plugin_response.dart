import 'package:flutter/widgets.dart';

enum PluginResponseType { text, image, alert, rich }

class PluginResponse {
  const PluginResponse({
    required this.type,
    required this.content,
    this.metadata,
    this.viewport,
  });

  final PluginResponseType type;
  final String content;
  final Map<String, dynamic>? metadata;

  /// Optional custom widget for plugin-specific UI rendering in the Shell.
  final Widget? viewport;
}
