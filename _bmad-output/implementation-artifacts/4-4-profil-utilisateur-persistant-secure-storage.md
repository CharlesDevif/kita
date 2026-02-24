# Story 4.4: Profil utilisateur persistant et secure storage

## Status: review

## Story
As a **utilisateur de Kita**, I want **que mon profil (preferences, accessibilite, providers) persiste entre les sessions et que mes cles API soient stockees en securite**, so that **je n'ai pas a reconfigurer Kita a chaque lancement**.

## Acceptance Criteria
- User profile (name, accessibility profile, language, TTS voice, speed) persists in `user_profiles`
- API keys stored in Keychain (iOS) / Keystore (Android) via `flutter_secure_storage`
- API keys are NEVER stored in plaintext or logged
- On launch, profile is loaded and AI providers can be configured automatically
- `PreferencesRepository` provides a Riverpod interface for reading/writing preferences
- Tests verify persistence across simulated sessions

## Implementation Summary

### Domain layer
- **SecureKeyVault** (`lib/features/memory/domain/secure_key_vault.dart`): Abstract interface for secure key storage (read, write, delete, containsKey, deleteAll)
- **PreferencesRepository** (`lib/features/memory/domain/preferences_repository.dart`): Unified interface for profile, preferences, and API key management

### Data layer
- **SecureKeyVaultImpl** (`lib/features/memory/data/secure_key_vault_impl.dart`): Wraps `FlutterSecureStorage` with Result error handling, zero PII in logs
- **PreferencesRepositoryImpl** (`lib/features/memory/data/preferences_repository_impl.dart`): Combines ProfileDao, MemoryVaultImpl (for consent-gated preferences), and SecureKeyVault. API keys stored with prefix `api_key_{providerId}`

### DI / Riverpod providers
- **providers.dart** (`lib/features/memory/di/providers.dart`): 4 providers:
  - `memoryVaultProvider` (keepAlive) — MemoryVault with all 6 DAOs
  - `secureKeyVaultProvider` (keepAlive) — SecureKeyVaultImpl
  - `preferencesRepositoryProvider` (keepAlive) — PreferencesRepository combining all
  - `activeProfileProvider` (keepAlive) — Loads active user profile at startup

### Mocks
- **MockSecureKeyVault** (`test/mocks/mock_secure_key_vault.dart`): In-memory mock with shouldFail toggle

### Tests
- `preferences_repository_impl_test.dart` — 18 tests:
  - Profile CRUD (5 tests): create, update, persist across sessions
  - Preferences (5 tests): get, set with consent, getAllPreferences, persist
  - Secure keys (8 tests): get, set, has, delete, scoping by provider, failure propagation, persist

## Files
- `lib/features/memory/domain/secure_key_vault.dart` — new
- `lib/features/memory/domain/preferences_repository.dart` — new
- `lib/features/memory/data/secure_key_vault_impl.dart` — new
- `lib/features/memory/data/preferences_repository_impl.dart` — new
- `lib/features/memory/di/providers.dart` — new
- `lib/features/memory/di/providers.g.dart` — generated
- `test/mocks/mock_secure_key_vault.dart` — new
- `test/features/memory/data/preferences_repository_impl_test.dart` — new (18 tests)
- `test/features/memory/domain/secure_key_vault_test.dart` — new (7 tests)
