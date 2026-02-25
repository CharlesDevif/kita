---
story_id: "9.2"
title: "Onboarding vocal-first — Flow principal"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: ready-for-dev
priority: critical
estimated_complexity: XL
depends_on: ["9.1"]
blocks: ["9.3", "9.4", "9.5"]
---

# Story 9.2 : Onboarding vocal-first — Flow principal

## User Story

**En tant que** utilisateur aveugle (Marie),
**je veux** que Kita me guide vocalement a travers l'onboarding en < 3 minutes,
**afin que** je puisse configurer l'app sans voir l'ecran et sans aide exterieure.

## Acceptance Criteria

- **AC1:** Si VoiceOver/TalkBack est actif, Kita parle EN PREMIER : "Bonjour, je suis Kita. Je suis la pour t'aider."
- **AC2:** Kita demande vocalement le prenom de l'utilisateur
- **AC3:** L'utilisateur selectionne son profil (aveugle, malvoyant, sourd, general) — vocalement ou par touch
- **AC4:** Le pack profil correspondant est auto-installe (Describe + Alert pour aveugle)
- **AC5:** Le flow complet est navigable en vocal uniquement (100%)
- **AC6:** Le flow complet est < 3 minutes
- **AC7:** Chaque widget interactif a un `Semantics` wrapper avec label descriptif
- **AC8:** Les contrastes respectent >= 4.5:1 (texte) et >= 3:1 (elements UI)
- **AC9:** Les touch targets font >= 48x48px (56x56px pour actions critiques)
- **AC10:** Les tests verifient le flow complet avec simulation VoiceOver

## Technical Intelligence

### go_router — Redirect guard pour onboarding

**Version : 17.1.0**

Pattern `refreshListenable` avec Riverpod pour rediriger vers onboarding au premier lancement :

```dart
GoRouter(
  refreshListenable: onboardingNotifier,
  redirect: (context, state) {
    final isComplete = ref.read(onboardingCompleteProvider);
    final isOnboarding = state.matchedLocation.startsWith('/onboarding');
    if (!isComplete && !isOnboarding) return '/onboarding';
    if (isComplete && isOnboarding) return '/';
    return null;
  },
);
```

**Pitfall** : Ne pas utiliser `ref.watch` dans le callback `redirect` — utiliser `ref.read`. Le `refreshListenable` gere le re-declenchement.

**Pitfall** : `state.subloc` est supprime depuis go_router v6 — utiliser `state.matchedLocation`.

### Onboarding vocal — Flow architecture

```
Detection accessibilite (Story 9.1)
  ↓
Kita parle : "Bonjour, je suis Kita" (TTS via OutputHandle ou TtsService direct)
  ↓
Demande prenom (vocal STT ou texte)
  ↓
Selection profil (vocal : "aveugle", "malvoyant", "sourd" ou touch)
  ↓
Auto-install pack (Describe + Alert pour blind)
  ↓
→ Story 9.3 (Permissions)
```

### Pack Installer — Auto-installation des plugins selon profil

| Profil | Plugins auto-installes |
|--------|----------------------|
| `blind` | Describe + Alert |
| `lowVision` | Describe + Alert (config zoom) |
| `deaf` | Alert (haptic only, no TTS) |
| `general` | Describe |

### Semantics Testing — API Flutter native

```dart
testWidgets('onboarding has accessible profile selector', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(buildOnboarding());

  expect(
    tester.getSemantics(find.byKey(Key('profile_blind'))),
    containsSemantics(label: 'Profil aveugle', hasTapAction: true),
  );

  handle.dispose();
});
```

**Pitfall** : `find.bySemanticsLabel` ne trouve pas les nodes dans `GestureDetector`/`InkWell`/`IconButton` dans certaines configs (GitHub #126059). Ajouter un `Semantics` wrapper explicite.

### ProfileAdapter pour output multi-modal

Tout output pendant l'onboarding DOIT passer par `ProfileAdapter` :
```dart
adapter.feedback(
  visual: () => showText("Bonjour, je suis Kita"),
  vocal: () => tts.speak("Bonjour, je suis Kita"),
  haptic: () => haptic.confirmation(),
);
```

## Pitfalls & Gotchas

1. **Kita parle en premier** — Le TTS doit etre pret AVANT le premier widget. Initialiser `TtsService` dans le `main()` ou via un provider eagerly-loaded.

2. **STT pour capture prenom** — Le micro doit etre actif pendant l'onboarding. Si la permission micro n'est pas encore accordee, fallback sur input texte.

3. **Infinite redirect loop** — Toujours garder les deux directions dans le redirect go_router (pas complete + pas sur onboarding → onboarding ; complete + sur onboarding → home).

4. **Semantics merge** — Quand plusieurs `Text` sont dans un meme widget interactif, Flutter merge les labels. Utiliser `Semantics(excludeSemantics: true, label: ...)` sur le parent si le merge produit un label incoherent.

5. **Timer < 3 minutes** — Ne pas mesurer en test avec un vrai timer. Compter les etapes et verifier que chaque etape prend < 30s en moyenne.

## Architecture References

- `lib/features/onboarding/presentation/onboarding_screen.dart` — Ecran principal
- `lib/features/onboarding/presentation/profile_selector.dart` — Selection profil
- `lib/features/onboarding/data/pack_installer.dart` — Auto-installation packs
- `lib/features/onboarding/domain/onboarding_state.dart` — Etat (Story 9.1)
- `lib/features/shell/presentation/kita_shell.dart` — Shell existant (E8)
- `lib/features/io/domain/tts_service.dart` — TTS (E3)
- `lib/features/io/domain/stt_service.dart` — STT (E3)
- `lib/shared/multi_modal/profile_adapter.dart` — ProfileAdapter (E8)

## Implementation Tasks

### Task 1 : OnboardingScreen (presentation)

Creer `lib/features/onboarding/presentation/onboarding_screen.dart` :
- [ ] `ConsumerStatefulWidget` avec go_router integration
- [ ] Step `welcome` : Kita parle "Bonjour, je suis Kita. Je suis la pour t'aider."
- [ ] Step `name` : Demande prenom (STT + fallback texte)
- [ ] Step `profile` : Selection profil accessible
- [ ] Step `installing` : Auto-install pack avec feedback
- [ ] Navigation vers Step permissions (Story 9.3) a la fin
- [ ] Tous les widgets interactifs avec `Semantics` wrapper
- [ ] Touch targets >= 48x48px

### Task 2 : ProfileSelector widget (presentation)

Creer `lib/features/onboarding/presentation/profile_selector.dart` :
- [ ] 4 options : aveugle, malvoyant, sourd, general
- [ ] Pre-selection basee sur `DetectedProfile` (Story 9.1)
- [ ] Navigable au vocal ("aveugle", "malvoyant", etc.)
- [ ] `Semantics` label sur chaque option
- [ ] Contrastes >= 4.5:1, touch targets >= 56x56px (actions critiques)

### Task 3 : PackInstaller (data)

Creer `lib/features/onboarding/data/pack_installer.dart` :
- [ ] `Future<void> installPack(AccessibilityProfile profile)`
- [ ] Mapping profil → liste de plugins a activer
- [ ] Utilise `PluginRegistry` (E5) pour enregistrer les plugins
- [ ] Feedback vocal pendant l'installation

### Task 4 : OnboardingNotifier (Riverpod)

Creer dans `lib/features/onboarding/di/providers.dart` :
- [ ] `onboardingNotifier` — AsyncNotifier qui gere l'etat de l'onboarding
- [ ] `onboardingCompleteProvider` — lit depuis `flutter_secure_storage` ou `SharedPreferences`
- [ ] Integration avec go_router `refreshListenable`

### Task 5 : go_router redirect guard

Modifier `lib/features/shell/` ou `lib/core/` (selon architecture existante) :
- [ ] Redirect guard : si onboarding pas complete → `/onboarding`
- [ ] Apres completion → redirect vers `/` (KitaShell)
- [ ] Pas de re-onboarding possible apres completion

### Task 6 : Tests

- [ ] `test/features/onboarding/presentation/onboarding_screen_test.dart`
  - Test : flow complet welcome → name → profile → install
  - Test : Kita parle en premier si screen reader actif
  - Test : selection profil accessible (Semantics)
  - Test : pack correct installe par profil
- [ ] `test/features/onboarding/data/pack_installer_test.dart`
  - Test : blind → Describe + Alert
  - Test : deaf → Alert (haptic only)
- [ ] Au moins 1 test widget avec `ensureSemantics()` + `containsSemantics`

## Accessibility Tax

- [ ] `Semantics` wrapper sur chaque bouton/option du profile selector
- [ ] `Semantics` wrapper sur le champ de saisie prenom
- [ ] Contrastes >= 4.5:1 sur tous les textes
- [ ] Touch targets >= 48x48px (56x56px pour selection profil)
- [ ] Flow 100% navigable en vocal

## Definition of Done

- [ ] OnboardingScreen complet avec 4 steps
- [ ] ProfileSelector avec pre-selection et vocal
- [ ] PackInstaller fonctionnel
- [ ] go_router redirect guard en place
- [ ] Kita parle en premier si VoiceOver/TalkBack actif
- [ ] Accessibility Tax verifie
- [ ] 10+ tests passent
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
