# Story 4.5: Nettoyage automatique et politique de donnees

## Status: review

## Story
As a **systeme Kita**, I want **nettoyer automatiquement les donnees episodiques > 30 jours sauf celles marquees comme importantes**, so that **la base de donnees ne grossit pas indefiniment et la vie privee est respectee**.

## Acceptance Criteria
- Episodes > 30 days are deleted automatically
- Episodes marked `isPinned = true` (important) are preserved indefinitely
- Cleanup runs at app launch and every 24h
- No user data leaves the device without explicit consent
- Cloud AI requests contain only the minimum necessary (no profile, no memory context unless explicit)
- No tracking or identifying analytics
- Tests verify selective cleanup (old vs important)

## Implementation Summary

### AutoCleanupService
- `lib/features/memory/data/auto_cleanup_service.dart`
- Configurable `retentionPeriod` (default 30 days) and `cleanupInterval` (default 24h)
- `start()` runs cleanup immediately then schedules periodic timer
- `runCleanup()` calls `episodeDao.deleteExpiredBefore(cutoff)` which filters out pinned episodes
- `stop()` / `dispose()` cancels the timer
- Returns `Result<int>` with count of deleted episodes

### Riverpod provider
- `autoCleanupProvider` in `lib/features/memory/di/providers.dart`
- keepAlive, starts at app launch via provider initialization
- Disposes on provider disposal

### Privacy guarantees
- Consent gates already enforced by MemoryVaultImpl (Stories 4.2/4.3)
- Zero PII in all logs (KitaLogger format)
- No analytics or tracking packages in pubspec.yaml
- SecureKeyVault for API keys (Story 4.4) never logs values

### Tests (10 tests)
- Selective cleanup: old deleted, pinned preserved, nothing to clean, empty DB, custom retention
- Scheduling: start runs immediately, stop/dispose cancel timer
- Mixed scenarios: bulk cleanup, boundary at exactly 30 days

## Files
- `lib/features/memory/data/auto_cleanup_service.dart` — new
- `lib/features/memory/di/providers.dart` — modified (added autoCleanupProvider)
- `lib/features/memory/di/providers.g.dart` — regenerated
- `test/features/memory/data/auto_cleanup_service_test.dart` — new (10 tests)
