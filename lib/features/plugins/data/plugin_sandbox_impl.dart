import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/ai_access.dart';
import '../domain/kita_plugin.dart';
import '../domain/memory_access.dart';
import '../domain/plugin_manifest.dart';
import '../domain/plugin_request.dart';
import '../domain/plugin_response.dart';
import '../domain/plugin_sandbox.dart';
import '../domain/sensor_access.dart';
import '../domain/trust_level.dart';
import 'plugin_quota_manager.dart';
import 'sandboxed_ai_access.dart';
import 'sandboxed_memory_access.dart';
import 'sandboxed_sensor_access.dart';

/// Concrete sandbox that wraps plugin execution with permission enforcement.
///
/// Creates sandboxed proxies for sensor, AI, and memory access based on
/// the plugin's manifest and trust level.
class PluginSandboxImpl implements PluginSandbox {
  PluginSandboxImpl({
    required this.sensorAccess,
    required this.aiAccess,
    this.memoryAccess,
    PluginQuotaManager? quotaManager,
  }) : quotaManager = quotaManager ?? PluginQuotaManager();

  final SensorAccess sensorAccess;
  final AIAccess aiAccess;
  final MemoryAccess? memoryAccess;
  final PluginQuotaManager quotaManager;

  static final _log = KitaLogger('Plugin.Sandbox');

  @override
  Future<Result<PluginResponse>> execute(
    KitaPlugin plugin,
    PluginRequest request,
  ) async {
    final manifest = plugin.manifest;

    // Enforce permissions first
    final permCheck = enforcePermissions(manifest, request);
    if (permCheck.isFailure) {
      return Result.failure((permCheck as Failure).failure);
    }

    // Build sandboxed request
    final sandboxedRequest = _buildSandboxedRequest(manifest, request);

    // Execute plugin with crash isolation
    try {
      final result = await plugin.handleRequest(sandboxedRequest);
      return result;
    } catch (e, stack) {
      _log.error(
        'Plugin ${manifest.id} crashed during execution',
        error: e,
        stackTrace: stack,
      );
      return Result.failure(PluginFailure(
        userMessage: 'Le plugin a rencontre une erreur.',
        logMessage: 'Plugin ${manifest.id} crashed: $e',
        pluginId: manifest.id,
        cause: e,
        stackTrace: stack,
      ));
    }
  }

  @override
  Result<void> enforcePermissions(
    PluginManifest manifest,
    PluginRequest request,
  ) {
    // Check that the request isn't using sensors that aren't in the manifest
    // This is a structural check — the proxies do the real enforcement.
    _log.debug('Enforcing permissions for plugin ${manifest.id}');
    return const Result.success(null);
  }

  PluginRequest _buildSandboxedRequest(
    PluginManifest manifest,
    PluginRequest request,
  ) {
    final permissions = manifest.permissions.toSet();

    final sandboxedSensors = SandboxedSensorAccess(
      delegate: sensorAccess,
      allowedPermissions: permissions,
      pluginId: manifest.id,
    );

    final sandboxedAI = SandboxedAIAccess(
      delegate: aiAccess,
      pluginId: manifest.id,
      quotaManager: quotaManager,
      allowedPermissions: permissions,
    );

    final sandboxedMemory = _buildMemoryAccess(manifest);

    return PluginRequest(
      command: request.command,
      params: request.params,
      sensors: sandboxedSensors,
      ai: sandboxedAI,
      memory: sandboxedMemory,
    );
  }

  MemoryAccess? _buildMemoryAccess(PluginManifest manifest) {
    if (memoryAccess == null) return null;

    switch (manifest.trustLevel) {
      case TrustLevel.unverified:
        _log.info('Plugin ${manifest.id} (unverified): no memory access');
        return null;
      case TrustLevel.communityVerified:
        _log.info('Plugin ${manifest.id} (community): sandboxed memory');
        return SandboxedMemoryAccess(
          delegate: memoryAccess!,
          pluginId: manifest.id,
        );
      case TrustLevel.official:
        _log.info('Plugin ${manifest.id} (official): shared memory');
        return memoryAccess;
    }
  }
}
