# Story 8.5: KitaAlert et KitaPermissionCard

## Status: review

## Story
As a **utilisateur de Kita**,
I want **voir des alertes critiques plein viewport et des demandes de permission avec storytelling contextuel**,
So that **les situations d'urgence sont immediatement visibles et je comprends pourquoi chaque permission est demandee**.

## Acceptance Criteria
1. `KitaAlert` takes full viewport for critical alerts (red/orange bg, large text)
2. `KitaAlert` is a live region (Semantics) auto-announced by VoiceOver
3. `KitaPermissionCard` shows permission requests with contextual storytelling
4. PermissionCard has 4 states: asking, granted, denied, re-asking
5. Contrasts >= 4.5:1 (text), >= 3:1 (UI)
6. Touch targets >= 48x48px (56x56px for critical actions)
7. Semantics test matcher verifies labels
8. Tests verify both components

## Dev Agent Record
| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 26/26 pass (11 alert + 15 permission) |
| Coverage | Both severities, 4 permission states, semantics, interactions, sizing |
