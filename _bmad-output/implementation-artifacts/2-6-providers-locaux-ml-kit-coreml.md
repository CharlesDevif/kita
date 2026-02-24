# Story 2.6: Providers locaux ML Kit et CoreML

## Status: review

## Story

As a **utilisateur de Kita**,
I want **que Kita puisse traiter les requetes localement via ML Kit (Android) et CoreML (iOS)**,
So that **les alertes critiques fonctionnent en < 50ms sans connexion internet**.

## Acceptance Criteria

1. `MLKitProvider` (Android) implemente `AIProvider` avec `tier = ProviderTier.local`
2. `CoreMLProvider` (iOS) implemente `AIProvider` avec `tier = ProviderTier.local`
3. Chaque provider supporte OCR (lecture de texte) et classification d'image basique
4. `isAvailable` detecte la plateforme courante et retourne `true` uniquement sur la bonne plateforme
5. La latence de traitement est < 50ms
6. Les providers fonctionnent 100% hors-ligne
7. Les tests verifient la detection de plateforme et le fallback

## Technical Intelligence

### Implementation Notes
- ML Kit and CoreML require native platform plugins which are not available in test environment
- For MVP, create stub implementations that return degraded responses
- Real ML pipeline will be integrated in Phase 3 (E7 - Alert plugin)
- Platform detection via `dart.io.Platform` or `defaultTargetPlatform`
- Use `google_mlkit_object_detection` and `tflite_flutter` from pubspec

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: Unified LocalProvider for both platforms with injectable TargetPlatform. MVP stub responses with keyword-based differentiation. Full ML pipeline deferred to E7 (Alert). 16 tests pass including < 50ms performance.
- Files Modified:
  - `lib/features/ai/data/providers/local_provider.dart` (new)
  - `test/features/ai/data/providers/local_provider_test.dart` (new)
