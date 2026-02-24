import 'package:yaml/yaml.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/plugin_manifest.dart';
import '../domain/trust_level.dart';

/// Parses and validates `plugin.kita.yaml` manifest content.
class PluginLoader {
  const PluginLoader();

  static final _log = KitaLogger('Plugin.Loader');

  static final _idPattern = RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*){2,}$');
  static final _versionPattern = RegExp(r'^\d+\.\d+\.\d+$');

  static const _validTrustLevels = {
    'official': TrustLevel.official,
    'community_verified': TrustLevel.communityVerified,
    'unverified': TrustLevel.unverified,
  };

  static const _requiredFields = ['id', 'name', 'version', 'description', 'trust_level'];

  /// Parses a YAML string into a validated [PluginManifest].
  ///
  /// Returns [Result.failure] with a [PluginFailure] if the YAML is malformed
  /// or any required field is missing/invalid.
  Result<PluginManifest> loadManifest(String yamlContent) {
    final Object? parsed;
    try {
      parsed = loadYaml(yamlContent);
    } catch (e, stack) {
      _log.error('Failed to parse YAML', error: e, stackTrace: stack);
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'YAML parse error: $e',
      ));
    }

    if (parsed is! YamlMap && parsed is! Map) {
      _log.error('YAML root is not a map');
      return const Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'YAML root is not a map',
      ));
    }

    final map = parsed as Map;

    // Check required fields
    final missing = <String>[];
    for (final field in _requiredFields) {
      if (!map.containsKey(field) || map[field] == null) {
        missing.add(field);
      }
    }
    if (missing.isNotEmpty) {
      final msg = 'Missing required fields: ${missing.join(', ')}';
      _log.error(msg);
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est incomplet.',
        logMessage: msg,
      ));
    }

    // Validate id
    final id = map['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      _log.error('Invalid plugin id: $id');
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Invalid plugin id "$id". Expected reverse domain format (e.g. com.kita.describe)',
        pluginId: id is String ? id : null,
      ));
    }

    // Validate name
    final name = map['name'];
    if (name is! String || name.isEmpty) {
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Invalid plugin name: must be a non-empty string',
        pluginId: id,
      ));
    }

    // Validate version
    final version = map['version'];
    final versionStr = version is String ? version : version?.toString() ?? '';
    if (!_versionPattern.hasMatch(versionStr)) {
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Invalid version "$versionStr". Expected format: X.Y.Z',
        pluginId: id,
      ));
    }

    // Validate description
    final description = map['description'];
    if (description is! String || description.isEmpty) {
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Invalid description: must be a non-empty string',
        pluginId: id,
      ));
    }

    // Validate trust_level
    final trustLevelStr = map['trust_level'];
    if (trustLevelStr is! String || !_validTrustLevels.containsKey(trustLevelStr)) {
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Invalid trust_level "$trustLevelStr". '
            'Valid values: ${_validTrustLevels.keys.join(', ')}',
        pluginId: id,
      ));
    }
    final trustLevel = _validTrustLevels[trustLevelStr]!;

    // Parse optional list fields
    final permissionsResult = _parseStringList(map, 'permissions', id);
    if (permissionsResult case Failure(:final failure)) {
      return Result.failure(failure);
    }

    final capabilitiesResult = _parseStringList(map, 'capabilities', id);
    if (capabilitiesResult case Failure(:final failure)) {
      return Result.failure(failure);
    }

    final profilesResult = _parseStringList(map, 'compatible_profiles', id);
    if (profilesResult case Failure(:final failure)) {
      return Result.failure(failure);
    }

    final commandsResult = _parseStringList(map, 'voice_commands', id);
    if (commandsResult case Failure(:final failure)) {
      return Result.failure(failure);
    }

    final manifest = PluginManifest(
      id: id,
      name: name,
      version: versionStr,
      description: description,
      trustLevel: trustLevel,
      permissions: (permissionsResult as Success<List<String>>).value,
      capabilities: (capabilitiesResult as Success<List<String>>).value,
      compatibleProfiles: (profilesResult as Success<List<String>>).value,
      voiceCommands: (commandsResult as Success<List<String>>).value,
    );

    _log.info('Loaded manifest for plugin $id v$versionStr ($trustLevelStr)');
    return Result.success(manifest);
  }

  Result<List<String>> _parseStringList(Map<dynamic, dynamic> map, String key, String pluginId) {
    final value = map[key];
    if (value == null) return const Result.success([]);

    if (value is! YamlList && value is! List) {
      return Result.failure(PluginFailure(
        userMessage: 'Le manifest du plugin est invalide.',
        logMessage: 'Field "$key" must be a list',
        pluginId: pluginId,
      ));
    }

    final list = (value as List).cast<Object?>();
    final strings = <String>[];
    for (final item in list) {
      if (item is! String) {
        return Result.failure(PluginFailure(
          userMessage: 'Le manifest du plugin est invalide.',
          logMessage: 'Field "$key" must contain only strings, found: $item',
          pluginId: pluginId,
        ));
      }
      strings.add(item);
    }
    return Result.success(strings);
  }
}
