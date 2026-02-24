# Story 8.2: KitaShell — Scaffold principal Living Aura

## Status: review

## Story
As a **utilisateur de Kita**,
I want **un ecran principal avec l'orbe en haut, le contenu plugin au centre, et l'input en bas**,
So that **l'interface est claire, constante et immediatement comprehensible**.

## Acceptance Criteria
1. Layout 3 zones: header (status + orb), viewport (plugin content), input (voice/text) bottom
2. Passive mode: orb `large` centered, viewport reduced
3. Active mode: orb `small` in header (300ms), viewport deploys (300ms)
4. Animated transition passive->active (orb shrink + viewport slide-up)
5. Active->passive after 5s silence or "merci"
6. Focus order VoiceOver: Input -> Viewport -> Header
7. `KitaStatusIndicator` in header showing connection/battery/mode
8. Contrasts >= 4.5:1 (text), >= 3:1 (UI)
9. Semantics test matcher verifies labels on all interactive elements
10. Tests verify state transitions and focus order

## Technical Intelligence

### Shell Modes
- `ShellMode.passive`: orb large center, viewport minimized, input visible
- `ShellMode.active`: orb small header, viewport expanded, input visible

### Transition Durations
- passive->active: 300ms (KitaAnimationDurations.transition)
- active->passive: 500ms (KitaAnimationDurations.state)

### Status Indicator States
- `online` (teal), `offline` (grey), `degraded` (orange), `error` (red)

### Focus Order
VoiceOver reads: Input first -> Viewport -> Header (reversed visual order for accessibility)

## Implementation Plan
1. `ShellMode` enum in domain
2. `KitaStatusIndicator` widget
3. `KitaShell` scaffold with animated layout
4. Shell providers (mode, status)
5. Tests

## Dev Agent Record
| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 33/33 pass (22 shell + 11 indicator) |
| Coverage | Modes, transitions, semantics, focus order, all statuses |
