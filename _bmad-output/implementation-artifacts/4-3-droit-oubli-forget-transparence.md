# Story 4.3: Droit a l'oubli — Forget et transparence

## Status: review

## Story
As a **utilisateur de Kita**, I want **pouvoir effacer toutes mes donnees et voir tout ce que Kita sait sur moi**, so that **j'ai le controle total sur ma vie privee**.

## Acceptance Criteria
- `forget(ForgetRequest.everything)` erases 100% of data from all tables
- `forget(ForgetRequest.domain(MemoryDomain.episodic))` erases only the specified domain
- `forget(ForgetRequest.plugin(pluginId))` erases only plugin data
- After `forget()`, an audit verifies no residual data exists (0 recoverable data)
- `whatDoYouKnow()` returns a structured list of all stored data by domain
- Tests verify complete erasure and audit verification

## Implementation Summary

### Domain changes
- **ForgetRequest**: Added `ForgetRequest.olderThan()` and `ForgetRequest.specific()` factory constructors
- **MemoryVault interface**: Added `auditForget(ForgetRequest)` method returning `Result<bool>`

### MemoryVaultImpl
- `forget()` handles all 5 ForgetScope values: everything, domain, plugin, olderThan, specific
- Confirmation gate: forget fails if `confirmation=false`
- `whatDoYouKnow()` aggregates data summaries from episodic/semantic/relational domains
- `auditForget()` verifies data was actually deleted by counting remaining rows per scope

### MockMemoryVault
- Updated with `auditForget()` method for use in other features' tests

### Tests (26 new tests in forget_and_audit_test.dart)
- 5 forget scope tests (everything, domain x3, plugin)
- 6 audit verification tests (confirms 0 residual after forget)
- 3 error case tests (missing domain, missing pluginId, missing date)
- 2 confirmation gate tests
- 3 audit detects residual data tests
- 3 transparency after forget tests
- 4 additional scope tests (olderThan, specific)

## Files
- `lib/features/memory/domain/forget_request.dart` — modified (added factory constructors)
- `lib/features/memory/domain/memory_vault.dart` — modified (added auditForget)
- `lib/features/memory/data/memory_vault_impl.dart` — modified (added auditForget impl)
- `test/mocks/mock_memory_vault.dart` — modified (added auditForget)
- `test/features/memory/data/forget_and_audit_test.dart` — new (26 tests)
