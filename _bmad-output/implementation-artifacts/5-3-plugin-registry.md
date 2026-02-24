# Story 5.3: PluginRegistry — Enregistrement et lifecycle

**Status:** done

## Story

As a **Kita system**,
I want to **register, activate and deactivate plugins dynamically**,
So that **plugins can be loaded and unloaded without restarting the application**.

## Acceptance Criteria

1. `register(plugin)` registers a plugin with validated manifest
2. `activate(pluginId)` calls `onActivate()` and makes plugin available
3. `deactivate(pluginId)` calls `onDeactivate()`, releases resources
4. `getPlugin(pluginId)` returns active plugin or null
5. `listPlugins()` returns list with state (registered/active/inactive)
6. Voice commands from active plugins aggregated and available
7. Plugin crash doesn't affect other plugins or shell
8. Injectable via Riverpod (`pluginRegistryServiceProvider`)
9. Tests verify lifecycle (register -> activate -> use -> deactivate)

## Technical Design

### Files to create

| File | Purpose |
|------|---------|
| `lib/features/plugins/data/plugin_registry.dart` | `PluginRegistryImpl` with lifecycle management |
| `lib/features/plugins/domain/plugin_registry_service.dart` | Abstract interface |
| `lib/features/plugins/domain/plugin_state.dart` | `PluginState` enum + `PluginEntry` model |
| `test/features/plugins/data/plugin_registry_test.dart` | Tests |

### Plugin States

```
registered -> active -> inactive (can re-activate)
```

### PluginEntry

```dart
class PluginEntry {
  final KitaPlugin plugin;
  final PluginState state; // registered, active, inactive
}
```

## Dev Agent Record

| Field | Value |
|-------|-------|
| Agent | E5-Plugin |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests passing | 26/26 |
| dart analyze | clean |
