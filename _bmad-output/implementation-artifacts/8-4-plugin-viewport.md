# Story 8.4: PluginViewport et KitaFeedbackBubble

## Status: review

## Story
As a **plugin Kita**,
I want **afficher mon contenu dans une zone sandbox au centre du shell et voir les reponses de Kita**,
So that **mon UI est visible sans casser le shell ni l'accessibilite**.

## Acceptance Criteria
1. `PluginViewport` is scrollable container displaying active plugin widget
2. Viewport is a visual sandbox: no access to header/input, no overlay outside zone
3. If plugin has no custom viewport, plain text response is displayed
4. Viewport is a live region (Semantics) for VoiceOver
5. `KitaFeedbackBubble` shows responses with Kita avatar, content and timestamp (variants: text, image, rich)
6. Contrasts >= 4.5:1 (text), >= 3:1 (UI)
7. Semantics test matcher verifies labels
8. Tests verify both components and accessibility

## Dev Agent Record
| Field | Value |
|-------|-------|
| Agent | E8-Shell |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests | 17/17 pass (8 viewport + 9 bubble) |
| Coverage | Plugin widget, fallback, sandbox, semantics, variants, timestamp |
