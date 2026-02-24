import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../memory/domain/episode.dart';
import '../domain/memory_access.dart';

/// A proxy that isolates memory access per plugin by namespacing keys.
///
/// Each plugin sees only its own data under `plugin_data/{pluginId}/`.
class SandboxedMemoryAccess implements MemoryAccess {
  const SandboxedMemoryAccess({
    required this.delegate,
    required this.pluginId,
  });

  final MemoryAccess delegate;
  final String pluginId;

  static final _log = KitaLogger('Plugin.Sandbox');

  String _namespacedKey(String key) => 'plugin_data/$pluginId/$key';

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    _log.info('Plugin $pluginId saving episode via sandboxed access');
    return delegate.saveEpisode(episode);
  }

  @override
  Future<Result<String?>> getPreference(String key) {
    return delegate.getPreference(_namespacedKey(key));
  }

  @override
  Future<Result<void>> setPreference(String key, String value) {
    return delegate.setPreference(_namespacedKey(key), value);
  }
}
