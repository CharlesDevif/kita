import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/plugins/domain/kita_plugin.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/plugin_sandbox.dart';

class MockPluginSandbox implements PluginSandbox {
  bool shouldFail = false;

  @override
  Future<Result<PluginResponse>> execute(
    KitaPlugin plugin,
    PluginRequest request,
  ) async {
    if (shouldFail) {
      return Result.failure(
        PluginFailure.sandboxViolation(plugin.manifest.id, 'execute'),
      );
    }
    return Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: 'Mock plugin response for ${request.command}',
    ));
  }

  @override
  Result<void> enforcePermissions(
    PluginManifest manifest,
    PluginRequest request,
  ) {
    if (shouldFail) {
      return Result.failure(
        PluginFailure.sandboxViolation(manifest.id, 'enforcePermissions'),
      );
    }
    return const Result.success(null);
  }
}
