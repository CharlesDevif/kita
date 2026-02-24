import 'package:flutter/material.dart';

/// Placeholder for Memory View — will be replaced in E4.
class MemoryViewPlaceholder extends StatelessWidget {
  const MemoryViewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ecran de visualisation de la memoire',
      child: Scaffold(
        appBar: AppBar(title: const Text('Memoire')),
        body: const Center(
          child: Text('Memory View — Placeholder'),
        ),
      ),
    );
  }
}
