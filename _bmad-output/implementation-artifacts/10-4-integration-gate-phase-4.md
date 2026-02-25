---
story_id: "10.4"
title: "Integration Gate Phase 4"
epic: "E10 — Kita veille — Mode Passif & Background"
phase: "4"
status: ready-for-dev
priority: critical
estimated_complexity: L
depends_on: ["9.5", "10.3"]
blocks: []
---

# Story 10.4 : Integration Gate Phase 4

## User Story

**En tant que** equipe de developpement,
**je veux** valider le parcours utilisateur complet avant la phase de qualite finale,
**afin que** E11 puisse se concentrer sur la CI/CD et les tests de conformite sans decouvrir de regressions.

## Acceptance Criteria

- **AC1:** Test onboarding E2E : detection VoiceOver → onboarding vocal < 3 min → permissions → pack installe → Premier Moment Magique
- **AC2:** Test mode aidant : Sophie configure pour Marie → profil aveugle → plugins installes → test guide → relancement avec accueil personnalise
- **AC3:** Test mode passif stable : mode passif actif pendant 1h → 0 crash, 0 memory leak, RAM < 200 MB
- **AC4:** Test cycle complet Marie : onboarding → "decris" → description → marche → alerte obstacle → "stop" → mode passif
- **AC5:** Test fallback hors-ligne : coupure reseau → annonce vocale → mode degrade → retour connexion → annonce retour

## Technical Intelligence

### Structure des tests E2E

Les tests d'integration gate utilisent le meme pattern que les gates precedents (7.3, 2.8) :
- Mocks complets des services natifs (camera, TTS, STT, haptic)
- FakeClock pour les timers
- Pas de dependance hardware
- Verification des flows de bout en bout via les outputs (speak, haptic, state)

### Tests necessitant des mocks plateforme

| Test | Mock requis |
|------|------------|
| Onboarding VoiceOver | `AccessibilityFeatures` mock avec `accessibleNavigation: true` |
| Permissions | `permission_handler` mock (grant/deny simulation) |
| Premier Moment Magique | Camera mock + AI mock + TTS mock |
| Mode passif | Accelerometre mock + Camera mock + Battery mock |
| Fallback offline | Network connectivity mock |
| Background service | MethodChannel mock pour FGS/Audio session |

### Pattern test E2E existant (reference Phase 3)

```dart
// Reference : test/features/orchestration/e2e/marie_decrit_test.dart
testWidgets('Marie decrit — flow complet', (tester) async {
  // Setup mocks
  final mockOutput = MockOutputHandle(agentId: 'com.kita.describe');
  final mockBus = MockAgentBus();
  final fakeClock = FakeClock();
  // ...
  // Verify flow
  expect(mockOutput.speakCalls.length, greaterThan(0));
  expect(mockOutput.speakCalls.first.text, contains('salon'));
});
```

### Test stabilite 1h — Approche

On ne peut pas faire un vrai test de 1h en CI. Approche :
- Simuler 1h en avancant le FakeClock par increments
- Verifier qu'aucune Map/List ne grossit indefiniment (memory leak check)
- Verifier que les subscriptions sont correctement gerees
- Compter les objets alloues avant/apres

### Test fallback hors-ligne

```dart
// Simuler la coupure reseau
mockNetworkService.setConnected(false);

// L'AI Router doit basculer sur le fallback local
final result = await orchestrator.handleInput(
  RawInput.voice('decris'),
);

// Verifier l'annonce vocale de mode degrade
expect(mockOutput.speakCalls, contains(
  predicate((call) => call.text.contains('hors ligne')),
));
```

## Pitfalls & Gotchas

1. **Pas de vrai hardware en CI** — Tous les tests E2E doivent fonctionner avec des mocks. Pas de camera reelle, pas de VoiceOver reel, pas de GPS reel.

2. **Test mode passif 1h** — Simuler avec FakeClock, pas de `await Future.delayed(Duration(hours: 1))`. Avancer le clock par tranches de 5 minutes et verifier l'etat a chaque tranche.

3. **AccessibilityFeatures mock** — Il n'y a pas de moyen standard de mocker `WidgetsBinding.instance.accessibilityFeatures`. Options : (a) abstraire derriere une interface `ProfileDetection` (deja fait en 9.1), (b) utiliser un `TestWidgetsFlutterBinding` custom.

4. **permission_handler mock** — Le package fournit un `MockPermissionHandlerPlatform` pour les tests. Voir la doc du package.

5. **Regression check** — Tous les 1163 tests existants doivent continuer a passer. Lancer `flutter test` sur tout le projet, pas juste sur les tests E2E.

## Architecture References

- `test/features/orchestration/e2e/` — Tests E2E existants (E12)
- `test/integration/phase3_integration_gate_test.dart` — Gate precedent
- Tous les story files 9.1-9.5 et 10.1-10.3

## Implementation Tasks

### Task 1 : Test onboarding E2E (AC1)

Creer `test/integration/phase4_onboarding_e2e_test.dart` :
- [ ] Setup : mock AccessibilityFeatures (VoiceOver active)
- [ ] Verify : detection → profil blind pre-selectionne
- [ ] Verify : Kita parle en premier
- [ ] Verify : flow name → profile → permissions → pack install
- [ ] Verify : Premier Moment Magique → description vocale
- [ ] Verify : completion → redirect vers KitaShell

### Task 2 : Test mode aidant E2E (AC2)

Creer `test/integration/phase4_caregiver_e2e_test.dart` :
- [ ] Setup : mode aidant selectionne
- [ ] Verify : nom cible "Marie" configure
- [ ] Verify : profil blind selectionne
- [ ] Verify : permissions groupees
- [ ] Verify : test guide DECRIS fonctionne
- [ ] Verify : relancement → "Bonjour Marie !" → mode passif

### Task 3 : Test mode passif stable (AC3)

Creer `test/integration/phase4_passive_stability_test.dart` :
- [ ] Setup : mode passif active avec mocks capteurs
- [ ] Simuler 1h (FakeClock, tranches de 5 min)
- [ ] Verify : 0 exception
- [ ] Verify : pas de memory leak (Maps/Lists ne grossissent pas)
- [ ] Verify : subscriptions correctement gerees
- [ ] Note : le check RAM < 200 MB est une mesure device-only, pas en unit test

### Task 4 : Test cycle complet Marie (AC4)

Creer `test/integration/phase4_marie_cycle_test.dart` :
- [ ] Setup : onboarding complete, mode passif actif
- [ ] Verify : "decris" → spawn DescribeAgent → description vocale
- [ ] Verify : mouvement detecte → camera active
- [ ] Verify : obstacle detecte → alerte vocale + haptic
- [ ] Verify : "stop" → cancelAll → mode passif
- [ ] Verify : retour etat passif stable

### Task 5 : Test fallback hors-ligne (AC5)

Creer `test/integration/phase4_offline_fallback_test.dart` :
- [ ] Setup : connexion active → "decris" fonctionne
- [ ] Simuler coupure reseau
- [ ] Verify : annonce vocale mode degrade
- [ ] Verify : "decris" → fallback local (ML Kit)
- [ ] Simuler retour connexion
- [ ] Verify : annonce vocale retour normal

### Task 6 : Regression check

- [ ] `flutter test` complet — tous les tests existants passent
- [ ] `dart analyze --fatal-infos` clean
- [ ] Pas de nouvelle dependance non declaree

## Definition of Done

- [ ] 5 tests E2E passent (onboarding, aidant, passif, cycle Marie, offline)
- [ ] Tous les tests existants (1163+) continuent a passer
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe (complet)
- [ ] Zero PII dans les logs des tests
- [ ] sprint-status.yaml mis a jour
- [ ] Phase Gate 4→5 : PASS

---

## Dev Agent Record

**Agent Model:**
**Date:**

### Completion Notes

_(A remplir par l'agent de developpement)_

### Files Modified

_(A remplir par l'agent de developpement)_
