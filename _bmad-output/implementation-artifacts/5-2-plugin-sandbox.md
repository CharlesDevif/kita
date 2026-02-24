# Story 5.2: PluginSandbox — Isolation et enforcement des permissions

**Status:** done

## Story

As a **Kita system**,
I want to **isolate each plugin and enforce permissions declared in its manifest**,
So that **a malicious plugin cannot access unauthorized sensors or data**.

## Acceptance Criteria

1. `SensorAccess` proxy gives access only to sensors declared in the manifest
2. `AIAccess` proxy routes AI requests via AIRouter with quota enforcement
3. `MemoryAccess` proxy gives access only to `plugin_data` namespace per plugin_id
4. Unverified plugins: NO MemoryAccess
5. Community verified: sandboxed MemoryAccess
6. Official: shared memory access
7. Unauthorized access -> `Result.failure(PermissionFailure)` + logged
8. `PluginQuotaManager` enforces AI request quotas per plugin
9. Tests verify enforcement for each trust level

## Technical Design

### Files to create

| File | Purpose |
|------|---------|
| `lib/features/plugins/data/plugin_sandbox_impl.dart` | `PluginSandboxImpl` implementing `PluginSandbox` |
| `lib/features/plugins/data/plugin_quota_manager.dart` | `PluginQuotaManager` for AI quota enforcement |
| `lib/features/plugins/data/sandboxed_sensor_access.dart` | `SandboxedSensorAccess` proxy |
| `lib/features/plugins/data/sandboxed_ai_access.dart` | `SandboxedAIAccess` proxy with quota |
| `lib/features/plugins/data/sandboxed_memory_access.dart` | `SandboxedMemoryAccess` proxy |
| `test/features/plugins/data/plugin_sandbox_impl_test.dart` | Tests |
| `test/features/plugins/data/plugin_quota_manager_test.dart` | Tests |

### Trust level matrix

| Level | SensorAccess | AIAccess | MemoryAccess |
|-------|-------------|----------|--------------|
| Official | All declared | Full with quota | Shared memory |
| Community verified | All declared | Full with quota | Sandboxed by plugin_id |
| Unverified | All declared | Limited with quota | null (no access) |

### Quota

- `Limits.maxPluginApiCallsPerMinute = 10` per plugin
- Sliding window per minute
- Exceeded quota -> `PluginFailure`

## Dev Agent Record

| Field | Value |
|-------|-------|
| Agent | E5-Plugin |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tests passing | 35/35 (sandbox) + 10 (quota) |
| dart analyze | clean |
