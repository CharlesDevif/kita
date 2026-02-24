import 'package:flutter/material.dart';

/// Placeholder for Forget screen (right to be forgotten) — will be replaced in E4.
class ForgetPlaceholder extends StatelessWidget {
  const ForgetPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Ecran du droit a l'oubli",
      child: Scaffold(
        appBar: AppBar(title: const Text("Droit a l'oubli")),
        body: const Center(
          child: Text('Forget — Placeholder'),
        ),
      ),
    );
  }
}
