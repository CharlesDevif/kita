---
story_id: "9.5"
title: "Mode aidant — Sophie configure pour Marie"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: ready-for-dev
priority: standard
estimated_complexity: L
depends_on: ["9.4"]
blocks: []
---

# Story 9.5 : Mode aidant — Sophie configure pour Marie

## User Story

**En tant que** aidant (Sophie),
**je veux** installer et configurer Kita pour un tiers (ma mere Marie),
**afin que** Marie puisse utiliser Kita sans avoir a faire l'onboarding elle-meme.

## Acceptance Criteria

- **AC1:** A l'onboarding, le choix "Pour moi" ou "Pour quelqu'un d'autre" est propose
- **AC2:** En mode "pour quelqu'un d'autre", Sophie selectionne le profil de l'utilisateur cible
- **AC3:** Les permissions sont groupees (pas une par une — Sophie accorde tout en une fois)
- **AC4:** Un test guide est propose : "Dites DECRIS pour verifier que tout fonctionne"
- **AC5:** Le nom de l'utilisateur cible est configure (ex: "Marie")
- **AC6:** Au prochain lancement, Kita accueille Marie par son nom : "Bonjour Marie !" → mode passif direct
- **AC7:** Chaque widget interactif a un `Semantics` wrapper
- **AC8:** Contrastes >= 4.5:1, touch targets >= 48x48px

## Technical Intelligence

### Flow mode aidant

```
Onboarding start
  ↓
"Pour moi" (flow standard 9.2-9.4) | "Pour quelqu'un d'autre" (mode aidant)
  ↓ (mode aidant)
Sophie entre le prenom de l'utilisateur cible (ex: "Marie")
  ↓
Sophie selectionne le profil (aveugle, malvoyant, sourd, general)
  ↓
Permissions groupees : camera + micro + location en un seul ecran
  ↓
Auto-install pack profil
  ↓
Test guide : "Dites DECRIS pour verifier"
  ↓
Si succes → "Tout est pret pour Marie !"
  ↓
Completion → au prochain lancement : "Bonjour Marie !" → mode passif
```

### Permissions groupees (mode aidant)

En mode aidant, l'aidant n'est pas handicape (probablement). Pas besoin de storytelling individuel. Utiliser le batch request :

```dart
final statuses = await [
  Permission.camera,
  Permission.microphone,
  Permission.locationWhenInUse,
].request();
```

### Persistance du mode aidant

Stocker dans le profil utilisateur (E4) :
- `isConfiguredByCaregiver: bool`
- `caregiverName: String?` (optionnel, pour reference)
- `userName: String` — le nom de l'utilisateur cible
- `skipOnboarding: bool` — true apres completion aidant

### Accueil personnalise au relancement

```dart
// Au lancement, si onboarding complete :
final profile = await userProfileService.getProfile();
if (profile != null && profile.userName.isNotEmpty) {
  await tts.speak("Bonjour ${profile.userName} !");
  // → mode passif direct (pas de re-onboarding)
}
```

## Pitfalls & Gotchas

1. **L'aidant est voyant** — L'interface mode aidant peut etre plus visuelle que le flow standard. Mais garder les `Semantics` wrapper quand meme (l'aidant peut aussi etre handicape).

2. **Permissions groupees mais pas silencieuses** — Meme en batch, chaque permission montre un dialogue natif. Sophie devra accepter 3 dialogues successifs. C'est le comportement attendu d'Android/iOS.

3. **Test guide avant handoff** — Le test "Dites DECRIS" doit utiliser le vrai pipeline (comme le Premier Moment Magique 9.4). Si le test echoue, proposer de recommencer, pas de bloquer la completion.

4. **Pas de re-onboarding** — Une fois complete (standard ou aidant), l'onboarding ne se relance JAMAIS. Si l'utilisateur veut changer de profil → Settings (E4).

5. **Nom de l'utilisateur** — Ne PAS logger le nom dans les logs (zero PII). Logger uniquement "[Onboarding] Profile configured by caregiver".

## Architecture References

- `lib/features/onboarding/presentation/onboarding_screen.dart` — Ecran principal (Story 9.2)
- `lib/features/onboarding/presentation/magic_moment_screen.dart` — Test guide (Story 9.4)
- `lib/features/onboarding/data/permission_storytelling_impl.dart` — Permissions (Story 9.3)
- `lib/features/memory/data/tables/user_profiles_table.dart` — Profil (E4)
- `lib/features/settings/` — Preferences (E4)

## Implementation Tasks

### Task 1 : CaregiverModeSelector (presentation)

Modifier `lib/features/onboarding/presentation/onboarding_screen.dart` :
- [ ] Ajouter step "mode_choice" : "Pour moi" vs "Pour quelqu'un d'autre"
- [ ] Si "Pour quelqu'un d'autre" → flow aidant
- [ ] `Semantics` label sur les deux boutons

### Task 2 : CaregiverOnboardingFlow (presentation)

Creer `lib/features/onboarding/presentation/caregiver_flow.dart` :
- [ ] Champ de saisie nom de l'utilisateur cible
- [ ] Selection profil (meme ProfileSelector que 9.2)
- [ ] Ecran permissions groupees (batch request)
- [ ] Ecran test guide ("Dites DECRIS pour verifier")
- [ ] Ecran confirmation : "Tout est pret pour {nom} !"

### Task 3 : CaregiverCompletion (data)

Modifier `lib/features/onboarding/data/onboarding_completion.dart` :
- [ ] `Future<void> completeCaregiverOnboarding(String targetName, AccessibilityProfile profile)`
- [ ] Persiste `isConfiguredByCaregiver: true` + `userName` dans le profil
- [ ] Marque l'onboarding comme complete

### Task 4 : Accueil personnalise au relancement

Modifier le flow de lancement (go_router redirect ou `main()`) :
- [ ] Si onboarding complete et `userName` non vide → TTS "Bonjour {nom} !"
- [ ] Aller directement en mode passif (pas de re-onboarding)

### Task 5 : Tests

- [ ] `test/features/onboarding/presentation/caregiver_flow_test.dart`
  - Test : flow complet aidant (nom → profil → permissions → test → completion)
  - Test : permissions groupees (batch)
  - Test : test guide DECRIS fonctionne
  - Test : completion persiste le profil aidant
- [ ] `test/features/onboarding/` (integration)
  - Test : relancement apres onboarding aidant → accueil personnalise
  - Test : pas de re-onboarding apres completion

## Accessibility Tax

- [ ] `Semantics` wrapper sur "Pour moi" / "Pour quelqu'un d'autre"
- [ ] `Semantics` wrapper sur champ de saisie nom
- [ ] `Semantics` wrapper sur confirmation
- [ ] Contrastes >= 4.5:1
- [ ] Touch targets >= 48x48px

## Definition of Done

- [ ] Mode aidant fonctionnel de bout en bout
- [ ] Permissions groupees
- [ ] Test guide avec vrai pipeline
- [ ] Accueil personnalise au relancement
- [ ] Accessibility Tax verifie
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
