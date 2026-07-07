import '../../../core/constants/limits.dart';
import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/kita_plugin.dart';
import '../domain/plugin_registry_service.dart';
import '../domain/plugin_state.dart';
import '../domain/voice_command.dart';

/// Concrete plugin registry managing lifecycle of all registered plugins.
///
/// Enforces max active plugins limit and crash isolation.
///
/// **Deprecated:** Use [AgentSupervisor] from
/// `lib/features/orchestration/data/agent_supervisor.dart` instead.
/// See `docs/spec-agent-orchestrator.md` for the migration guide.
@Deprecated('Use AgentSupervisor instead. See docs/spec-agent-orchestrator.md')
class PluginRegistryImpl implements PluginRegistryService {
  PluginRegistryImpl({
    this.maxActivePlugins = Limits.maxActivePlugins,
  });

  final int maxActivePlugins;

  static final _log = KitaLogger('Plugin.Registry');

  final Map<String, PluginEntry> _plugins = {};

  @override
  Result<void> register(KitaPlugin plugin) {
    final id = plugin.manifest.id;

    if (_plugins.containsKey(id)) {
      _log.warning('Plugin $id already registered');
      return Result.failure(PluginFailure(
        userMessage: 'Ce plugin est déjà enregistré.',
        logMessage: 'Plugin $id already registered',
        pluginId: id,
      ));
    }

    _plugins[id] = PluginEntry(
      plugin: plugin,
      state: PluginState.registered,
    );
    _log.info('Registered plugin $id (${plugin.manifest.name})');
    return const Result.success(null);
  }

  @override
  Future<Result<void>> activate(String pluginId) async {
    final entry = _plugins[pluginId];
    if (entry == null) {
      return Result.failure(PluginFailure(
        userMessage: 'Plugin introuvable.',
        logMessage: 'Cannot activate: plugin $pluginId not registered',
        pluginId: pluginId,
      ));
    }

    if (entry.state == PluginState.active) {
      _log.info('Plugin $pluginId already active');
      return const Result.success(null);
    }

    // Check active plugins limit
    final activeCount =
        _plugins.values.where((e) => e.state == PluginState.active).length;
    if (activeCount >= maxActivePlugins) {
      _log.warning('Cannot activate $pluginId: max active plugins reached '
          '($activeCount/$maxActivePlugins)');
      return Result.failure(PluginFailure(
        userMessage: 'Nombre maximum de plugins actifs atteint.',
        logMessage: 'Max active plugins reached: $activeCount/$maxActivePlugins',
        pluginId: pluginId,
      ));
    }

    // Call onActivate with crash isolation
    try {
      await entry.plugin.onActivate();
    } catch (e, stack) {
      _log.error('Plugin $pluginId crashed during activation',
          error: e, stackTrace: stack);
      return Result.failure(PluginFailure(
        userMessage: "Le plugin n'a pas pu démarrer.",
        logMessage: 'Plugin $pluginId crashed during activation: $e',
        pluginId: pluginId,
        cause: e,
        stackTrace: stack,
      ));
    }

    _plugins[pluginId] = entry.copyWith(state: PluginState.active);
    _log.info('Activated plugin $pluginId');
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deactivate(String pluginId) async {
    final entry = _plugins[pluginId];
    if (entry == null) {
      return Result.failure(PluginFailure(
        userMessage: 'Plugin introuvable.',
        logMessage: 'Cannot deactivate: plugin $pluginId not registered',
        pluginId: pluginId,
      ));
    }

    if (entry.state != PluginState.active) {
      _log.info('Plugin $pluginId not active, nothing to deactivate');
      return const Result.success(null);
    }

    // Call onDeactivate with crash isolation
    try {
      await entry.plugin.onDeactivate();
    } catch (e, stack) {
      _log.error('Plugin $pluginId crashed during deactivation',
          error: e, stackTrace: stack);
      // Still mark as inactive even if deactivation crashes
    }

    _plugins[pluginId] = entry.copyWith(state: PluginState.inactive);
    _log.info('Deactivated plugin $pluginId');
    return const Result.success(null);
  }

  @override
  KitaPlugin? getPlugin(String pluginId) {
    final entry = _plugins[pluginId];
    if (entry == null || entry.state != PluginState.active) return null;
    return entry.plugin;
  }

  @override
  List<PluginEntry> listPlugins() {
    return List.unmodifiable(_plugins.values);
  }

  @override
  List<VoiceCommand> get aggregatedVoiceCommands {
    return _plugins.values
        .where((e) => e.state == PluginState.active)
        .expand((e) => e.plugin.voiceCommands)
        .toList();
  }
}
