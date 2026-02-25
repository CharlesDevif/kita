---
story_id: "9.1"
title: "Detection accessibilite et adaptation automatique"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: review
priority: critical
estimated_complexity: M
depends_on: []
blocks: ["9.2", "9.3", "9.4", "9.5"]
---

# Story 9.1 : Detection accessibilite et adaptation automatique

## User Story

**En tant que** utilisateur de Kita,
**je veux** que Kita detecte automatiquement VoiceOver/TalkBack et adapte l'experience immediatement,
**afin que** je n'aie rien a configurer manuellement pour que l'app soit accessible.

## Acceptance Criteria

- **AC1:** La detection VoiceOver (iOS) et TalkBack (Android) se fait au lancement de l'app, AVANT le premier ecran
- **AC2:** Si VoiceOver/TalkBack est actif, le profil `aveugle` est pre-selectionne
- **AC3:** Si `textScaleFactor > 1.3`, le profil `basse_vision` est pre-selectionne
- **AC4:** La detection est transparente — l'utilisateur ne voit rien, l'app s'adapte
- **AC5:** Les changements d'accessibilite en cours d'utilisation sont detectes dynamiquement (VoiceOver active/desactive)
- **AC6:** Les tests verifient la pre-selection pour chaque detection

## Technical Intelligence

### Detection VoiceOver/TalkBack — API Flutter native (PAS de platform channel necessaire)

Flutter fournit `AccessibilityFeatures` via `WidgetsBinding` et `MediaQuery`. Aucun package tiers requis.

```dart
// Detection screen reader (VoiceOver/TalkBack)
final bool screenReaderActive =
    WidgetsBinding.instance.accessibilityFeatures.accessibleNavigation;

// Detection text scaling
final TextScaler scaler = MediaQuery.textScalerOf(context);
final bool isLargeText = scaler.scale(16.0) > 16.0 * 1.3;

// Detection reduced motion
final bool reduceMotion =
    WidgetsBinding.instance.accessibilityFeatures.reduceMotion;

// Detection bold text
final bool boldText =
    WidgetsBinding.instance.accessibilityFeatures.boldText;

// Detection high contrast (iOS only)
final bool highContrast =
    WidgetsBinding.instance.accessibilityFeatures.highContrast;
```

### Ecoute des changements dynamiques

```dart
class AccessibilityObserver with WidgetsBindingObserver {
  @override
  void didChangeAccessibilityFeatures() {
    // Re-evaluer le profil quand l'utilisateur active/desactive VoiceOver
    final features = WidgetsBinding.instance.accessibilityFeatures;
    _updateProfile(features);
  }
}
```

### textScaleFactor est DEPRECATED

`textScaleFactor` est deprecated depuis Flutter 3.16. Utiliser `TextScaler` :
```dart
// DEPRECATED — NE PAS UTILISER
MediaQuery.of(context).textScaleFactor; // deprecated

// CORRECT
final TextScaler scaler = MediaQuery.textScalerOf(context);
final double effectiveSize = scaler.scale(16.0);
```

### Proprietes AccessibilityFeatures disponibles

| Propriete | Signification |
|-----------|--------------|
| `accessibleNavigation` | Screen reader (VoiceOver/TalkBack) actif |
| `boldText` | OS demande du texte gras |
| `disableAnimations` | OS demande la reduction des animations |
| `highContrast` | Mode haut contraste (iOS) |
| `invertColors` | Couleurs inversees |
| `reduceMotion` | Reduce motion (iOS) |

## Pitfalls & Gotchas

1. **`disableAnimations` bug connu** — GitHub issue #106499 : `MediaQueryData.disableAnimations` ne se declenche pas toujours correctement sur certains appareils Android. Workaround : lire depuis `WidgetsBinding.instance.accessibilityFeatures.disableAnimations` directement et ecouter via `WidgetsBindingObserver.didChangeAccessibilityFeatures`.

2. **`accessibleNavigation` = true ne signifie pas forcement VoiceOver/TalkBack** — Certains appareils avec navigation par switch ou d'autres outils d'accessibilite peuvent aussi activer ce flag. C'est le bon comportement pour Kita (on veut adapter dans tous ces cas).

3. **`textScaleFactor` > 1.3 detection** — Utiliser `scaler.scale(16.0) > 16.0 * 1.3` et non `scaler.textScaleFactor > 1.3` (deprecated).

4. **Timing de detection** — La detection doit se faire dans le `main()` AVANT le premier `runApp()` ou au plus tard dans le premier `build()`. Utiliser `WidgetsFlutterBinding.ensureInitialized()` puis lire `WidgetsBinding.instance.accessibilityFeatures`.

5. **Package `device_accessibility_info` (1.0.0)** — Existe mais adoption tres faible (321 downloads). Ne PAS l'utiliser — l'API native Flutter est suffisante et plus fiable.

## Architecture References

- `lib/features/onboarding/domain/profile_detection.dart` — Interface ProfileDetection
- `lib/features/onboarding/data/profile_detection_impl.dart` — Implementation
- `lib/features/memory/data/tables/user_profiles_table.dart` — Persistance du profil
- `lib/features/settings/` — UserProfile existant (E4)

## Implementation Tasks

### Task 1 : Interface ProfileDetection (domain)

Creer `lib/features/onboarding/domain/profile_detection.dart` :
- [x] `abstract class ProfileDetection`
- [x] `DetectedProfile detect()` — detection one-shot au lancement (synchrone, pas Future)
- [x] `Stream<DetectedProfile> onProfileChanged` — changements dynamiques
- [x] `DetectedProfile` class : `{AccessibilityProfile profile, bool screenReader, bool largeText, bool reduceMotion, bool boldText, bool highContrast}`
- [x] `enum AccessibilityProfile { blind, lowVision, general }`

### Task 2 : Implementation ProfileDetectionImpl (data)

Creer `lib/features/onboarding/data/profile_detection_impl.dart` :
- [x] Implements `ProfileDetection`
- [x] `detect()` lit `WidgetsBinding.instance.accessibilityFeatures` + `PlatformDispatcher.textScaleFactor`
- [x] `onProfileChanged` utilise `WidgetsBindingObserver.didChangeAccessibilityFeatures` via un `StreamController.broadcast`
- [x] Logique de pre-selection : `accessibleNavigation` -> `blind`, `textScale > 1.3` -> `lowVision`, sinon `general`
- [x] Dispose propre du StreamController et observer (guard `_disposed`)

### Task 3 : Riverpod Provider

Creer dans `lib/features/onboarding/di/providers.dart` :
- [x] `profileDetectionProvider` — Provider pour l'interface avec `ref.onDispose`
- [x] `detectedProfileProvider` — StreamProvider qui expose le profil courant (initial + stream)
- [x] `ref.onDispose()` pour cleanup

### Task 4 : OnboardingState (domain)

Creer `lib/features/onboarding/domain/onboarding_state.dart` :
- [x] `enum OnboardingStep { detecting, welcome, profile, permissions, magic, complete }`
- [x] `class OnboardingState { step, detectedProfile, userName, permissionsGranted, onboardingComplete }`
- [x] `copyWith` pour la progression de l'onboarding (utilise par 9.2+)

### Task 5 : Tests

- [x] `test/features/onboarding/data/profile_detection_impl_test.dart`
  - Test : VoiceOver actif -> `AccessibilityProfile.blind` (via `_FakeAccessibilityFeatures`)
  - Test : screenReader priority over largeText -> `AccessibilityProfile.blind`
  - Test : largeText without screenReader -> `AccessibilityProfile.lowVision`
  - Test : aucune accessibilite -> `AccessibilityProfile.general`
  - Test : changement dynamique declenche stream
  - Test : multiple changes emit multiple events
  - Test : dispose nettoie les ressources (no more emissions)
  - Test : dispose can be called multiple times safely
  - Test : reduce motion, bold text, high contrast detected
- [x] Au moins 1 test d'integration avec un vrai `TestWidgetsFlutterBinding` (6 testWidgets tests)
- [x] `test/features/onboarding/domain/onboarding_state_test.dart` — 8 tests

## Definition of Done

- [x] `ProfileDetection` interface creee dans `domain/`
- [x] `ProfileDetectionImpl` implementee avec detection VoiceOver/TalkBack/textScale
- [x] Stream de changements dynamiques fonctionnel
- [x] Provider Riverpod expose le profil detecte
- [x] `OnboardingState` et `OnboardingStep` definis
- [x] 8+ tests passent (31 tests total)
- [x] `dart analyze --fatal-infos` clean
- [x] `flutter test` passe (1211 tests, 0 failures)
- [x] Zero PII dans les logs
- [x] sprint-status.yaml mis a jour

---

## Dev Agent Record

**Agent Model:** claude-opus-4-6
**Date:** 2026-02-25

### Completion Notes

**Approche technique :**
- Detection basee sur l'API native Flutter `AccessibilityFeatures` via `WidgetsBinding.platformDispatcher` — aucun package tiers, aucun platform channel
- `ProfileDetectionImpl` implemente `WidgetsBindingObserver` pour les changements dynamiques, avec un `StreamController.broadcast` pour multi-listeners
- Detection synchrone (`detect()`) au lieu de `Future<DetectedProfile>` comme suggere dans le story file, car `accessibilityFeatures` est disponible immediatement via le binding
- `resolveProfile()` est une fonction pure top-level pour faciliter le test unitaire independamment du binding

**Decisions techniques :**
- `detect()` retourne `DetectedProfile` (synchrone) au lieu de `Future<DetectedProfile>` — les donnees d'accessibilite sont disponibles synchroniquement via `platformDispatcher.accessibilityFeatures` et il n'y a aucune raison d'ajouter de l'asynchronisme
- `enum AccessibilityProfile` n'inclut PAS `deaf` (present dans le story file original) car il n'y a aucune API Flutter native pour detecter la surdite. Le profil `deaf` sera gere par selection manuelle dans la story 9.2
- Text scale detection utilise `platformDispatcher.textScaleFactor` (deprecated mais fonctionnel) plutot que `MediaQuery.textScalerOf(context)` car on n'a pas de `BuildContext` au moment de la detection dans `main()`. Pour la v2, on pourrait utiliser `implicitView.platformDispatcher` avec TextScaler

**Problemes rencontres :**
- `KitaLogger` factory n'est pas `const` — corrige en retirant `const` du champ `_log`
- `AccessibilityFeatures.supportsAnnounce` — nouveau getter dans Flutter 3.41 non documente dans le story file, ajoute dans le fake pour les tests
- `testWidgets` + `WidgetsBindingObserver` cause un hang du test framework lors du teardown quand un stream listener est actif. Workaround : utiliser `test()` regulier pour les tests de stream emission, et `testWidgets` uniquement pour les tests qui ont besoin de `tester.platformDispatcher.accessibilityFeaturesTestValue`

**Workarounds :**
- Les tests de stream emission (`onProfileChanged`) utilisent `test()` au lieu de `testWidgets()` car le test framework Flutter hang quand un `WidgetsBindingObserver` avec broadcast stream est enregistre dans un `testWidgets` context. Les tests d'integration avec `accessibilityFeaturesTestValue` utilisent `testWidgets` normalement

### Files Modified

**Created:**
- `lib/features/onboarding/domain/profile_detection.dart` — Interface `ProfileDetection`, `DetectedProfile`, `AccessibilityProfile` enum
- `lib/features/onboarding/data/profile_detection_impl.dart` — Implementation avec `WidgetsBindingObserver`, `resolveProfile()`, `isLargeTextScale()`
- `lib/features/onboarding/di/providers.dart` — `profileDetectionProvider`, `detectedProfileProvider` (StreamProvider)
- `lib/features/onboarding/domain/onboarding_state.dart` — `OnboardingStep` enum, `OnboardingState` class avec `copyWith`
- `test/features/onboarding/data/profile_detection_impl_test.dart` — 23 tests (unit + integration avec TestWidgetsFlutterBinding)
- `test/features/onboarding/domain/onboarding_state_test.dart` — 8 tests

**Modified:**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — epic-9: in-progress, 9.1: in-progress -> review

## Change Log

| Date | Change |
|------|--------|
| 2026-02-25 | Story 9.1 implemented: ProfileDetection interface + impl, Riverpod providers, OnboardingState, 31 tests passing |
