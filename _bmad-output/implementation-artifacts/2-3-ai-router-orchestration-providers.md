# Story 2.3: AIRouter — Orchestration des providers

## Status: review

## Story

As a **systeme Kita**,
I want **un routeur IA qui orchestre les providers selon la classification et la disponibilite**,
So that **chaque requete est traitee par le provider optimal disponible**.

## Acceptance Criteria

1. Given le RequestClassifier et la FallbackChain existent (Stories 2.1, 2.2)
   When l'AIRouterImpl est implemente
   Then le routeur selectionne le provider optimal selon : priorite de la requete, disponibilite du provider, tier du provider
2. Les requetes critical sont toujours routees vers le tier local
3. Les requetes standard tentent cloud-powerful en premier
4. Le routeur utilise la FallbackChain en cas d'echec
5. Chaque reponse est un AIResponse unifie avec meta (provider, latency, tier, cached) et status (success, fallback, degraded)
6. Le routeur est injectable via Riverpod (aiRouterServiceProvider)

## Technical Intelligence

### Dependencies
- RequestClassifierImpl (Story 2.1)
- FallbackChain (Story 2.2)
- AIProvider interface, AIRequest, AIResponse
- Riverpod for DI

### File: `lib/features/ai/data/ai_router_impl.dart`

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: AIRouterImpl classifies requests if needed, delegates to FallbackChain, measures total latency. 8 tests pass.
- Files Modified:
  - `lib/features/ai/data/ai_router_impl.dart` (new)
  - `test/features/ai/data/ai_router_impl_test.dart` (new)
