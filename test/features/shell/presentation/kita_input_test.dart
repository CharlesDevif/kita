import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/features/shell/domain/input_state.dart';
import 'package:kita/features/shell/presentation/kita_input.dart';

void main() {
  Widget buildInput({
    InputState state = InputState.idle,
    String transcription = '',
    ValueChanged<String>? onTextSubmit,
    VoidCallback? onMicPressed,
    ValueChanged<String>? onTextChanged,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: KitaInput(
              state: state,
              transcription: transcription,
              onTextSubmit: onTextSubmit,
              onMicPressed: onMicPressed,
              onTextChanged: onTextChanged,
            ),
          ),
        ),
      ),
    );
  }

  group('KitaInput rendering', () {
    testWidgets('renders in idle state', (tester) async {
      await tester.pumpWidget(buildInput());
      expect(find.byType(KitaInput), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(buildInput());
      expect(find.text('Parle ou ecris a Kita'), findsOneWidget);
    });

    testWidgets('shows mic button', (tester) async {
      await tester.pumpWidget(buildInput());
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });
  });

  group('KitaInput states', () {
    testWidgets('idle state shows mic_none icon', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.idle));
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('listening state shows mic icon', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.listening));
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('listening state shows wave indicator', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.listening));
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });

    testWidgets('disabled state disables text field', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.disabled));
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('idle state enables text field', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.idle));
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
    });
  });

  group('KitaInput text interaction', () {
    testWidgets('calls onTextSubmit when Enter pressed', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        buildInput(onTextSubmit: (text) => submitted = text),
      );

      await tester.enterText(find.byType(TextField), 'Bonjour Kita');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, 'Bonjour Kita');
    });

    testWidgets('clears text field after submit', (tester) async {
      await tester.pumpWidget(
        buildInput(onTextSubmit: (_) {}),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('does not submit empty text', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        buildInput(onTextSubmit: (text) => submitted = text),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, isNull);
    });

    testWidgets('calls onTextChanged when typing', (tester) async {
      String? changed;
      await tester.pumpWidget(
        buildInput(onTextChanged: (text) => changed = text),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(changed, 'Hello');
    });
  });

  group('KitaInput mic interaction', () {
    testWidgets('calls onMicPressed when mic tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        buildInput(onMicPressed: () => pressed = true),
      );

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('mic not tappable when disabled', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        buildInput(
          state: InputState.disabled,
          onMicPressed: () => pressed = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      expect(pressed, isFalse);
    });
  });

  group('KitaInput transcription', () {
    testWidgets('shows transcription text when listening', (tester) async {
      await tester.pumpWidget(
        buildInput(
          state: InputState.listening,
          transcription: 'Decris ce que tu vois',
        ),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Decris ce que tu vois');
    });

    testWidgets('updates transcription on change', (tester) async {
      await tester.pumpWidget(
        buildInput(state: InputState.listening, transcription: 'De'),
      );
      await tester.pump();

      await tester.pumpWidget(
        buildInput(state: InputState.listening, transcription: 'Decris'),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Decris');
    });
  });

  group('KitaInput Semantics', () {
    testWidgets('has main semantics label', (tester) async {
      await tester.pumpWidget(buildInput());
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Parle ou ecris a Kita',
        ),
        findsOneWidget,
      );
    });

    testWidgets('mic button has semantics when idle', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.idle));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Activer le micro',
        ),
        findsOneWidget,
      );
    });

    testWidgets('mic button has semantics when listening', (tester) async {
      await tester.pumpWidget(buildInput(state: InputState.listening));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Arreter le micro',
        ),
        findsOneWidget,
      );
    });
  });

  group('KitaInput sizing', () {
    testWidgets('mic button is 56x56', (tester) async {
      await tester.pumpWidget(buildInput());

      final micBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(micBox.width, 56.0);
      expect(micBox.height, 56.0);
    });
  });
}
