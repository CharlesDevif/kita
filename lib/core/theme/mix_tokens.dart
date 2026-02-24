import 'package:mix/mix.dart';

// === Color Tokens ===

/// Primary colors — Teal chaud (confiance + calme)
const $kitaPrimary = ColorToken('kita.primary');
const $kitaPrimaryVariant = ColorToken('kita.primary.variant');

/// Accent colors — Violet electrique (intelligence + innovation)
const $kitaAccent = ColorToken('kita.accent');
const $kitaAccentVariant = ColorToken('kita.accent.variant');

/// Background colors
const $kitaBackground = ColorToken('kita.background');
const $kitaSurface = ColorToken('kita.surface');

/// On-colors (text/icons on backgrounds)
const $kitaOnBackground = ColorToken('kita.onBackground');
const $kitaOnSurface = ColorToken('kita.onSurface');

/// Semantic colors
const $kitaSuccess = ColorToken('kita.success');
const $kitaWarning = ColorToken('kita.warning');
const $kitaError = ColorToken('kita.error');
const $kitaInfo = ColorToken('kita.info');

// === TextStyle Tokens ===

const $kitaDisplay = TextStyleToken('kita.display');
const $kitaHeading1 = TextStyleToken('kita.heading1');
const $kitaHeading2 = TextStyleToken('kita.heading2');
const $kitaBody = TextStyleToken('kita.body');
const $kitaBodyLarge = TextStyleToken('kita.bodyLarge');
const $kitaCaption = TextStyleToken('kita.caption');
const $kitaButton = TextStyleToken('kita.button');

// === Space Tokens (8px grid) ===

const $kitaSpaceXs = SpaceToken('kita.space.xs'); // 4px
const $kitaSpaceSm = SpaceToken('kita.space.sm'); // 8px
const $kitaSpaceMd = SpaceToken('kita.space.md'); // 16px
const $kitaSpaceLg = SpaceToken('kita.space.lg'); // 24px
const $kitaSpaceXl = SpaceToken('kita.space.xl'); // 32px
const $kitaSpace2xl = SpaceToken('kita.space.2xl'); // 48px

// === Radius Tokens ===

const $kitaRadiusSm = RadiusToken('kita.radius.sm'); // 4px
const $kitaRadiusMd = RadiusToken('kita.radius.md'); // 8px
const $kitaRadiusLg = RadiusToken('kita.radius.lg'); // 12px
const $kitaRadiusXl = RadiusToken('kita.radius.xl'); // 16px
const $kitaRadiusFull = RadiusToken('kita.radius.full'); // 999px (pill)
