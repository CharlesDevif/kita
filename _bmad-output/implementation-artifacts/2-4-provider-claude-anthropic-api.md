# Story 2.4: Provider Claude (Anthropic API)

## Status: review

## Story

As a **utilisateur de Kita**,
I want **que Kita puisse utiliser Claude comme provider IA cloud**,
So that **j'obtiens des descriptions de haute qualite via l'API Anthropic**.

## Acceptance Criteria

1. Il implemente `AIProvider` avec `tier = ProviderTier.cloudPowerful`
2. `complete()` envoie une requete texte a l'API Claude et retourne un `AIResponse`
3. `vision()` envoie une image + prompt et retourne une description textuelle
4. `validateApiKey()` verifie la validite de la cle API
5. Les erreurs reseau retournent `Result.failure(NetworkFailure)` — jamais de throw
6. Le timeout est configurable (defaut 3s)
7. Aucune donnee PII n'est incluse dans la requete
8. Les tests unitaires mockent l'API et verifient les cas succes/echec/timeout

## Technical Intelligence

### Anthropic API
- HTTP endpoint: `https://api.anthropic.com/v1/messages`
- Headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- Model: `claude-sonnet-4-20250514` (fast) or configurable
- Vision: send image as base64 `image` content block
- Uses `http` package from pubspec.yaml

### Implementation Notes
- File: `lib/features/ai/data/providers/claude_provider.dart`
- Use `http.Client` for testability (injectable)
- Timeout via `AppConfig.aiCloudTimeout` (3s default)
- API key stored externally (not in provider) — passed via constructor or config

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: Full Anthropic Messages API integration with text and vision. Mocked HTTP client for tests. Zero PII verified. 15 tests pass.
- Files Modified:
  - `lib/features/ai/data/providers/claude_provider.dart` (new)
  - `test/features/ai/data/providers/claude_provider_test.dart` (new)
