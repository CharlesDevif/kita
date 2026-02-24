# Story 4.1: Tables Drift et DAOs — Schéma mémoire

## Status: review

## Story
As a **système Kita**, I want **les 7 tables Drift créées avec leurs DAOs typesafe**, so that **toutes les données utilisateur sont stockées de manière structurée et chiffrée**.

## Acceptance Criteria
- 6 typed DAOs: EpisodeDao, PreferenceDao, PersonDao, ProfileDao, PluginDataDao, ConsentDao
- Each DAO uses columns defined in pre-declared `.drift` schemas
- Each DAO returns domain objects, not row objects
- `dart run build_runner build` generates code without error
- Unit tests verify basic CRUD on each DAO
- Migration v1 is defined (already done in E1)

## Technical Intelligence

### Drift DAO Pattern (v2.31+)
DAOs extend `DatabaseAccessor<KitaDatabase>` and use `@DriftAccessor(tables: [...])` annotation.
Since tables are defined in `.drift` files (not Dart), the generated table classes are available via `KitaDatabase`.

**Key pattern:**
```dart
@DriftAccessor()
class EpisodeDao extends DatabaseAccessor<KitaDatabase> {
  EpisodeDao(super.db);
  // Access tables via: db.episodes, db.persons, etc.
}
```

### Name Collision: domain Episode vs generated Episode
The generated `database.g.dart` produces a `Episode` data class that conflicts with `domain/episode.dart`.
**Solution:** Use import prefix `as db` for database import in DAO files.

### Generated Data Classes
- `Episode` (from episodes table) - fields: id, source, eventType, summary, details, tags, importanceScore, isPinned, createdAt, expiresAt
- `Preference` (from preferences) - fields: id, category, prefKey, value, confidenceScore, source, createdAt, updatedAt
- `Person` (from persons) - fields: id, name, relationship, notes, interests, lastMentionedAt, createdAt, updatedAt
- `UserProfile` (from user_profiles) - fields: id, displayName, accessibilityProfile, language, ttsSpeed, ttsVoice, hapticEnabled, createdAt, updatedAt
- `ConsentLogData` (from consent_log) - fields: id, consentType, scope, granted, grantedAt, revokedAt, details
- `PluginDataData` (from plugin_data) - fields: id, pluginId, namespace, dataKey, value, createdAt, updatedAt

### Companion Classes for Inserts
- `EpisodesCompanion`, `PreferencesCompanion`, `PersonsCompanion`, `UserProfilesCompanion`, `ConsentLogCompanion`, `PluginDataCompanion`

### Testing with Real Drift DB
Use in-memory SQLite: `sqlite3.openInMemory()` + `NativeDatabase.opened(rawDb)`.
Pattern already established in `test/core/data/database_test.dart`.

## Domain Models Needed
- `KitaEpisode` (rename from `Episode` to avoid collision) OR keep `Episode` and use import prefixes
- `KitaPerson` — new domain model
- `KitaUserProfile` — new domain model
- `KitaPreference` — new domain model
- `KitaPluginData` — new domain model
- `ConsentEntry` — already exists

## Files to Create/Modify
- `lib/features/memory/domain/person.dart` — new
- `lib/features/memory/domain/user_profile.dart` — new
- `lib/features/memory/domain/preference.dart` — new
- `lib/features/memory/domain/plugin_data_entry.dart` — new
- `lib/features/memory/data/daos/episode_dao.dart` — new
- `lib/features/memory/data/daos/preference_dao.dart` — new
- `lib/features/memory/data/daos/person_dao.dart` — new
- `lib/features/memory/data/daos/profile_dao.dart` — new
- `lib/features/memory/data/daos/plugin_data_dao.dart` — new
- `lib/features/memory/data/daos/consent_dao.dart` — new
- `test/features/memory/data/daos/episode_dao_test.dart` — new
- `test/features/memory/data/daos/preference_dao_test.dart` — new
- `test/features/memory/data/daos/person_dao_test.dart` — new
- `test/features/memory/data/daos/profile_dao_test.dart` — new
- `test/features/memory/data/daos/plugin_data_dao_test.dart` — new
- `test/features/memory/data/daos/consent_dao_test.dart` — new

## Pitfalls & Gotchas
- `tags` in episodes is stored as TEXT (comma-separated), must parse to `List<String>` in domain
- `interests` in persons is stored as TEXT (comma-separated), same handling
- Generated `Episode` class has `int id` but domain uses `String id` — need conversion
- `ConsentLogData` uses `consentType` + `scope` fields vs domain `ConsentEntry` uses `domain` + `purpose` — need mapping
- `PluginDataDao` table is in `features/plugins/data/tables/` but DAO lives in `features/memory/data/daos/`
- Never log PII (names, preferences values) — only log operation names and counts
