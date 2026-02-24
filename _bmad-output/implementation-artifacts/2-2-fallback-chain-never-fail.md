# Story 2.2: FallbackChain never-fail

## Status: review

## Story

As a **utilisateur de Kita**,
I want **que Kita me reponde toujours, meme quand tout echoue**,
So that **je ne suis jamais laisse sans reponse, surtout dans les situations critiques**.

## Acceptance Criteria

1. Given un AIRequest classifie arrive dans la fallback chain
   When le provider cloud-powerful echoue (timeout 3s)
   Then la requete cascade vers cloud-fast (timeout 3s)
2. Si cloud-fast echoue, la requete cascade vers le provider local
3. Si le provider local echoue, une alerte brute (son + vibration hardcode) est declenchee
4. Une requete classee `critical` ne passe JAMAIS par le cloud — traitement local direct
5. Chaque niveau de cascade log le fallback avec le niveau `warning`
6. Le dernier niveau (alerte brute) ne peut PAS echouer — `Result.success` garanti
7. Les tests unitaires simulent les echecs en cascade et verifient que la reponse est toujours `Success`

## Technical Intelligence

### Architecture Pattern (from architecture.md)
```
Requete -> RequestClassifier -> AIRouter
  |-- cloud-powerful (timeout 3s) -> succes -> reponse
  |-- cloud-fast (timeout 3s) -> succes -> reponse
  |-- local (ML Kit/CoreML) -> succes -> reponse (degradee)
  '-- alerte brute -> succes GARANTI -> reponse minimale
```

### Dependencies
- `AIProvider` interface for provider interactions
- `ProviderTier` enum: local, cloudFast, cloudPowerful
- `AIResponse` / `AIResponseMeta` / `AIResponseStatus`
- `KitaLogger` for logging fallbacks
- `AppConfig.aiCloudTimeout` (3s) / `AppConfig.aiLocalTimeout` (500ms)

### Implementation
- File: `lib/features/ai/data/fallback_chain.dart`
- FallbackChain receives a list of AIProviders sorted by tier
- For critical requests: skip cloud providers, go directly to local
- Each failed tier logs a warning and tries the next
- Last resort: brute alert response that CANNOT fail

## Tasks

1. Create `FallbackChain` class in `lib/features/ai/data/fallback_chain.dart`
2. Write tests in `test/features/ai/data/fallback_chain_test.dart`
3. Cover: success on first try, cascade through all tiers, critical skip cloud, brute alert

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: Never-fail cascade: cloud-powerful -> cloud-fast -> local -> brute alert. Critical skips cloud. Brute alert guaranteed Success. 12 tests pass.
- Files Modified:
  - `lib/features/ai/data/fallback_chain.dart` (new)
  - `test/features/ai/data/fallback_chain_test.dart` (new)
