import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../orchestration/domain/agent_bus.dart';
import '../../orchestration/domain/clock.dart';
import '../../orchestration/domain/kita_agent.dart';
import '../../orchestration/domain/models/agent_manifest.dart';
import '../../orchestration/domain/output_handle.dart';
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

  /// Set of known valid permission strings for manifest validation.
  static const _validPermissions = {
    'camera',
    'microphone',
    'location',
    'motion',
    'haptic',
    'memory',
    'tts',
    'stt',
    'ai.text',
    'ai.vision',
  };

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
    _log.debug('Enforcing permissions for plugin ${manifest.id}');

    // Validate that all declared permissions are known.
    for (final perm in manifest.permissions) {
      if (!_validPermissions.contains(perm)) {
        _log.warning(
          'Plugin ${manifest.id} declares unknown permission: $perm',
        );
        return Result.failure(PluginFailure(
          userMessage: 'Le plugin declare une permission inconnue.',
          logMessage:
              'Plugin ${manifest.id} declares unknown permission: $perm',
          pluginId: manifest.id,
        ));
      }
    }

    // Memory access requires the 'memory' permission for non-official plugins.
    if (request.memory != null &&
        !manifest.permissions.contains('memory') &&
        manifest.trustLevel != TrustLevel.official) {
      _log.warning(
        'Plugin ${manifest.id} requests memory without permission',
      );
      return Result.failure(PluginFailure(
        userMessage: "Le plugin n'a pas la permission memoire.",
        logMessage:
            'Plugin ${manifest.id} requests memory without permission',
        pluginId: manifest.id,
      ));
    }

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
          allowedPermissions: manifest.permissions.toSet(),
        );
      case TrustLevel.official:
        _log.info('Plugin ${manifest.id} (official): shared memory');
        return memoryAccess;
    }
  }

  MemoryAccess? _buildAgentMemoryAccess(AgentManifest manifest) {
    if (memoryAccess == null) return null;

    switch (manifest.trustLevel) {
      case TrustLevel.unverified:
        _log.info('Agent ${manifest.id} (unverified): no memory access');
        return null;
      case TrustLevel.communityVerified:
        _log.info('Agent ${manifest.id} (community): sandboxed memory');
        return SandboxedMemoryAccess(
          delegate: memoryAccess!,
          pluginId: manifest.id,
          allowedPermissions: manifest.permissions.toSet(),
        );
      case TrustLevel.official:
        _log.info('Agent ${manifest.id} (official): shared memory');
        return memoryAccess;
    }
  }

  /// Builds a sandboxed [AgentContext] for a [KitaAgent] based on its manifest.
  ///
  /// Reuses the same sandboxing logic (permissions, quotas) as the
  /// plugin sandbox but returns an [AgentContext] instead of a [PluginRequest].
  AgentContext buildAgentContext({
    required AgentManifest manifest,
    required AgentBus bus,
    required OutputHandle output,
    required Clock clock,
  }) {
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

    final sandboxedMemory = _buildAgentMemoryAccess(manifest);

    _log.info('Built AgentContext for agent ${manifest.id}');

    return AgentContext(
      sensors: sandboxedSensors,
      ai: sandboxedAI,
      memory: sandboxedMemory,
      bus: bus,
      output: output,
      clock: clock,
    );
  }
}
