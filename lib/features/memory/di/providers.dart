import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/database_provider.dart';
import '../../ai/data/response_cache.dart';
import '../data/auto_cleanup_service.dart';
import '../data/daos/consent_dao.dart';
import '../data/daos/episode_dao.dart';
import '../data/daos/person_dao.dart';
import '../data/daos/plugin_data_dao.dart';
import '../data/daos/preference_dao.dart';
import '../data/daos/profile_dao.dart';
import '../data/memory_vault_impl.dart';
import '../data/preferences_repository_impl.dart';
import '../data/secure_key_vault_impl.dart';
import '../domain/memory_vault.dart';
import '../domain/preferences_repository.dart';
import '../domain/secure_key_vault.dart';
import '../domain/user_profile.dart';

part 'providers.g.dart';

/// Provides the [MemoryVault] singleton backed by real DAOs.
@Riverpod(keepAlive: true)
Future<MemoryVault> memoryVault(Ref ref) async {
  final db = await ref.watch(kitaDatabaseProvider.future);
  final keyVault = ref.watch(secureKeyVaultProvider);
  return MemoryVaultImpl(
    episodeDao: EpisodeDao(db),
    preferenceDao: PreferenceDao(db),
    personDao: PersonDao(db),
    profileDao: ProfileDao(db),
    pluginDataDao: PluginDataDao(db),
    consentDao: ConsentDao(db),
    // Shared db enables atomic (transactional) forget-everything deletes.
    database: db,
    // Leader-wired cross-feature purge for forget(everything): clears the AI
    // request cache (prompts/responses stored in clear text) and the stored
    // cloud API keys. It deliberately does NOT call keyVault.deleteAll(),
    // which would also wipe the database encryption key and brick the vault.
    onPurgeExternal: () async {
      await ResponseCache(database: db).clear();
      await keyVault.delete('${apiKeyStoragePrefix}anthropic');
      await keyVault.delete('${apiKeyStoragePrefix}openai');
    },
  );
}

/// Provides the [SecureKeyVault] singleton for API key storage.
@Riverpod(keepAlive: true)
SecureKeyVault secureKeyVault(Ref ref) {
  return SecureKeyVaultImpl(
    storage: const FlutterSecureStorage(),
  );
}

/// Provides the [PreferencesRepository] combining profile, prefs, and keys.
@Riverpod(keepAlive: true)
Future<PreferencesRepository> preferencesRepository(Ref ref) async {
  final db = await ref.watch(kitaDatabaseProvider.future);
  final vault = await ref.watch(memoryVaultProvider.future);
  final keyVault = ref.watch(secureKeyVaultProvider);
  return PreferencesRepositoryImpl(
    profileDao: ProfileDao(db),
    vault: vault as MemoryVaultImpl,
    secureKeyVault: keyVault,
  );
}

/// Loads the active user profile at startup. Returns null if no profile exists.
@Riverpod(keepAlive: true)
Future<KitaUserProfile?> activeProfile(Ref ref) async {
  final repo = await ref.watch(preferencesRepositoryProvider.future);
  final result = await repo.getActiveProfile();
  return result.getOrNull();
}

/// Provides the [AutoCleanupService] that removes expired episodes.
/// Starts cleanup immediately and schedules periodic runs.
@Riverpod(keepAlive: true)
Future<AutoCleanupService> autoCleanup(Ref ref) async {
  final db = await ref.watch(kitaDatabaseProvider.future);
  final service = AutoCleanupService(episodeDao: EpisodeDao(db));
  await service.start();
  ref.onDispose(service.dispose);
  return service;
}
