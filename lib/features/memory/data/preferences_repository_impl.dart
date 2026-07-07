import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/preference.dart';
import '../domain/preferences_repository.dart';
import '../domain/secure_key_vault.dart';
import '../domain/user_profile.dart';
import 'daos/profile_dao.dart';
import 'memory_vault_impl.dart';

final _log = KitaLogger('Memory');

/// API key storage key prefix. Keys stored as "api_key_{providerId}".
///
/// Public so the forget(everything) purge (wired in memory/di/providers.dart)
/// can target the same secure-storage keys this repository writes.
const apiKeyStoragePrefix = 'api_key_';

/// Backward-compatible private alias used throughout this file.
const _apiKeyPrefix = apiKeyStoragePrefix;

/// Implementation of [PreferencesRepository] combining ProfileDao,
/// PreferenceDao (via MemoryVault for consent), and SecureKeyVault.
class PreferencesRepositoryImpl implements PreferencesRepository {
  PreferencesRepositoryImpl({
    required this.profileDao,
    required this.vault,
    required this.secureKeyVault,
  });

  final ProfileDao profileDao;
  final MemoryVaultImpl vault;
  final SecureKeyVault secureKeyVault;

  // --- Profile ---

  @override
  Future<Result<KitaUserProfile?>> getActiveProfile() async {
    return profileDao.getActive();
  }

  @override
  Future<Result<int>> saveProfile({
    String? displayName,
    String? accessibilityProfile,
    String? language,
    double? ttsSpeed,
    String? ttsVoice,
    bool? hapticEnabled,
  }) async {
    // Check if a profile already exists
    final existingResult = await profileDao.getActive();
    final existing = existingResult.getOrNull();

    if (existing != null) {
      // Update existing profile
      final updateResult = await profileDao.update(
        existing.id,
        displayName: displayName,
        accessibilityProfile: accessibilityProfile,
        language: language,
        ttsSpeed: ttsSpeed,
        ttsVoice: ttsVoice,
        hapticEnabled: hapticEnabled,
      );
      if (updateResult.isFailure) {
        return Result.failure(
          (updateResult as Failure).failure,
        );
      }
      _log.info('Profile updated');
      return Result.success(existing.id);
    }

    // Create new profile
    final result = await profileDao.insert(
      displayName: displayName,
      accessibilityProfile: accessibilityProfile ?? 'standard',
      language: language ?? 'fr',
      ttsSpeed: ttsSpeed ?? 1.0,
      ttsVoice: ttsVoice,
      hapticEnabled: hapticEnabled ?? true,
    );
    if (result.isSuccess) {
      _log.info('Profile created');
    }
    return result;
  }

  @override
  Future<Result<bool>> updateProfile(int id, {
    String? displayName,
    String? accessibilityProfile,
    String? language,
    double? ttsSpeed,
    String? ttsVoice,
    bool? hapticEnabled,
  }) async {
    return profileDao.update(
      id,
      displayName: displayName,
      accessibilityProfile: accessibilityProfile,
      language: language,
      ttsSpeed: ttsSpeed,
      ttsVoice: ttsVoice,
      hapticEnabled: hapticEnabled,
    );
  }

  // --- Preferences ---

  @override
  Future<Result<String?>> getPreference(String key) async {
    return vault.getPreference(key);
  }

  @override
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
  }) async {
    return vault.setPreference(
      key: key,
      value: value,
      category: category,
      source: 'user',
    );
  }

  @override
  Future<Result<List<KitaPreference>>> getAllPreferences() async {
    return vault.getPreferences();
  }

  // --- Secure keys ---

  @override
  Future<Result<String?>> getApiKey(String providerId) async {
    final result = await secureKeyVault.read('$_apiKeyPrefix$providerId');
    if (result.isSuccess) {
      _log.debug('API key read for provider (found=${result.getOrNull() != null})');
    }
    return result;
  }

  @override
  Future<Result<void>> setApiKey(String providerId, String key) async {
    final result =
        await secureKeyVault.write('$_apiKeyPrefix$providerId', key);
    if (result.isSuccess) {
      _log.info('API key stored for provider');
    }
    return result;
  }

  @override
  Future<Result<void>> deleteApiKey(String providerId) async {
    return secureKeyVault.delete('$_apiKeyPrefix$providerId');
  }

  @override
  Future<Result<bool>> hasApiKey(String providerId) async {
    return secureKeyVault.containsKey('$_apiKeyPrefix$providerId');
  }
}
