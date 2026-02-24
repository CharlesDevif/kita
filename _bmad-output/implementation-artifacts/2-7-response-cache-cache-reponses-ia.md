# Story 2.7: ResponseCache — Cache des reponses IA

## Status: review

## Story

As a **systeme Kita**,
I want **cacher les reponses IA dans Drift selon la priorite de la requete**,
So that **les requetes repetees sont servies instantanement et la batterie est economisee**.

## Acceptance Criteria

1. La table `request_cache` est creee dans Drift (done in E1)
2. Les requetes `critical` ne sont JAMAIS cachees
3. Les requetes `urgent` sont cachees 30s
4. Les requetes `standard` sont cachees 5 min
5. Les requetes `background` sont cachees 1h
6. Le cache est consulte AVANT de router vers un provider
7. Les entrees expirees sont nettoyees automatiquement
8. Les tests verifient le hit/miss cache et l'expiration TTL

## Technical Intelligence

### Drift table (already exists from E1)
- `request_cache` table with: id, request_hash, request_type, response_content, provider_id, ttl_seconds, created_at, expires_at
- Use `KitaDatabase.requestCache` for access
- TTL values from `AppConfig`: cacheTtlCritical (0), cacheTtlUrgent (30s), cacheTtlStandard (5m), cacheTtlBackground (1h)

### For tests
- Use `NativeDatabase.memory()` for in-memory SQLite

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: Raw SQL cache using FNV-1a hash. TTL by priority, critical never cached. Uses ISO 8601 text dates to match .drift file defaults. Real Drift in-memory DB tests. 14 tests pass.
- Files Modified:
  - `lib/features/ai/data/response_cache.dart` (new)
  - `test/features/ai/data/response_cache_test.dart` (new)
