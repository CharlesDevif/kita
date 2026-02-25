import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/profile_detection.dart';

/// Plugin pack configuration for each accessibility profile.
///
/// Defines which agents/plugins are auto-installed during onboarding
/// based on the user's selected profile.
class PackConfig {
  const PackConfig({
    required this.agentIds,
    required this.description,
  });

  /// Agent IDs to activate for this profile.
  final List<String> agentIds;

  /// Human-readable description of the pack.
  final String description;
}

/// Maps accessibility profiles to their default plugin packs.
const Map<AccessibilityProfile, PackConfig> defaultPacks = {
  AccessibilityProfile.blind: PackConfig(
    agentIds: ['com.kita.describe', 'com.kita.alert'],
    description: 'Describe + Alert',
  ),
  AccessibilityProfile.lowVision: PackConfig(
    agentIds: ['com.kita.describe', 'com.kita.alert'],
    description: 'Describe + Alert (zoom)',
  ),
  AccessibilityProfile.general: PackConfig(
    agentIds: ['com.kita.describe'],
    description: 'Describe',
  ),
};

/// Installs the appropriate plugin pack for a given profile.
///
/// During onboarding, this records which agents should be activated.
/// The actual agent spawning happens via [AgentSupervisor] at app startup.
class PackInstaller {
  PackInstaller({
    SavePackCallback? onSavePack,
  }) : _onSavePack = onSavePack;

  static final _log = KitaLogger('Onboarding.PackInstaller');

  /// Callback to persist the selected pack configuration.
  /// Injected to avoid direct dependency on PreferencesRepository.
  final SavePackCallback? _onSavePack;

  /// Returns the pack configuration for a given profile.
  PackConfig getPackForProfile(AccessibilityProfile profile) {
    return defaultPacks[profile] ?? defaultPacks[AccessibilityProfile.general]!;
  }

  /// Installs the pack for the given profile.
  ///
  /// Saves the agent IDs to preferences so they can be spawned at startup.
  Future<Result<PackConfig>> installPack(AccessibilityProfile profile) async {
    final pack = getPackForProfile(profile);
    _log.info('Installing pack for ${profile.name}: ${pack.description}');

    if (_onSavePack != null) {
      final result = await _onSavePack(pack.agentIds);
      if (result.isFailure) {
        _log.warning('Failed to save pack configuration');
        return Result.failure(
          (result as Failure<void>).failure,
        );
      }
    }

    _log.info('Pack installed: ${pack.agentIds.join(", ")}');
    return Result.success(pack);
  }
}

/// Callback type for persisting pack configuration.
typedef SavePackCallback = Future<Result<void>> Function(List<String> agentIds);
