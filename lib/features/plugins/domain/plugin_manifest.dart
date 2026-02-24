import 'trust_level.dart';

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.trustLevel,
    this.permissions = const [],
    this.capabilities = const [],
    this.compatibleProfiles = const [],
    this.voiceCommands = const [],
  });

  /// Reverse domain format: "com.kita.describe"
  final String id;
  final String name;
  final String version;
  final String description;
  final TrustLevel trustLevel;
  final List<String> permissions;
  final List<String> capabilities;
  final List<String> compatibleProfiles;
  final List<String> voiceCommands;
}
