import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/app.dart';

void main() {
  testWidgets('KitaApp renders shell placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KitaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kita Shell — Placeholder'), findsOneWidget);
  });
}
