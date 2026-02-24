# Story 2.1: RequestClassifier — Classification des requetes

## Status: review

## Story

As a **systeme Kita**,
I want **classifier automatiquement chaque requete en 4 niveaux de priorite**,
So that **les requetes critiques sont traitees localement en < 50ms et les requetes standard via le cloud**.

## Acceptance Criteria

1. **Given** l'interface `RequestClassifier` existe (Epic 1)
   **When** l'implementation `RequestClassifierImpl` est creee
   **Then** chaque requete est classee en : `critical` (< 50ms, local uniquement), `urgent` (< 500ms), `standard` (< 5s), `background` (async)
2. Les mots-cles "alerte", "danger", "obstacle" sont classes `critical`
3. Les mots-cles "decris", "lis" sont classes `standard`
4. La classification prend < 1ms
5. Les tests unitaires couvrent les 4 niveaux avec des cas concrets
6. Le classifier retourne un `Result<RequestPriority>`

## Technical Intelligence

### Existing Interfaces (from Epic 1)
- `RequestClassifier` in `lib/features/ai/domain/request_classifier.dart`: `Result<RequestPriority> classify(String prompt)`
- `RequestPriority` enum: `critical`, `urgent`, `standard`, `background`
- `Result<T>` sealed class in `lib/core/errors/result.dart`
- `KitaLogger` in `lib/core/utils/logger.dart` with `[Source] Message` format

### Implementation Pattern
- File: `lib/features/ai/data/request_classifier_impl.dart`
- Keyword-based classification with normalized lowercase matching
- Must be synchronous (< 1ms) — no async, no regex if avoidable
- Return `Result.success(priority)` always — classification should never fail

### Keyword Maps (from epics.md + architecture.md)
- **critical**: alerte, danger, obstacle, attention, stop, urgence, aide (immediate safety)
- **urgent**: decris, lis, ou suis-je, qui est la (needs quick response)
- **standard**: raconte, explique, traduis, resume, cherche (cloud-quality preferred)
- **background**: rappelle, sauvegarde, analyse, statistiques (can be async)

## Tasks

1. Create `RequestClassifierImpl` in `lib/features/ai/data/request_classifier_impl.dart`
2. Write comprehensive tests in `test/features/ai/data/request_classifier_impl_test.dart`
3. Verify < 1ms classification with stopwatch in test
4. Update sprint-status.yaml

## Dev Agent Record

- Agent Model: claude-opus-4-6
- Started: 2026-02-24
- Completion Notes: Keyword-based classifier with priority ordering (critical > urgent > background > standard default). 42 tests pass including performance test < 1ms.
- Files Modified:
  - `lib/features/ai/data/request_classifier_impl.dart` (new)
  - `test/features/ai/data/request_classifier_impl_test.dart` (new)
