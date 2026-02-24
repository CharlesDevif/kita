import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mix/mix.dart';

import 'package:kita/core/theme/kita_theme.dart';
import 'package:kita/core/theme/mix_tokens.dart';

void main() {
  group('buildKitaMixTheme', () {
    test('dark theme returns valid MixThemeData', () {
      final theme = buildKitaMixTheme(Brightness.dark);
      expect(theme, isA<MixThemeData>());
    });

    test('light theme returns valid MixThemeData', () {
      final theme = buildKitaMixTheme(Brightness.light);
      expect(theme, isA<MixThemeData>());
    });

    test('dark and light backgrounds differ', () {
      expect(
        kitaDarkColors[$kitaBackground],
        isNot(equals(kitaLightColors[$kitaBackground])),
      );
      expect(
        kitaDarkColors[$kitaSurface],
        isNot(equals(kitaLightColors[$kitaSurface])),
      );
    });

    test('primary and accent are same in dark and light', () {
      expect(
        kitaDarkColors[$kitaPrimary],
        equals(kitaLightColors[$kitaPrimary]),
      );
      expect(
        kitaDarkColors[$kitaAccent],
        equals(kitaLightColors[$kitaAccent]),
      );
    });
  });

  group('Token resolution via MixTheme', () {
    testWidgets('color token resolves in dark mode', (tester) async {
      late Color resolvedPrimary;

      await tester.pumpWidget(
        MixTheme(
          data: buildKitaMixTheme(Brightness.dark),
          child: Builder(
            builder: (context) {
              resolvedPrimary = $kitaPrimary.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedPrimary, const Color(0xFF0D9488));
    });

    testWidgets('space token resolves correctly', (tester) async {
      late double resolvedSpace;

      await tester.pumpWidget(
        MixTheme(
          data: buildKitaMixTheme(Brightness.dark),
          child: Builder(
            builder: (context) {
              resolvedSpace = $kitaSpaceMd.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedSpace, 16.0);
    });
  });
}
