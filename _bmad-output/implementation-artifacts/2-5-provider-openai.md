# Story 2.5: Provider OpenAI

## Status: review

## Story

As a **utilisateur de Kita**,
I want **que Kita puisse utiliser OpenAI comme provider IA alternatif**,
So that **j'ai le choix entre plusieurs providers et un fallback cloud**.

## Acceptance Criteria

1. Il implemente `AIProvider` avec `tier = ProviderTier.cloudFast`
2. `complete()` et `vision()` fonctionnent via l'API OpenAI
3. `validateApiKey()` verifie la cle OpenAI
4. Le meme format `AIResponse` est retourne
5. Les tests unitaires couvrent les memes cas que le ClaudeProvider

## Technical Intelligence

### OpenAI API
- HTTP endpoint: `https://api.openai.com/v1/chat/completions`
- Headers: `Authorization: Bearer <key>`, `Content-Type: application/json`
- Model: `gpt-4o-mini` (fast, cheap) — configurable
- Vision: image_url content part with base64 data URL
- Uses `http` package

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: OpenAI Chat Completions API with text and vision (data URL format). Same test coverage as Claude. 14 tests pass.
- Files Modified:
  - `lib/features/ai/data/providers/openai_provider.dart` (new)
  - `test/features/ai/data/providers/openai_provider_test.dart` (new)
