import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_bridge.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/settings/presentation/diagnostic_screen.dart';

class _FakeBridge implements GemmaBridge {
  _FakeBridge(this._status);
  final GemmaModelStatus _status;

  @override
  Future<GemmaModelStatus> checkStatus() async => _status;

  @override
  Future<GemmaVisionResult> describeImage(Uint8List bytes, {String? prompt}) async =>
      const GemmaVisionResult(description: 'une scène de test');

  @override
  Future<GemmaCompletionResult> complete(String prompt,
          {String? systemPrompt, int? maxTokens}) async =>
      const GemmaCompletionResult(text: '');

  @override
  Stream<String> completeStream(String prompt,
          {String? systemPrompt, int? maxTokens}) =>
      const Stream.empty();

  @override
  Stream<String> describeImageStream(Uint8List bytes, {String? prompt}) =>
      Stream.value('une scène de test');

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  Widget app(GemmaModelStatus status) => ProviderScope(
        overrides: [
          gemmaBridgeProvider.overrideWithValue(_FakeBridge(status)),
        ],
        child: const MaterialApp(home: DiagnosticScreen()),
      );

  testWidgets('affiche « Modèle chargé » quand le statut est ready',
      (tester) async {
    await tester.pumpWidget(app(GemmaModelStatus.ready));
    await tester.pump(); // résout le FutureProvider
    expect(find.textContaining('Modèle chargé'), findsOneWidget);
  });

  testWidgets('affiche « Modèle indisponible » quand le statut est error',
      (tester) async {
    await tester.pumpWidget(app(GemmaModelStatus.error));
    await tester.pump();
    expect(find.textContaining('Modèle indisponible'), findsOneWidget);
  });

  testWidgets('a des Semantics descriptifs sur l\'état et le bouton',
      (tester) async {
    await tester.pumpWidget(app(GemmaModelStatus.ready));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').contains('État du modèle'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').contains('Tester la reconnaissance'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('le bouton de test respecte la cible tactile critique (56px)',
      (tester) async {
    await tester.pumpWidget(app(GemmaModelStatus.ready));
    await tester.pump();
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets('le test vision affiche et conserve le résultat',
      (tester) async {
    await tester.pumpWidget(app(GemmaModelStatus.ready));
    await tester.pump();
    // L'asset test_scene.jpg n'existe pas dans le bundle de test : le flux
    // d'échec doit produire un message honnête, jamais un silence.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp('scène de test|a échoué')),
      findsOneWidget,
    );
  });
}
