class PluginDataEntry {
  const PluginDataEntry({
    required this.id,
    required this.pluginId,
    required this.namespace,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String pluginId;
  final String namespace;
  final String key;
  final String value;
  final DateTime createdAt;
  final DateTime updatedAt;
}
