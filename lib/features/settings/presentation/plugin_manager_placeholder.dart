import 'package:flutter/material.dart';

/// Placeholder for Plugin Manager — will be replaced in E5.
class PluginManagerPlaceholder extends StatelessWidget {
  const PluginManagerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ecran de gestion des plugins',
      child: Scaffold(
        appBar: AppBar(title: const Text('Plugins')),
        body: const Center(
          child: Text('Plugin Manager — Placeholder'),
        ),
      ),
    );
  }
}
