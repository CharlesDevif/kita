# Story 8.1: KitaOrb — Widget anime signature

## Status: review

## Story
As a **utilisateur de Kita**,
I want **voir une orbe animee teal/violet qui represente l'etat de Kita en temps reel**,
So that **je sais visuellement si Kita est prete, ecoute, traite, ou rencontre un probleme**.

## Acceptance Criteria

1. Orb rendered via `CustomPainter` with gradient teal/violet and particles
2. 6 visually distinct states: `passive` (slow undulation), `listening` (pulsation), `processing` (accelerated flux), `responding` (green expansion), `error` (red pulse), `offline` (grey-teal slowed)
3. 2 sizes: `large` (passive mode, center) and `small` (active mode, header)
4. Animation at 60fps via `AnimationController`
5. `prefers-reduced-motion` respected — instant transitions, no animation
6. `Semantics(label: "Kita est [etat]")` for VoiceOver
7. Contrast >= 3:1 against background (UI element requirement)
8. Tests verify all 6 states and Semantics label

## Technical Intelligence

### Architecture
- File: `lib/features/shell/presentation/kita_orb.dart`
- Test: `test/features/shell/presentation/kita_orb_test.dart`
- Uses Mix tokens from `lib/core/theme/mix_tokens.dart` and `kita_theme.dart`
- Animation durations from `lib/core/theme/multi_modal_tokens.dart`
- Accessibility constraints from `lib/core/theme/accessibility_tokens.dart`

### Design Tokens (from kita_theme.dart)
- Primary teal: `#0D9488` ($kitaPrimary)
- Accent violet: `#8B5CF6` ($kitaAccent)
- Background dark: `#1A1A2E` ($kitaBackground)
- Error red: `#EF4444` ($kitaError)
- Success green: `#10B981` ($kitaSuccess)
- Warning orange: `#F97316` ($kitaWarning)

### OrbState Enum
```dart
enum OrbState { passive, listening, processing, responding, error, offline }
```

### OrbSize Enum
```dart
enum OrbSize { large, small }
```

### Animation Parameters per State
| State | Primary Color | Secondary Color | Speed Multiplier | Pattern |
|-------|--------------|-----------------|-----------------|---------|
| passive | teal #0D9488 | violet #8B5CF6 | 0.3x | slow undulation |
| listening | teal #0D9488 | violet #8B5CF6 | 1.0x | pulsation (scale) |
| processing | teal #0D9488 | violet #8B5CF6 | 2.0x | accelerated rotation |
| responding | green #10B981 | teal #0D9488 | 1.0x | expansion + glow |
| error | red #EF4444 | red-dark | 1.5x | pulse (opacity) |
| offline | grey-teal #708090 | grey #4A5568 | 0.15x | slow undulation |

### Sizing (from UX spec)
- `large`: `MediaQuery.size.width * 0.5` (passive mode, center)
- `small`: `MediaQuery.size.width * 0.15` (active mode, header)
- Transition between sizes: 300ms (KitaAnimationDurations.transition)

### Impeller Compatibility
- CustomPainter is the recommended approach for Impeller
- Avoid `BlendMode` operations that are not supported (e.g., `BlendMode.multiply` may have issues)
- Use `Canvas.drawCircle`, `Canvas.drawPath`, gradient shaders — all Impeller-compatible
- `Paint.shader` with `RadialGradient.createShader()` works fine on Impeller

### Reduced Motion
- Check `MediaQuery.of(context).disableAnimations` for platform reduced-motion
- When reduced motion: no AnimationController ticking, static rendering of current state
- State transitions: instant (Duration.zero)

### Semantics
- Label pattern: `"Kita est [etat_francais]"`
- State labels: passive="en veille", listening="a l'ecoute", processing="en traitement", responding="repond", error="en erreur", offline="hors ligne"

## Implementation Plan

### Domain
1. `OrbState` enum with 6 values
2. `OrbSize` enum with 2 values

### Presentation
1. `KitaOrb` — StatefulWidget with AnimationController(s)
2. `KitaOrbPainter` — CustomPainter that renders the orb based on state
3. Riverpod provider `orbStateProvider` to expose orb state

### Tests
1. Widget test: renders for each state
2. Widget test: Semantics label correct for each state
3. Widget test: large vs small sizing
4. Widget test: reduced motion disables animation

## Dev Agent Record

| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 18/18 pass |
| Coverage | All 6 states, 2 sizes, semantics, animation, reduced motion |
