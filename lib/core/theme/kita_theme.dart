import 'package:flutter/material.dart';
import 'package:mix/mix.dart';

import 'mix_tokens.dart';

// ===================================================================
// KitaTheme — Living Aura identity via Mix design tokens
// ===================================================================

/// Dark theme color mapping — default mode.
///
/// Primary teal #0D9488 (trust + calm)
/// Accent violet #8B5CF6 (intelligence + innovation)
/// Background charcoal #1A1A2E
final Map<ColorToken, Color> kitaDarkColors = {
  $kitaPrimary: const Color(0xFF0D9488),
  $kitaPrimaryVariant: const Color(0xFF0F766E),
  $kitaAccent: const Color(0xFF8B5CF6),
  $kitaAccentVariant: const Color(0xFF7C3AED),
  $kitaBackground: const Color(0xFF1A1A2E),
  $kitaSurface: const Color(0xFF16213E),
  $kitaOnBackground: const Color(0xFFF8FAFC),
  $kitaOnSurface: const Color(0xFFE2E8F0),
  $kitaSuccess: const Color(0xFF10B981),
  $kitaWarning: const Color(0xFFF97316),
  $kitaError: const Color(0xFFEF4444),
  $kitaInfo: const Color(0xFF3B82F6),
};

/// Light theme color mapping — inverted backgrounds, same brand colors.
final Map<ColorToken, Color> kitaLightColors = {
  $kitaPrimary: const Color(0xFF0D9488),
  $kitaPrimaryVariant: const Color(0xFF0F766E),
  $kitaAccent: const Color(0xFF8B5CF6),
  $kitaAccentVariant: const Color(0xFF7C3AED),
  $kitaBackground: const Color(0xFFF8FAFC),
  $kitaSurface: const Color(0xFFF1F5F9),
  $kitaOnBackground: const Color(0xFF1E293B),
  $kitaOnSurface: const Color(0xFF334155),
  $kitaSuccess: const Color(0xFF059669),
  $kitaWarning: const Color(0xFFEA580C),
  $kitaError: const Color(0xFFDC2626),
  $kitaInfo: const Color(0xFF2563EB),
};

/// Typography tokens — same for dark and light themes.
///
/// Space Grotesk for headings (geometric, bold, futuristic).
/// Nunito for body text (humanist, soft, warm).
final Map<TextStyleToken, TextStyle> kitaTextStyles = {
  $kitaDisplay: const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  ),
  $kitaHeading1: const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  ),
  $kitaHeading2: const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  ),
  $kitaBody: const TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  $kitaBodyLarge: const TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  $kitaCaption: const TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  ),
  $kitaButton: const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.2,
  ),
};

/// Space tokens — 8px grid system.
final Map<SpaceToken, double> kitaSpaces = {
  $kitaSpaceXs: 4.0,
  $kitaSpaceSm: 8.0,
  $kitaSpaceMd: 16.0,
  $kitaSpaceLg: 24.0,
  $kitaSpaceXl: 32.0,
  $kitaSpace2xl: 48.0,
};

/// Radius tokens.
final Map<RadiusToken, Radius> kitaRadii = {
  $kitaRadiusSm: const Radius.circular(4),
  $kitaRadiusMd: const Radius.circular(8),
  $kitaRadiusLg: const Radius.circular(12),
  $kitaRadiusXl: const Radius.circular(16),
  $kitaRadiusFull: const Radius.circular(999),
};

/// Builds a [MixThemeData] for the given brightness.
MixThemeData buildKitaMixTheme(Brightness brightness) {
  final colors =
      brightness == Brightness.dark ? kitaDarkColors : kitaLightColors;

  return MixThemeData(
    colors: colors,
    textStyles: kitaTextStyles,
    spaces: kitaSpaces,
    radii: kitaRadii,
  );
}
