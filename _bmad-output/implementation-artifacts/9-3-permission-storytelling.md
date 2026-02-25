---
story_id: "9.3"
title: "Permission Storytelling"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: ready-for-dev
priority: high
estimated_complexity: L
depends_on: ["9.2"]
blocks: ["9.4"]
---

# Story 9.3 : Permission Storytelling

## User Story

**En tant que** utilisateur de Kita,
**je veux** que chaque permission soit expliquee dans son contexte d'usage avant d'etre demandee,
**afin que** je comprenne pourquoi Kita a besoin de ma camera et de mon micro.

## Acceptance Criteria

- **AC1:** La camera est demandee avec : "Pour decrire ce qui t'entoure, j'ai besoin de ta camera"
- **AC2:** Le micro est demande avec : "Pour t'ecouter, j'ai besoin du micro"
- **AC3:** L'ordre des permissions est adapte au profil (aveugle → camera d'abord)
- **AC4:** Chaque permission refusee est reproposee UNE fois avec une explication complementaire
- **AC5:** Apres 2 refus, Kita accepte et continue sans la permission
- **AC6:** Les permissions sont demandees via l'API native (`permission_handler`)
- **AC7:** Chaque widget interactif a un `Semantics` wrapper avec label descriptif
- **AC8:** Contrastes >= 4.5:1 (texte) et >= 3:1 (elements UI)
- **AC9:** Touch targets >= 48x48px (56x56px pour actions critiques)
- **AC10:** Les tests verifient les cas : acceptee, refusee une fois puis acceptee, refusee deux fois

## Technical Intelligence

### permission_handler 12.0.1

```yaml
dependencies:
  permission_handler: ^12.0.1
```

**API pour demande sequentielle :**

```dart
import 'package:permission_handler/permission_handler.dart';

Future<PermissionStatus> requestWithStorytelling(
  Permission permission,
  String explanation,
  String secondExplanation,
) async {
  // Premiere demande avec explication
  await _speak(explanation);
  var status = await permission.request();

  if (status.isDenied) {
    // Deuxieme tentative avec explication complementaire
    await _speak(secondExplanation);
    status = await permission.request();
  }

  if (status.isPermanentlyDenied) {
    // iOS: 2 refus → permanentlyDenied
    // Android 11+: 2 refus → permanentlyDenied
    // Proposer d'ouvrir les parametres
    await openAppSettings();
  }

  return status;
}
```

**PermissionStatus valeurs :**

| Status | Signification |
|--------|--------------|
| `granted` | Accordee |
| `denied` | Refusee (peut re-demander) |
| `permanentlyDenied` | Refusee definitivement (doit aller dans Settings) |
| `restricted` | iOS uniquement : controles parentaux |
| `limited` | iOS uniquement : acces photos limite |

### Ordre des permissions par profil

| Profil | Ordre |
|--------|-------|
| `blind` | Camera → Micro → Location |
| `lowVision` | Camera → Micro → Location |
| `deaf` | Micro → Camera → Location |
| `general` | Camera → Micro → Location |

### AndroidManifest.xml — Declarations requises

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Info.plist — Usage descriptions requises

```xml
<key>NSCameraUsageDescription</key>
<string>Kita utilise la camera pour decrire votre environnement et detecter les obstacles.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Kita utilise le micro pour ecouter vos commandes vocales.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Kita utilise votre position pour adapter les alertes a votre environnement.</string>
```

## Pitfalls & Gotchas

1. **`permanentlyDenied` vs `denied`** — Sur iOS, le premier refus = `denied`. Apres le deuxieme refus (ou si l'utilisateur a choisi "Never") = `permanentlyDenied`. Sur Android 11+, deux refus successifs = `permanentlyDenied`. Apres `permanentlyDenied`, `permission.request()` ne montre plus de dialogue — il faut `openAppSettings()`.

2. **`openAppSettings()` sur iOS** — Ouvre les Settings root, pas directement la page de l'app. L'utilisateur doit naviguer manuellement vers Privacy > Camera > Kita.

3. **Pas de batch request pour le storytelling** — `[Permission.camera, Permission.microphone].request()` affiche les dialogues dans l'ordre de la plateforme, pas le notre. Pour le storytelling, demander UNE permission a la fois avec explication vocale entre chaque.

4. **KitaPermissionCard (E8)** — Le widget `KitaPermissionCard` existe deja dans E8. Le reutiliser pour l'affichage visuel des permissions pendant le storytelling.

5. **Consent logging (RGPD)** — Logger chaque reponse de permission dans `consent_log_table` (E4) pour la conformite RGPD Art.9.

## Architecture References

- `lib/features/onboarding/presentation/permission_card.dart` — Ecran permission
- `lib/features/shell/presentation/widgets/kita_permission_card.dart` — Widget existant (E8)
- `lib/features/memory/data/tables/consent_log_table.dart` — Log consentement (E4)
- `lib/features/io/domain/tts_service.dart` — TTS pour explication vocale

## Implementation Tasks

### Task 1 : PermissionStorytellingService (domain)

Creer `lib/features/onboarding/domain/permission_storytelling.dart` :
- [ ] `abstract class PermissionStorytelling`
- [ ] `Future<Map<Permission, PermissionStatus>> requestAll(AccessibilityProfile profile)`
- [ ] Retourne le status de chaque permission demandee

### Task 2 : PermissionStorytellingImpl (data)

Creer `lib/features/onboarding/data/permission_storytelling_impl.dart` :
- [ ] Implements `PermissionStorytelling`
- [ ] Ordre adapte au profil
- [ ] Explication vocale (TTS) avant chaque demande
- [ ] Max 2 tentatives par permission
- [ ] Apres 2 refus → continue sans (pas d'exception)
- [ ] Log chaque reponse dans consent_log (RGPD)

### Task 3 : PermissionScreen (presentation)

Creer `lib/features/onboarding/presentation/permission_screen.dart` :
- [ ] Affiche `KitaPermissionCard` pour chaque permission
- [ ] Explication contextuelle vocale + visuelle
- [ ] Bouton "Autoriser" (touch target 56x56px)
- [ ] Feedback apres accord/refus
- [ ] `Semantics` wrapper sur tous les elements interactifs

### Task 4 : Tests

- [ ] `test/features/onboarding/data/permission_storytelling_impl_test.dart`
  - Test : permission accordee du premier coup
  - Test : permission refusee une fois puis accordee
  - Test : permission refusee deux fois → continue sans
  - Test : `permanentlyDenied` → propose `openAppSettings`
  - Test : ordre adapte au profil blind vs deaf
  - Test : consent log enregistre chaque reponse
- [ ] Test widget PermissionScreen avec Semantics

## Accessibility Tax

- [ ] `Semantics` wrapper sur bouton "Autoriser" avec label explicite
- [ ] `Semantics` wrapper sur explication textuelle
- [ ] Contrastes >= 4.5:1
- [ ] Touch targets >= 56x56px pour bouton "Autoriser"
- [ ] Explication vocale complete (pas juste visuelle)

## Definition of Done

- [ ] Permission storytelling avec explication vocale avant chaque demande
- [ ] Ordre adapte au profil
- [ ] Max 2 tentatives par permission
- [ ] Consent log RGPD
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
