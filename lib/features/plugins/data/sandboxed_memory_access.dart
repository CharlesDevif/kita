import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../memory/domain/episode.dart';
import '../domain/memory_access.dart';

/// A proxy that isolates memory access per plugin by namespacing keys.
///
/// Each plugin sees only its own data under `plugin_data/{pluginId}/`.
/// Access is denied if the plugin's manifest does not include the 'memory'
/// permission.
class SandboxedMemoryAccess implements MemoryAccess {
  const SandboxedMemoryAccess({
    required this.delegate,
    required this.pluginId,
    this.allowedPermissions = const {'memory'},
  });

  final MemoryAccess delegate;
  final String pluginId;

  /// The permissions declared by the plugin manifest.
  final Set<String> allowedPermissions;

  static final _log = KitaLogger('Plugin.Sandbox');

  String _namespacedKey(String key) => 'plugin_data/$pluginId/$key';

  /// Checks that the plugin holds the 'memory' permission.
  Result<void> _checkMemoryPermission() {
    if (!allowedPermissions.contains('memory')) {
      _log.warning('Plugin $pluginId denied memory access: no memory permission');
      return Result.failure(PluginFailure(
        userMessage: "Le plugin n'a pas la permission memoire.",
        logMessage: 'Memory access denied for plugin $pluginId',
        pluginId: pluginId,
      ));
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    final check = _checkMemoryPermission();
    if (check.isFailure) return Result.failure((check as Failure).failure);
    _log.info('Plugin $pluginId saving episode via sandboxed access');
    return delegate.saveEpisode(episode);
  }

  @override
  Future<Result<String?>> getPreference(String key) {
    final check = _checkMemoryPermission();
    if (check.isFailure) {
      return Future.value(Result.failure((check as Failure).failure));
    }
    return delegate.getPreference(_namespacedKey(key));
  }

  @override
  Future<Result<void>> setPreference(String key, String value) {
    final check = _checkMemoryPermission();
    if (check.isFailure) {
      return Future.value(Result.failure((check as Failure).failure));
    }
    return delegate.setPreference(_namespacedKey(key), value);
  }
}
