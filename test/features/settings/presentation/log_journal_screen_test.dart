import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/settings/presentation/log_journal_screen.dart';

void main() {
  setUp(KitaLogger.clearJournal);
  tearDown(KitaLogger.clearJournal);

  testWidgets('affiche « journal vide » sans entrées', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LogJournalScreen()));
    expect(
      find.text('Aucun événement enregistré pour le moment.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche les entrées du journal', (tester) async {
    KitaLogger('Test').info('Un événement de diagnostic');
    await tester.pumpWidget(const MaterialApp(home: LogJournalScreen()));
    expect(
      find.textContaining('[Test] Un événement de diagnostic'),
      findsOneWidget,
    );
  });

  testWidgets('a un bouton copier accessible', (tester) async {
    KitaLogger('Test').info('entrée');
    await tester.pumpWidget(const MaterialApp(home: LogJournalScreen()));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '') == 'Copier tout le journal',
      ),
      findsOneWidget,
    );
  });
}
