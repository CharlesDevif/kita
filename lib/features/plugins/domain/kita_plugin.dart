import 'package:flutter/widgets.dart';

import '../../../core/errors/result.dart';
import 'plugin_manifest.dart';
import 'plugin_request.dart';
import 'plugin_response.dart';
import 'voice_command.dart';

@Deprecated(
  'Use KitaAgent from lib/features/orchestration/domain/kita_agent.dart instead',
)
abstract class KitaPlugin {
  PluginManifest get manifest;
  List<VoiceCommand> get voiceCommands;

  Future<void> onActivate();
  Future<void> onDeactivate();
  Future<Result<PluginResponse>> handleRequest(PluginRequest request);
  Widget? buildViewport(BuildContext context);
}
