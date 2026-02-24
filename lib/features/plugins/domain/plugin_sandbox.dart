import '../../../core/errors/result.dart';
import 'kita_plugin.dart';
import 'plugin_manifest.dart';
import 'plugin_request.dart';
import 'plugin_response.dart';

abstract interface class PluginSandbox {
  Future<Result<PluginResponse>> execute(
    KitaPlugin plugin,
    PluginRequest request,
  );
  Result<void> enforcePermissions(
    PluginManifest manifest,
    PluginRequest request,
  );
}
