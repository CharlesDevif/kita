# Story 5.1: PluginManifest — Parsing et validation YAML

**Status:** done

## Story

As a **plugin developer**,
I want to **declare permissions and capabilities of my plugin in a YAML manifest**,
So that **Kita knows which sensors and services my plugin uses and can enforce permissions**.

## Acceptance Criteria

1. `PluginLoader.loadManifest(yamlString)` parses a `plugin.kita.yaml` string and returns `Result<PluginManifest>`
2. Manifest contains: id (reverse domain), name, version, description, permissions, capabilities, compatible profiles, trust level, voice commands
3. An invalid manifest returns `Result.failure` with an explanatory `PluginFailure`
4. Unit tests verify parsing of valid and invalid manifests

## Technical Design

### Files to create

| File | Purpose |
|------|---------|
| `lib/features/plugins/data/plugin_loader.dart` | `PluginLoader` class with `loadManifest(String yaml)` |
| `test/features/plugins/data/plugin_loader_test.dart` | Unit + integration tests |

### PluginLoader API

```dart
class PluginLoader {
  const PluginLoader();
  Result<PluginManifest> loadManifest(String yamlContent);
}
```

### YAML schema (`plugin.kita.yaml`)

```yaml
id: com.kita.describe          # Required, reverse domain
name: Kita Describe             # Required, display name
version: 1.0.0                  # Required, semver
description: Scene description  # Required
trust_level: official           # Required: official | community_verified | unverified
permissions:                    # Optional, list of strings
  - camera
  - ai.vision
capabilities:                   # Optional, list of strings
  - vision
  - text
compatible_profiles:            # Optional, list of strings
  - blind
  - low_vision
voice_commands:                 # Optional, list of strings
  - decris
  - describe
```

### Validation rules

1. **Required fields:** id, name, version, description, trust_level
2. **ID format:** must match reverse domain pattern `^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*){2,}$`
3. **Version format:** must match semver-like pattern `^\d+\.\d+\.\d+$`
4. **Trust level:** must be one of `official`, `community_verified`, `unverified`
5. **Permissions:** if present, must be a list of strings
6. **Capabilities:** if present, must be a list of strings
7. **Compatible profiles:** if present, must be a list of strings
8. **Voice commands:** if present, must be a list of strings

### Error handling

- YAML parse errors -> `PluginFailure` with descriptive message
- Missing required fields -> `PluginFailure` listing the missing fields
- Invalid ID format -> `PluginFailure` explaining the expected format
- Invalid version format -> `PluginFailure`
- Invalid trust_level -> `PluginFailure` listing valid values

### Technical Intelligence

- **yaml package:** `^3.1.3` already in pubspec.yaml
- `loadYaml(String)` returns `dynamic` (YamlMap) — must cast carefully
- YamlMap values are always `dynamic` — need safe casting
- No need for `loadYamlDocument` — `loadYaml` is sufficient for single document

### Pitfalls & Gotchas

- `loadYaml` throws `FormatException` on malformed YAML — wrap in `runCatching`
- YamlList items may not be strings — validate each item
- An empty YAML string or null top-level value needs explicit handling
- The `yaml` package returns `YamlMap` not `Map<String, dynamic>` — use typed access

## Dev Agent Record

| Field | Value |
|-------|-------|
| Agent | E5-Plugin |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests passing | 26/26 |
| dart analyze | clean |
