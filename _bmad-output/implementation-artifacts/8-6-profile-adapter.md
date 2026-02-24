# Story 8.6: ProfileAdapter — Routage multi-modal

## Status: review

## Story
As a **systeme Kita**,
I want **router chaque output vers les bonnes modalites selon le profil actif de l'utilisateur**,
So that **Marie (aveugle) recoit de la voix et de l'haptique, et les voyants recoivent aussi du visuel**.

## Acceptance Criteria
1. `adapter.feedback(visual, vocal, haptic)` executes adapted callbacks per active profile
2. Profile `aveugle`: vocal=ON, haptic=fort, visual=minimal (VoiceOver handles)
3. Profile `sourd`: vocal=OFF, haptic=fort, visual=primary
4. Profile `standard`: vocal=secondary, haptic=medium, visual=complete
5. Profile `aidant`: vocal=OFF, haptic=light, visual=complete+dashboard
6. Active profile read from Riverpod (`userProfileProvider`)
7. State change announcements (connection loss, battery <20%, degraded mode) go through ProfileAdapter
8. Tests verify routing for each profile

## Profiles Routing Table
| Profile | Visual | Vocal | Haptic |
|---------|--------|-------|--------|
| aveugle | skip | always | always |
| sourd | always | skip | always |
| standard | always | always | always |
| aidant | always | skip | always |

## Dev Agent Record
| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 11/11 pass |
| Coverage | All 4 profiles, null callbacks, profile switching, routing verification |
