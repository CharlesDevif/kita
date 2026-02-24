import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/theme/accessibility_tokens.dart';
import 'package:kita/core/theme/kita_theme.dart';
import 'package:kita/core/theme/mix_tokens.dart';

double _contrastRatio(Color c1, Color c2) {
  final l1 = c1.computeLuminance();
  final l2 = c2.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('KitaAccessibility constants', () {
    test('text contrast minimum >= 4.5', () {
      expect(KitaAccessibility.contrastTextMin, greaterThanOrEqualTo(4.5));
    });

    test('touch target minimum >= 48.0', () {
      expect(KitaAccessibility.touchTargetMin, greaterThanOrEqualTo(48.0));
    });

    test('critical touch target >= 56.0', () {
      expect(KitaAccessibility.touchTargetCritical, greaterThanOrEqualTo(56.0));
    });

    test('minimum text size >= 14.0', () {
      expect(KitaAccessibility.textSizeMin, greaterThanOrEqualTo(14.0));
    });

    test('text scale range is valid', () {
      expect(KitaAccessibility.textScaleMin, lessThan(KitaAccessibility.textScaleMax));
    });
  });

  group('Dark theme contrast verification', () {
    test('onBackground on background meets WCAG AA (4.5:1)', () {
      final bg = kitaDarkColors[$kitaBackground]!;
      final fg = kitaDarkColors[$kitaOnBackground]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
    });

    test('onSurface on background meets WCAG AA (4.5:1)', () {
      final bg = kitaDarkColors[$kitaBackground]!;
      final fg = kitaDarkColors[$kitaOnSurface]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
    });

    test('onSurface on surface meets WCAG AA (4.5:1)', () {
      final bg = kitaDarkColors[$kitaSurface]!;
      final fg = kitaDarkColors[$kitaOnSurface]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
    });

    test('primary on background meets AA large text (3:1)', () {
      final bg = kitaDarkColors[$kitaBackground]!;
      final fg = kitaDarkColors[$kitaPrimary]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastLargeTextMin));
    });

    test('accent on background meets AA UI components (3:1)', () {
      final bg = kitaDarkColors[$kitaBackground]!;
      final fg = kitaDarkColors[$kitaAccent]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastUIMin));
    });
  });

  group('Light theme contrast verification', () {
    test('onBackground on background meets WCAG AA (4.5:1)', () {
      final bg = kitaLightColors[$kitaBackground]!;
      final fg = kitaLightColors[$kitaOnBackground]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
    });

    test('onSurface on surface meets WCAG AA (4.5:1)', () {
      final bg = kitaLightColors[$kitaSurface]!;
      final fg = kitaLightColors[$kitaOnSurface]!;
      final ratio = _contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
    });
  });
}
