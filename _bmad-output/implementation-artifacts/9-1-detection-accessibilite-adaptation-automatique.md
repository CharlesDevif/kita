---
story_id: "9.1"
title: "Detection accessibilite et adaptation automatique"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: ready-for-dev
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
- [ ] `abstract class ProfileDetection`
- [ ] `Future<DetectedProfile> detect()` — detection one-shot au lancement
- [ ] `Stream<DetectedProfile> onProfileChanged` — changements dynamiques
- [ ] `DetectedProfile` record : `{AccessibilityProfile profile, bool screenReader, bool largeText, bool reduceMotion, bool boldText, bool highContrast}`
- [ ] `enum AccessibilityProfile { blind, lowVision, deaf, general }`

### Task 2 : Implementation ProfileDetectionImpl (data)

Creer `lib/features/onboarding/data/profile_detection_impl.dart` :
- [ ] Implements `ProfileDetection`
- [ ] `detect()` lit `WidgetsBinding.instance.accessibilityFeatures` + `MediaQuery` (via `PlatformDispatcher`)
- [ ] `onProfileChanged` utilise `WidgetsBindingObserver.didChangeAccessibilityFeatures` via un `StreamController`
- [ ] Logique de pre-selection : `accessibleNavigation` → `blind`, `textScale > 1.3` → `lowVision`, sinon `general`
- [ ] Dispose propre du StreamController et observer

### Task 3 : Riverpod Provider

Creer dans `lib/features/onboarding/di/providers.dart` :
- [ ] `profileDetectionProvider` — Provider pour l'interface
- [ ] `detectedProfileProvider` — StreamProvider qui expose le profil courant
- [ ] `ref.onDispose()` pour cleanup

### Task 4 : OnboardingState (domain)

Creer `lib/features/onboarding/domain/onboarding_state.dart` :
- [ ] `enum OnboardingStep { detecting, welcome, profile, permissions, magic, complete }`
- [ ] `class OnboardingState { step, detectedProfile, userName, permissionsGranted, onboardingComplete }`
- [ ] Logique d'etat pour la progression de l'onboarding (utilise par 9.2+)

### Task 5 : Tests

- [ ] `test/features/onboarding/data/profile_detection_impl_test.dart`
  - Test : VoiceOver actif → `AccessibilityProfile.blind`
  - Test : TalkBack actif → `AccessibilityProfile.blind`
  - Test : textScale > 1.3 → `AccessibilityProfile.lowVision`
  - Test : aucune accessibilite → `AccessibilityProfile.general`
  - Test : changement dynamique declenche stream
  - Test : dispose nettoie les ressources
- [ ] Au moins 1 test d'integration avec un vrai `TestWidgetsFlutterBinding`

## Definition of Done

- [ ] `ProfileDetection` interface creee dans `domain/`
- [ ] `ProfileDetectionImpl` implementee avec detection VoiceOver/TalkBack/textScale
- [ ] Stream de changements dynamiques fonctionnel
- [ ] Provider Riverpod expose le profil detecte
- [ ] `OnboardingState` et `OnboardingStep` definis
- [ ] 8+ tests passent
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe
- [ ] Zero PII dans les logs
- [ ] sprint-status.yaml mis a jour

---

## Dev Agent Record

**Agent Model:**
**Date:**

### Completion Notes

_(A remplir par l'agent de developpement)_

### Files Modified

_(A remplir par l'agent de developpement)_
