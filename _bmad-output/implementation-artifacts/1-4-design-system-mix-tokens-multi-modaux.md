# Story 1.4: Design System Mix et tokens multi-modaux

Status: ready-for-dev

## Story

As a **developpeur**,
I want **le framework Mix configure avec tous les design tokens (visuels, vocaux, haptiques)**,
So that **les composants UI sont styles de maniere coherente avec l'identite Living Aura**.

**Depends on:** Story 1.3 (State management Riverpod DI)

## Acceptance Criteria

1. **Given** Riverpod est configure (Story 1.3) **When** le design system est implemente **Then** `core/theme/kita_theme.dart` configure Mix avec l'identite Living Aura

2. **And** `core/theme/mix_tokens.dart` definit les tokens visuels : couleurs (teal `#0D9488` primary, violet `#8B5CF6` accent, charbon `#1A1A2E` background), typographie (Space Grotesk titres, Nunito corps), spacing grille 8px, border radii

3. **And** `core/theme/multi_modal_tokens.dart` definit les durees d'animation (micro 150ms, transitions 300ms, etats 500ms) et les intensites haptiques

4. **And** `core/theme/accessibility_tokens.dart` definit les contraintes a11y (contraste min 4.5:1, taille tactile min 48px, taille texte min 14px)

5. **And** le mode clair et le mode sombre sont definis

6. **And** les fonts Space Grotesk et Nunito sont incluses dans `assets/`

## Tasks / Subtasks

### Task 1 : Verifier les prerequis (AC: #1)

- [ ] Verifier que Story 1.3 est done (Riverpod configure, `ProviderScope` dans `main.dart`)
- [ ] Verifier que `pubspec.yaml` contient `mix: ^1.7.0` (ajoute en Story 1.1)
- [ ] Verifier que la structure `lib/core/theme/` existe

### Task 2 : Telecharger et integrer les fonts (AC: #6)

- [ ] Telecharger les fichiers TTF de **Space Grotesk** depuis Google Fonts :
  - `SpaceGrotesk-Light.ttf` (300)
  - `SpaceGrotesk-Regular.ttf` (400)
  - `SpaceGrotesk-Medium.ttf` (500)
  - `SpaceGrotesk-SemiBold.ttf` (600)
  - `SpaceGrotesk-Bold.ttf` (700)
- [ ] Telecharger les fichiers TTF de **Nunito** depuis Google Fonts :
  - `Nunito-Regular.ttf` (400)
  - `Nunito-Medium.ttf` (500)
  - `Nunito-SemiBold.ttf` (600)
  - `Nunito-Bold.ttf` (700)
- [ ] Creer le repertoire `assets/fonts/`
- [ ] Placer tous les fichiers TTF dans `assets/fonts/`
- [ ] Ajouter la declaration des fonts dans `pubspec.yaml` :

```yaml
flutter:
  fonts:
    - family: SpaceGrotesk
      fonts:
        - asset: assets/fonts/SpaceGrotesk-Light.ttf
          weight: 300
        - asset: assets/fonts/SpaceGrotesk-Regular.ttf
          weight: 400
        - asset: assets/fonts/SpaceGrotesk-Medium.ttf
          weight: 500
        - asset: assets/fonts/SpaceGrotesk-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/SpaceGrotesk-Bold.ttf
          weight: 700
    - family: Nunito
      fonts:
        - asset: assets/fonts/Nunito-Regular.ttf
          weight: 400
        - asset: assets/fonts/Nunito-Medium.ttf
          weight: 500
        - asset: assets/fonts/Nunito-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Nunito-Bold.ttf
          weight: 700
```

**Note :** On integre les fonts en local (pas via `google_fonts` package) pour garantir le fonctionnement offline et eviter le flash de font non chargee. C'est conforme a l'approche local-first de Kita.

### Task 3 : Creer les tokens visuels Mix (AC: #2)

- [ ] Creer `lib/core/theme/mix_tokens.dart`
- [ ] Definir les **ColorTokens** :

```dart
import 'package:flutter/material.dart';
import 'package:mix/mix.dart';

// --- Color Tokens ---

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
```

- [ ] Definir les **TextStyleTokens** :

```dart
// --- TextStyle Tokens ---

const $kitaDisplay = TextStyleToken('kita.display');
const $kitaHeading1 = TextStyleToken('kita.heading1');
const $kitaHeading2 = TextStyleToken('kita.heading2');
const $kitaBody = TextStyleToken('kita.body');
const $kitaBodyLarge = TextStyleToken('kita.bodyLarge');
const $kitaCaption = TextStyleToken('kita.caption');
const $kitaButton = TextStyleToken('kita.button');
```

- [ ] Definir les **SpaceTokens** (grille 8px) :

```dart
// --- Space Tokens ---

const $kitaSpaceXs = SpaceToken('kita.space.xs');     // 4px
const $kitaSpaceSm = SpaceToken('kita.space.sm');     // 8px
const $kitaSpaceMd = SpaceToken('kita.space.md');     // 16px
const $kitaSpaceLg = SpaceToken('kita.space.lg');     // 24px
const $kitaSpaceXl = SpaceToken('kita.space.xl');     // 32px
const $kitaSpace2xl = SpaceToken('kita.space.2xl');   // 48px
```

- [ ] Definir les **RadiusTokens** :

```dart
// --- Radius Tokens ---

const $kitaRadiusSm = RadiusToken('kita.radius.sm');   // 4px
const $kitaRadiusMd = RadiusToken('kita.radius.md');   // 8px
const $kitaRadiusLg = RadiusToken('kita.radius.lg');   // 12px
const $kitaRadiusXl = RadiusToken('kita.radius.xl');   // 16px
const $kitaRadiusFull = RadiusToken('kita.radius.full'); // 999px (pill)
```

### Task 4 : Creer les tokens multi-modaux (AC: #3)

- [ ] Creer `lib/core/theme/multi_modal_tokens.dart`
- [ ] Definir les tokens de durees d'animation :

```dart
/// Animation duration tokens — coherent across the app.
/// Uses [DurationToken] from Mix for integration with style system.
///
/// Durees definies dans le UX spec :
/// - Micro interactions : 150ms (feedback instantane)
/// - Transitions de page/viewport : 300ms (passif -> actif)
/// - Animations d'etat : 500ms (responding -> passif)
class KitaDurations {
  KitaDurations._();

  /// Micro-interactions : feedback bouton, prise en charge
  static const Duration micro = Duration(milliseconds: 150);

  /// Transitions d'ecran, viewport slide, orbe resize
  static const Duration transition = Duration(milliseconds: 300);

  /// Animations d'etat : orbe responding -> passif
  static const Duration state = Duration(milliseconds: 500);

  /// Aucune animation (prefers-reduced-motion)
  static const Duration zero = Duration.zero;
}
```

- [ ] Definir les tokens d'intensites haptiques :

```dart
/// Haptic intensity tokens for multi-modal feedback.
///
/// 3 patterns definis dans le UX spec :
/// - confirmation : feedback positif, leger
/// - warning : attention requise, moyen
/// - danger : alerte critique, fort + repete
///
/// Les valeurs sont des abstractions — le HapticService (E3)
/// les mappe vers les APIs natives :
/// - iOS : UIImpactFeedbackGenerator (light/medium/heavy)
/// - Android : VibrationEffect (amplitudes)
enum HapticIntensity {
  /// Feedback leger — confirmation, prise en charge
  light,

  /// Feedback moyen — warning, attention
  medium,

  /// Feedback fort — danger, alerte critique
  heavy,
}

/// Haptic patterns for different feedback types.
///
/// Chaque pattern definit une sequence de vibrations.
/// Le HapticService (E3) implemente les patterns natifs.
class KitaHapticPatterns {
  KitaHapticPatterns._();

  /// Confirmation : 1 vibration legere
  static const HapticPattern confirmation = HapticPattern(
    intensity: HapticIntensity.light,
    repetitions: 1,
  );

  /// Warning : 2 vibrations moyennes
  static const HapticPattern warning = HapticPattern(
    intensity: HapticIntensity.medium,
    repetitions: 2,
  );

  /// Danger : 3 vibrations fortes
  static const HapticPattern danger = HapticPattern(
    intensity: HapticIntensity.heavy,
    repetitions: 3,
  );

  /// Info : 1 vibration legere (identique confirmation pour l'instant)
  static const HapticPattern info = HapticPattern(
    intensity: HapticIntensity.light,
    repetitions: 1,
  );
}

/// A haptic feedback pattern definition.
class HapticPattern {
  const HapticPattern({
    required this.intensity,
    required this.repetitions,
  });

  final HapticIntensity intensity;
  final int repetitions;
}
```

### Task 5 : Creer les tokens d'accessibilite (AC: #4)

- [ ] Creer `lib/core/theme/accessibility_tokens.dart`
- [ ] Definir les contraintes d'accessibilite :

```dart
/// Accessibility constraint tokens for WCAG 2.1 AA+ compliance.
///
/// Ces valeurs sont des minimums absolus — les composants
/// peuvent (et devraient) depasser ces seuils.
class KitaAccessibility {
  KitaAccessibility._();

  // --- Contrast Ratios ---

  /// Minimum contrast ratio for normal text (WCAG AA)
  static const double contrastTextMin = 4.5;

  /// Minimum contrast ratio for large text (WCAG AA)
  static const double contrastLargeTextMin = 3.0;

  /// Minimum contrast ratio for UI components (WCAG AA)
  static const double contrastUIMin = 3.0;

  /// Target contrast ratio for primary text (WCAG AAA)
  static const double contrastTextTarget = 7.0;

  // --- Touch Targets ---

  /// Minimum touch target size (WCAG)
  static const double touchTargetMin = 48.0;

  /// Recommended touch target size for critical actions
  static const double touchTargetCritical = 56.0;

  /// Minimum spacing between touch targets
  static const double touchTargetSpacing = 8.0;

  // --- Text Sizes ---

  /// Minimum text size (never smaller than this)
  static const double textSizeMin = 14.0;

  /// Default body text size
  static const double textSizeBody = 16.0;

  /// Text scale factor range — user adjustable
  static const double textScaleMin = 0.8;
  static const double textScaleMax = 2.0;

  // --- Focus ---

  /// Focus indicator width
  static const double focusIndicatorWidth = 3.0;

  /// Focus indicator color = accent violet
  /// (resolved from $kitaAccent token at runtime)

  // --- Animation ---

  /// Line height multiplier for readable text
  static const double lineHeightMultiplier = 1.5;
}
```

### Task 6 : Creer le theme Kita — dark et light (AC: #1, #5)

- [ ] Creer `lib/core/theme/kita_theme.dart`
- [ ] Definir le theme sombre (mode par defaut) et le theme clair :

```dart
import 'package:flutter/material.dart';
import 'package:mix/mix.dart';

import 'mix_tokens.dart';

// ===================================================================
// KitaTheme — Living Aura identity via Mix design tokens
// ===================================================================

/// Dark theme color mapping — default mode.
///
/// Palette definie dans UX spec :
/// - Primary teal #0D9488 (confiance + calme)
/// - Accent violet #8B5CF6 (intelligence + innovation)
/// - Background charbon #1A1A2E
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

/// Light theme color mapping.
///
/// Same primary/accent, inverted backgrounds.
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
/// Nunito for body text (humaniste, douce, chaleureuse).
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
///
/// Usage in app.dart:
/// ```dart
/// MixTheme(
///   data: buildKitaMixTheme(Brightness.dark),
///   child: MaterialApp.router(...)
/// )
/// ```
MixThemeData buildKitaMixTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? kitaDarkColors
      : kitaLightColors;

  return MixThemeData(
    colors: colors,
    textStyles: kitaTextStyles,
    spaces: kitaSpaces,
    radii: kitaRadii,
  );
}
```

**Note :** La version stable Mix 1.7.0 utilise `MixTheme` + `MixThemeData`. Si le projet migre vers Mix 2.0.0-rc, l'API equivalent est `MixScope` avec les memes maps de tokens. Les tokens eux-memes sont identiques entre les deux versions.

### Task 7 : Integrer le theme dans app.dart (AC: #1, #5)

- [ ] Modifier `lib/app.dart` pour wrapper l'app avec `MixTheme`
- [ ] Ajouter un provider Riverpod pour le brightness mode :

```dart
// In lib/core/theme/brightness_mode_provider.dart (or inline in app.dart)
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'brightness_mode_provider.g.dart';

@riverpod
class BrightnessMode extends _$BrightnessMode {
  @override
  Brightness build() => Brightness.dark;

  void toggle() => state = state == Brightness.dark ? Brightness.light : Brightness.dark;
}
```

- [ ] Modifier `lib/app.dart` pour utiliser ce provider :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mix/mix.dart';

import 'core/theme/brightness_mode_provider.dart';
import 'core/theme/kita_theme.dart';

class KitaApp extends ConsumerWidget {
  const KitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessModeProvider);

    return MixTheme(
      data: buildKitaMixTheme(brightness),
      child: MaterialApp.router(
        title: 'Kita',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          fontFamily: 'Nunito',
        ),
        // routerConfig will be added in Story 1.5
      ),
    );
  }
}
```

**Note :** `MaterialApp` est conserve comme base pour les fonctionnalites Flutter natives (navigation, media query, etc.) mais les composants Kita sont styles exclusivement avec Mix. Le `ThemeData` est minimal — il definit le brightness et le background pour les composants Flutter natifs qui pourraient etre utilises temporairement.

### Task 8 : Ecrire les tests (AC: #1-#6)

- [ ] Creer `test/core/theme/mix_tokens_test.dart` :
  - Test que tous les ColorTokens sont definis (non null)
  - Test que tous les TextStyleTokens sont definis
  - Test que tous les SpaceTokens sont definis
  - Test que tous les RadiusTokens sont definis
  - Test que les valeurs de spacing suivent la grille 8px (multiples de 4)

- [ ] Creer `test/core/theme/kita_theme_test.dart` :
  - Test que `buildKitaMixTheme(Brightness.dark)` retourne un `MixThemeData` valide
  - Test que `buildKitaMixTheme(Brightness.light)` retourne un `MixThemeData` valide
  - Test que les couleurs dark et light sont differentes pour les backgrounds
  - Test que les couleurs primary et accent sont identiques en dark et light
  - Test de resolution des tokens via `MixTheme` widget :
  ```dart
  testWidgets('tokens resolve correctly in dark mode', (tester) async {
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
  ```

- [ ] Creer `test/core/theme/multi_modal_tokens_test.dart` :
  - Test que les durees sont coherentes : micro < transition < state
  - Test que `KitaDurations.micro.inMilliseconds` == 150
  - Test que `KitaDurations.transition.inMilliseconds` == 300
  - Test que `KitaDurations.state.inMilliseconds` == 500
  - Test que les patterns haptiques sont corrects (confirmation = 1 rep, warning = 2, danger = 3)

- [ ] Creer `test/core/theme/accessibility_tokens_test.dart` :
  - Test que `contrastTextMin` >= 4.5
  - Test que `touchTargetMin` >= 48.0
  - Test que `textSizeMin` >= 14.0
  - Test de contraste reel entre couleurs dark theme :
  ```dart
  test('dark theme text contrast meets WCAG AA', () {
    const background = Color(0xFF1A1A2E);
    const foreground = Color(0xFFF8FAFC);
    final ratio = _contrastRatio(background, foreground);
    expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
  });

  test('dark theme secondary text contrast meets WCAG AA', () {
    const background = Color(0xFF1A1A2E);
    const secondary = Color(0xFFE2E8F0);
    final ratio = _contrastRatio(background, secondary);
    expect(ratio, greaterThanOrEqualTo(KitaAccessibility.contrastTextMin));
  });
  ```
  - Implementer `_contrastRatio()` en utilisant `Color.computeLuminance()` (Flutter built-in) :
  ```dart
  double _contrastRatio(Color c1, Color c2) {
    final l1 = c1.computeLuminance();
    final l2 = c2.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }
  ```
  **Note :** Ne PAS implementer manuellement `_relativeLuminance()` avec `color.red / 255.0` etc. — les getters `Color.red`, `Color.green`, `Color.blue` (int 0-255) sont **deprecated depuis Flutter 3.27**. Utiliser `Color.computeLuminance()` qui gere correctement le nouveau Color API wide-gamut (voir Pitfall #11).

- [ ] Executer `flutter test` — tous les tests doivent passer

### Task 9 : Verification finale

- [ ] `dart analyze` clean (0 warnings, 0 errors)
- [ ] `flutter test` pass
- [ ] Verifier que les fonts TTF sont presents dans `assets/fonts/`
- [ ] Verifier que `pubspec.yaml` declare correctement les fonts
- [ ] Verifier que `app.dart` wrappe l'app dans `MixTheme`
- [ ] Verifier la structure :
  ```
  lib/core/theme/
  ├── kita_theme.dart             # MixTheme config, dark/light themes
  ├── mix_tokens.dart             # ColorToken, TextStyleToken, SpaceToken, RadiusToken
  ├── multi_modal_tokens.dart     # KitaDurations, HapticIntensity, HapticPattern
  └── accessibility_tokens.dart   # KitaAccessibility constants

  assets/fonts/
  ├── SpaceGrotesk-Light.ttf
  ├── SpaceGrotesk-Regular.ttf
  ├── SpaceGrotesk-Medium.ttf
  ├── SpaceGrotesk-SemiBold.ttf
  ├── SpaceGrotesk-Bold.ttf
  ├── Nunito-Regular.ttf
  ├── Nunito-Medium.ttf
  ├── Nunito-SemiBold.ttf
  └── Nunito-Bold.ttf

  test/core/theme/
  ├── mix_tokens_test.dart
  ├── kita_theme_test.dart
  ├── multi_modal_tokens_test.dart
  └── accessibility_tokens_test.dart
  ```

## Dev Notes

### Architecture — Design System layers

```
┌─────────────────────────────────────────────┐
│          Kita Design System                  │
│  ┌──────────────────────────────────────┐    │
│  │  KitaMultiModal Layer (custom)      │    │  <- Story 1.4 (tokens only)
│  │  KitaDurations · HapticPatterns     │    │     Full impl in E8 (ProfileAdapter)
│  ├──────────────────────────────────────┤    │
│  │  KitaUI Components (Mix-based)      │    │  <- E8 (Shell Living Aura)
│  │  KitaOrb · KitaShell · KitaInput   │    │
│  ├──────────────────────────────────────┤    │
│  │  Mix Framework + Design Tokens      │    │  <- Story 1.4 (this story)
│  │  Colors · Typography · Spacing      │    │
│  │  Radii · MixTheme · Dark/Light     │    │
│  └──────────────────────────────────────┘    │
├─────────────────────────────────────────────┤
│  Flutter SDK (Semantics API, Widgets)        │
└─────────────────────────────────────────────┘
```

Cette story pose les **fondations du design system** (tokens + theme). Les composants UI qui consomment ces tokens sont crees dans E8 (Shell Living Aura). Le ProfileAdapter multi-modal est aussi dans E8.

### Utilisation des tokens dans les futurs widgets

Les agents des phases 2+ utiliseront les tokens comme suit :

```dart
// Utiliser un ColorToken dans un Style Mix
final cardStyle = Style(
  $box.color.ref($kitaSurface),
  $box.borderRadius.ref($kitaRadiusMd),
  $box.padding.all.ref($kitaSpaceMd),
);

// Utiliser un TextStyleToken
final titleStyle = Style(
  $text.style.ref($kitaHeading1),
);

// Resoudre un token dans du code imperatif
final primaryColor = $kitaPrimary.resolve(context);
final bodyStyle = $kitaBody.resolve(context);
```

### Choix Mix 1.7.0 vs 2.0.0-rc

Le projet utilise **Mix 1.7.0 stable**. L'API principale est :

| Concept | Mix 1.7.0 (stable) | Mix 2.0.0-rc |
|---------|-------------------|--------------|
| Theme wrapper | `MixTheme` widget | `MixScope` widget |
| Theme data | `MixThemeData` | Maps directes dans `MixScope` |
| Style definition | `Style(...)` class | `BoxStyler()` fluent API |
| Widget styling | `Box(style: ...)` | `Box(style: ...)` |
| Token reference | `$box.color.ref($token)` | `$token()` call syntax |

**Si migration vers Mix 2.0 est necessaire plus tard**, les tokens (`ColorToken`, `SpaceToken`, etc.) restent identiques. Seule la couche de theming et la syntaxe de style changent.

### Fonts — strategy offline-first

On bundle les fonts dans `assets/fonts/` plutot que d'utiliser `google_fonts` (HTTP) car :
1. **Offline-first** — Kita fonctionne sans connexion
2. **Pas de flash** — Pas de FOUT (Flash of Unstyled Text) au premier lancement
3. **Controle total** — Pas de dependance a un CDN externe
4. **Performance** — Pas de latence de chargement font au runtime

### Mode sombre par defaut

Le UX spec definit le mode sombre comme defaut pour tous les profils :
- Moins agressif visuellement (fond charbon `#1A1A2E`)
- Meilleur pour les utilisateurs basse vision
- Meilleur contraste (texte blanc sur fond sombre)
- Le mode clair est disponible en option dans les settings

### JetBrains Mono — differe a E5 (Plugins)

Le UX spec definit une 3eme font : **JetBrains Mono** pour les logs et l'affichage debug dans le plugin system. Cette font n'est PAS incluse dans cette story. Elle sera ajoutee dans E5 (Plugins) quand le systeme de logs/debug sera implemente. Seules Space Grotesk (titres) et Nunito (corps) sont integrees ici.

### Propriete des fichiers

Cette story cree/modifie uniquement des fichiers dans le scope E1 (Fondation) :
- `lib/core/theme/kita_theme.dart` (creation)
- `lib/core/theme/mix_tokens.dart` (creation)
- `lib/core/theme/multi_modal_tokens.dart` (creation)
- `lib/core/theme/accessibility_tokens.dart` (creation)
- `lib/app.dart` (modification — ajout MixTheme wrapper)
- `pubspec.yaml` (modification — ajout fonts declaration)
- `assets/fonts/*.ttf` (creation — fichiers fonts)
- `test/core/theme/mix_tokens_test.dart` (creation)
- `test/core/theme/kita_theme_test.dart` (creation)
- `test/core/theme/multi_modal_tokens_test.dart` (creation)
- `test/core/theme/accessibility_tokens_test.dart` (creation)

## Technical Intelligence

### Mix 1.7.0 — Version verifiee (fevrier 2026)

| Package | Version | Role |
|---------|---------|------|
| `mix` | `^1.7.0` | Framework utility-first styling, design tokens, MixTheme |

**Publication :** Juillet 2025 (derniere stable). Publie par `leoafarias.com` (verified publisher).
**License :** BSD-3-Clause.
**Pre-release :** `2.0.0-rc.1` disponible mais **ne pas utiliser** — API en cours de stabilisation.
**Dart SDK :** Compatible Dart 3.x (null safety, records, patterns).

### API Mix 1.7.0 — Classes cles

**Design Token types :**
- `ColorToken('name')` — Token de couleur
- `TextStyleToken('name')` — Token de typographie
- `SpaceToken('name')` — Token d'espacement (double)
- `RadiusToken('name')` — Token de rayon (Radius)
- `BreakpointToken('name')` — Token de breakpoint

**Theme :**
- `MixTheme` — Widget qui wrappe l'app et fournit les tokens
- `MixThemeData` — Classe avec 5 maps : `colors`, `textStyles`, `spaces`, `radii`, `breakpoints`

**Styled widgets (Mix 1.7.0) :**
- `Box(style: Style(...))` — Container style
- `StyledText('text', style: Style(...))` — Texte style
- `StyledIcon(icon, style: Style(...))` — Icone stylee
- `FlexBox(style: Style(...))` — Flex container

**Style utilities :**
- `$box.color.ref($colorToken)` — Couleur depuis un token
- `$box.padding.all.ref($spaceToken)` — Padding depuis un token
- `$box.borderRadius.ref($radiusToken)` — Radius depuis un token
- `$text.style.ref($textStyleToken)` — TextStyle depuis un token
- `$on.dark(...)` — Variant conditionnelle dark mode
- `$on.hover(...)` — Variant hover state

**Resolution programmatique :**
```dart
final color = $kitaPrimary.resolve(context);       // -> Color
final style = $kitaBody.resolve(context);          // -> TextStyle
final space = $kitaSpaceMd.resolve(context);       // -> double
final radius = $kitaRadiusMd.resolve(context);     // -> Radius
```

### Fonts — versions verifiees

| Font | Version | Weights utilises | Source |
|------|---------|-----------------|--------|
| Space Grotesk | Variable (2022) | 300, 400, 500, 600, 700 | Google Fonts (OFL license) |
| Nunito | Variable (2022) | 400, 500, 600, 700 | Google Fonts (OFL license) |

Les deux fonts sont sous licence **Open Font License** (OFL) — libre d'utilisation dans des applications.

### google_fonts package — non utilise

| Package | Version | Statut |
|---------|---------|--------|
| `google_fonts` | `8.0.2` | Disponible mais **non utilise** — fonts bundled localement pour offline-first |

Le package `google_fonts` telecharge les fonts par HTTP et les cache. Pour Kita, on prefer le bundling local dans `assets/fonts/` avec declaration dans `pubspec.yaml` section `flutter: fonts:`. Cela garantit le fonctionnement offline et elimine le flash de font non chargee.

### Calcul de contraste WCAG

La formule de contraste WCAG 2.1 est :
```
contrast_ratio = (L1 + 0.05) / (L2 + 0.05)
```
ou L1 est la luminance relative de la couleur la plus claire et L2 de la plus sombre.

**Contrastes verifies pour le dark theme :**

| Combinaison | Ratio | Standard |
|------------|-------|----------|
| `#F8FAFC` (onBackground) sur `#1A1A2E` (background) | ~13.5:1 | AAA (7:1) |
| `#E2E8F0` (onSurface) sur `#1A1A2E` (background) | ~12:1 | AAA (7:1) |
| `#E2E8F0` (onSurface) sur `#16213E` (surface) | ~10:1 | AAA (7:1) |
| `#0D9488` (primary) sur `#1A1A2E` (background) | ~4.0:1 | AA large text (3:1) |
| `#8B5CF6` (accent) sur `#1A1A2E` (background) | ~3.6:1 | AA large text & UI components only (3:1 min) — **ne passe PAS** AA normal text (4.5:1 min) |

**Note :** Les couleurs primary et accent comme couleur de texte sur fond sombre ont un contraste limite (~3.6-4:1). Elles doivent etre utilisees :
- En gros texte (>= 18px bold ou >= 24px regular) ou
- Comme couleur d'UI (boutons, bordures, icones) ou le minimum est 3:1, ou
- Avec du texte blanc par-dessus (pas en tant que couleur de texte sur fond sombre)

## Pitfalls & Gotchas

### 1. Mix MixTheme doit etre au-dessus de MaterialApp

`MixTheme` doit wrapper `MaterialApp.router` (pas l'inverse) pour que les tokens soient resolus dans tous les widgets :

```dart
// CORRECT
MixTheme(
  data: buildKitaMixTheme(Brightness.dark),
  child: MaterialApp.router(...),
)

// INCORRECT — tokens non resolus dans l'app
MaterialApp.router(
  builder: (context, child) => MixTheme(
    data: buildKitaMixTheme(Brightness.dark),
    child: child!,
  ),
)
```

### 2. Fonts bundled — ne pas utiliser `fontFamily` dans les tokens directement

Les fonts sont declarees dans `pubspec.yaml` section `flutter: fonts:`. Le `fontFamily` dans les `TextStyle` des tokens doit correspondre exactement au `family` declare dans le pubspec :

```yaml
# pubspec.yaml
fonts:
  - family: SpaceGrotesk     # <- Ce nom exact
```

```dart
// mix_tokens.dart
TextStyle(fontFamily: 'SpaceGrotesk')  // <- Doit correspondre
```

Si les noms ne correspondent pas, Flutter utilisera la font par defaut sans erreur visible.

### 3. Ne pas confondre `RadiusToken` et `BorderRadiusGeometry`

Mix `RadiusToken` mappe vers `Radius` (un seul coin), pas vers `BorderRadius` (4 coins). Quand on utilise `$box.borderRadius.ref($kitaRadiusMd)`, Mix applique le meme radius aux 4 coins. Pour des radii differents par coin, utiliser la syntaxe directe :

```dart
$box.borderRadius.only(
  topLeft: Radius.circular(12),
  topRight: Radius.circular(12),
)
```

### 4. Les couleurs semantiques (success/warning/error) changent entre dark et light

Les couleurs semantiques doivent etre ajustees pour le mode clair (variantes plus sombrees pour maintenir le contraste sur fond clair). Le theme light dans `kita_theme.dart` utilise des variantes plus sombres :
- Success: `#10B981` (dark) -> `#059669` (light)
- Warning: `#F97316` (dark) -> `#EA580C` (light)
- Error: `#EF4444` (dark) -> `#DC2626` (light)

### 5. `prefers-reduced-motion` — pas gere au niveau du theme

Les `KitaDurations` definissent les durees standard. La detection de `prefers-reduced-motion` (via `MediaQuery.disableAnimations`) est geree au niveau des widgets qui consomment ces durees, PAS au niveau des tokens. Pattern :

```dart
final duration = MediaQuery.of(context).disableAnimations
    ? KitaDurations.zero
    : KitaDurations.transition;
```

Ce pattern sera utilise dans E8 (KitaOrb, KitaShell, etc.).

### 6. HapticPattern est un placeholder

`HapticPattern` dans `multi_modal_tokens.dart` est une abstraction. L'implementation reelle du service haptique (platform channels iOS/Android) est dans E3 (Story 3.4 — HapticService). Cette story definit uniquement les tokens (intensites et nombres de repetitions). E3 mappe ces tokens vers les API natives.

### 7. Mix communaute limitee — plan B

Le CLAUDE.md mentionne que Mix a une communaute limitee. Si Mix n'est plus maintenu :
- Les tokens (`ColorToken`, etc.) sont des classes Dart simples — portables
- Le plan B est `ThemeExtension<T>` custom (Flutter natif)
- Les valeurs de tokens (couleurs, spacing, etc.) restent identiques
- Seule la couche d'injection/resolution change

### 8. Ne PAS ajouter `google_fonts` au pubspec

L'approche Kita est le bundling local. Si `google_fonts` est ajoute au `pubspec.yaml`, il tentera de telecharger les fonts par HTTP au premier lancement, ce qui :
- Echoue en mode offline
- Cause un FOUT (Flash of Unstyled Text)
- Ajoute une dependance reseau inutile

### 9. Attention au `textScaleFactor` avec les tailles fixes

Les tailles definies dans les `TextStyleToken` (32px, 24px, etc.) seront multiplied par le `textScaleFactor` de l'utilisateur (0.8x a 2.0x). Les widgets doivent gerer le cas ou le texte est 2x plus grand que prevu. Ne PAS utiliser `textScaler: TextScaler.noScaling` sauf pour des elements fixes comme l'orbe.

### 10. DurationToken existe dans Mix mais n'est pas utilise

Mix 1.7.0 propose `DurationToken` mais il n'est pas utilise dans les token maps de `MixThemeData` (pas de propriete `durations`). On utilise donc une classe Dart simple (`KitaDurations`) plutot qu'un `DurationToken` pour les animations. Si Mix 2.0 ajoute le support, on pourra migrer.

### 11. Flutter 3.41 wide-gamut Color API — getters int DEPRECATED

Depuis **Flutter 3.27**, les getters entiers `Color.red`, `Color.green`, `Color.blue` (int 0-255) sont **deprecated** au profit du nouveau Color API wide-gamut :
- **Ancien (deprecated) :** `color.red` (int 0-255), `color.green`, `color.blue`, `color.alpha`
- **Nouveau :** `color.r` (double 0.0-1.0), `color.g`, `color.b`, `color.a`

**Impact sur cette story :**
- Ne PAS ecrire `color.red / 255.0` pour calculer la luminance ou le contraste
- Utiliser `Color.computeLuminance()` (built-in Flutter) pour les calculs de luminance WCAG
- Si besoin d'acces aux composantes individuelles, utiliser `color.r`, `color.g`, `color.b` (double 0.0-1.0)

```dart
// DEPRECATED — ne pas faire
final r = color.red / 255.0;   // color.red est deprecated
final g = color.green / 255.0; // color.green est deprecated

// CORRECT — utiliser les nouveaux getters float
final r = color.r; // double 0.0-1.0
final g = color.g; // double 0.0-1.0

// MIEUX — pour le contraste WCAG, utiliser le built-in
final luminance = color.computeLuminance();
```

## References

- Architecture: `_bmad-output/planning-artifacts/architecture.md` — sections "Styling Solution", "Frontend Architecture", "Code Organization"
- UX Design: `_bmad-output/planning-artifacts/ux-design-specification.md` — sections "Design System Foundation", "Color System", "Typography System", "Spacing & Layout Foundation", "Motion Design Principles", "Accessibility Considerations"
- Epics: `_bmad-output/planning-artifacts/epics.md` — Story 1.4, UX-010 through UX-013
- Story 1.3 (prerequis): `_bmad-output/implementation-artifacts/1-3-state-management-riverpod-di.md`
- Mix docs: https://www.fluttermix.com/docs/overview/introduction
- Mix design tokens: https://www.fluttermix.com/docs/guides/design-token
- Mix theming: https://www.fluttermix.com/docs/tutorials/theming
- Mix pub.dev: https://pub.dev/packages/mix (v1.7.0)
- Space Grotesk: https://fonts.google.com/specimen/Space+Grotesk
- Nunito: https://fonts.google.com/specimen/Nunito
- Flutter custom fonts: https://docs.flutter.dev/cookbook/design/fonts
- WCAG contrast ratios: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html

## Dev Agent Record

### Agent Model Used

(a remplir par l'agent dev)

### Debug Log References

### Completion Notes List

### File List
