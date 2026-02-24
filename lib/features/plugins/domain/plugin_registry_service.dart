import '../../../core/errors/result.dart';
import 'kita_plugin.dart';
import 'plugin_state.dart';
import 'voice_command.dart';

/// Abstract interface for the plugin registry.
///
/// Manages plugin lifecycle: register -> activate -> use -> deactivate.
///
/// **Deprecated:** Use [AgentSupervisor] from
/// `lib/features/orchestration/data/agent_supervisor.dart` instead.
/// See `docs/spec-agent-orchestrator.md` for the migration guide.
@Deprecated('Use AgentSupervisor instead. See docs/spec-agent-orchestrator.md')
abstract interface class PluginRegistryService {
  Result<void> register(KitaPlugin plugin);
  Future<Result<void>> activate(String pluginId);
  Future<Result<void>> deactivate(String pluginId);
  KitaPlugin? getPlugin(String pluginId);
  List<PluginEntry> listPlugins();
  List<VoiceCommand> get aggregatedVoiceCommands;
}
