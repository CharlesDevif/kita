import '../../../core/errors/result.dart';
import 'preference.dart';
import 'user_profile.dart';

/// Repository providing a unified interface for user profile, preferences,
/// and secure key management.
///
/// This is the Riverpod-facing API that presentation/providers use.
abstract interface class PreferencesRepository {
  // --- Profile ---

  /// Loads the active user profile, or null if none exists.
  Future<Result<KitaUserProfile?>> getActiveProfile();

  /// Creates or updates the user profile. Returns the profile ID.
  Future<Result<int>> saveProfile({
    String? displayName,
    String? accessibilityProfile,
    String? language,
    double? ttsSpeed,
    String? ttsVoice,
    bool? hapticEnabled,
  });

  /// Updates an existing profile by ID.
  Future<Result<bool>> updateProfile(int id, {
    String? displayName,
    String? accessibilityProfile,
    String? language,
    double? ttsSpeed,
    String? ttsVoice,
    bool? hapticEnabled,
  });

  // --- Preferences ---

  /// Gets a single preference value by key.
  Future<Result<String?>> getPreference(String key);

  /// Sets a preference value. Requires an active consent for semantic scope.
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
  });

  /// Gets all preferences.
  Future<Result<List<KitaPreference>>> getAllPreferences();

  // --- Secure keys (API keys, tokens) ---

  /// Reads an API key from secure storage. Never logs the value.
  Future<Result<String?>> getApiKey(String providerId);

  /// Stores an API key in secure storage. Never logs the value.
  Future<Result<void>> setApiKey(String providerId, String key);

  /// Deletes an API key from secure storage.
  Future<Result<void>> deleteApiKey(String providerId);

  /// Checks whether an API key exists for a provider.
  Future<Result<bool>> hasApiKey(String providerId);
}
