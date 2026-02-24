import 'kita_plugin.dart';

enum PluginState { registered, active, inactive }

class PluginEntry {
  const PluginEntry({
    required this.plugin,
    required this.state,
  });

  final KitaPlugin plugin;
  final PluginState state;

  PluginEntry copyWith({PluginState? state}) {
    return PluginEntry(
      plugin: plugin,
      state: state ?? this.state,
    );
  }

  String get id => plugin.manifest.id;
  String get name => plugin.manifest.name;
}
