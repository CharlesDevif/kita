# Story 8.3: KitaInput — Zone d'input unifiee voix/texte

## Status: review

## Story
As a **utilisateur de Kita**,
I want **une zone d'input qui combine saisie texte et bouton micro**,
So that **je peux interagir avec Kita par voix ou par texte selon ma preference**.

## Acceptance Criteria
1. Widget displays text field + mic button (56x56px)
2. 4 states: `idle` (placeholder "Parle ou ecris a Kita"), `listening` (mic active, visual wave), `typing` (keyboard open), `disabled` (during processing)
3. In `listening` mode, STT transcription appears in real-time in the field
4. Submit via Enter (text) or silence detection (voice)
5. Text interface is COMPLETE alternative to voice
6. `Semantics(label: "Parle ou ecris a Kita")` configured
7. Contrasts >= 4.5:1 (text), >= 3:1 (UI)
8. Semantics test matcher verifies labels
9. Tests verify 4 states and both input modes

## Implementation Plan
1. `InputState` enum (idle, listening, typing, disabled)
2. `KitaInput` widget with TextField + mic FloatingActionButton
3. Callbacks: `onTextSubmit`, `onVoiceStart`, `onVoiceStop`
4. STT integration via callback pattern (actual STT from E3)
5. Tests

## Dev Agent Record
| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 20/20 pass |
| Coverage | 4 states, text submit, mic toggle, transcription, semantics, sizing |
