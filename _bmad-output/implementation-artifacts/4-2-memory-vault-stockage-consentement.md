# Story 4.2: MemoryVault — Stockage avec consentement

## Status: review

## Story
As a **utilisateur de Kita**, I want **que Kita demande mon consentement explicite avant de stocker mes données sensibles**, so that **je contrôle ce que Kita sait sur moi, conformément au RGPD Article 9**.

## Acceptance Criteria
- `MemoryVaultImpl` is implemented
- `saveEpisode(data)` stores a timestamped event in the episodic domain with auto tags
- `savePreference(key, value, category)` stores a preference in the semantic domain
- All sensitive data storage requires explicit consent via ConsentDao
- Consent is tracked in consent_log with date, data type, and user choice
- Storage is refused if consent has not been given — returns Result.failure
- 4 memory domains (working, episodic, semantic, relational) are functional
- Tests verify consent -> storage -> verification flow

## Implementation Plan
- MemoryVaultImpl wraps all 6 DAOs
- Consent check before sensitive operations
- Working memory is RAM-only (Riverpod state, not persisted)
- Episodic/Semantic/Relational map to DB tables via DAOs
- Zero PII in logs

## Files
- `lib/features/memory/data/memory_vault_impl.dart` — new
- `test/features/memory/data/memory_vault_impl_test.dart` — new
