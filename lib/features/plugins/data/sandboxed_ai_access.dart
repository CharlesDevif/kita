import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_response.dart';
import '../../ai/domain/image_data.dart';
import '../domain/ai_access.dart';
import 'plugin_quota_manager.dart';

/// A proxy that enforces quota limits on AI access for a plugin.
class SandboxedAIAccess implements AIAccess {
  const SandboxedAIAccess({
    required this.delegate,
    required this.pluginId,
    required this.quotaManager,
    required this.allowedPermissions,
  });

  final AIAccess delegate;
  final String pluginId;
  final PluginQuotaManager quotaManager;
  final Set<String> allowedPermissions;

  static final _log = KitaLogger('Plugin.Sandbox');

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    if (!allowedPermissions.contains('ai.text')) {
      _log.warning('Plugin $pluginId denied ai.text access');
      return Result.failure(PermissionFailure(
        userMessage: "Le plugin n'a pas la permission IA texte.",
        logMessage: 'Plugin $pluginId tried ai.text without permission',
        permission: 'ai.text',
      ));
    }

    final quotaCheck = quotaManager.checkQuota(pluginId);
    if (quotaCheck.isFailure) return Result.failure((quotaCheck as Failure).failure);

    quotaManager.recordCall(pluginId);
    return delegate.complete(request);
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    if (!allowedPermissions.contains('ai.vision')) {
      _log.warning('Plugin $pluginId denied ai.vision access');
      return Result.failure(PermissionFailure(
        userMessage: "Le plugin n'a pas la permission IA vision.",
        logMessage: 'Plugin $pluginId tried ai.vision without permission',
        permission: 'ai.vision',
      ));
    }

    final quotaCheck = quotaManager.checkQuota(pluginId);
    if (quotaCheck.isFailure) return Result.failure((quotaCheck as Failure).failure);

    quotaManager.recordCall(pluginId);
    return delegate.vision(image, prompt);
  }
}
