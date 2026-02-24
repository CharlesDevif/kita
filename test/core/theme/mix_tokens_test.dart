import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/theme/kita_theme.dart';
import 'package:kita/core/theme/mix_tokens.dart';

void main() {
  group('Color tokens', () {
    test('all color tokens are mapped in dark theme', () {
      final tokens = [
        $kitaPrimary,
        $kitaPrimaryVariant,
        $kitaAccent,
        $kitaAccentVariant,
        $kitaBackground,
        $kitaSurface,
        $kitaOnBackground,
        $kitaOnSurface,
        $kitaSuccess,
        $kitaWarning,
        $kitaError,
        $kitaInfo,
      ];
      for (final token in tokens) {
        expect(kitaDarkColors.containsKey(token), isTrue,
            reason: '${token.name} missing in dark colors');
      }
    });

    test('all color tokens are mapped in light theme', () {
      final tokens = [
        $kitaPrimary,
        $kitaPrimaryVariant,
        $kitaAccent,
        $kitaAccentVariant,
        $kitaBackground,
        $kitaSurface,
        $kitaOnBackground,
        $kitaOnSurface,
        $kitaSuccess,
        $kitaWarning,
        $kitaError,
        $kitaInfo,
      ];
      for (final token in tokens) {
        expect(kitaLightColors.containsKey(token), isTrue,
            reason: '${token.name} missing in light colors');
      }
    });
  });

  group('TextStyle tokens', () {
    test('all text style tokens are mapped', () {
      final tokens = [
        $kitaDisplay,
        $kitaHeading1,
        $kitaHeading2,
        $kitaBody,
        $kitaBodyLarge,
        $kitaCaption,
        $kitaButton,
      ];
      for (final token in tokens) {
        expect(kitaTextStyles.containsKey(token), isTrue,
            reason: '${token.name} missing in text styles');
      }
    });
  });

  group('Space tokens', () {
    test('all space tokens are mapped', () {
      final tokens = [
        $kitaSpaceXs,
        $kitaSpaceSm,
        $kitaSpaceMd,
        $kitaSpaceLg,
        $kitaSpaceXl,
        $kitaSpace2xl,
      ];
      for (final token in tokens) {
        expect(kitaSpaces.containsKey(token), isTrue,
            reason: '${token.name} missing in spaces');
      }
    });

    test('spacing values follow 4px multiples (8px grid)', () {
      for (final entry in kitaSpaces.entries) {
        expect(entry.value % 4, equals(0),
            reason: '${entry.key.name} = ${entry.value} is not a multiple of 4');
      }
    });
  });

  group('Radius tokens', () {
    test('all radius tokens are mapped', () {
      final tokens = [
        $kitaRadiusSm,
        $kitaRadiusMd,
        $kitaRadiusLg,
        $kitaRadiusXl,
        $kitaRadiusFull,
      ];
      for (final token in tokens) {
        expect(kitaRadii.containsKey(token), isTrue,
            reason: '${token.name} missing in radii');
      }
    });
  });
}
