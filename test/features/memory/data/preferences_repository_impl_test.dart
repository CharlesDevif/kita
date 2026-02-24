import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/data/preferences_repository_impl.dart';

import '../../../../test/mocks/mock_secure_key_vault.dart';

void main() {
  late KitaDatabase db;
  late PreferencesRepositoryImpl repo;
  late MockSecureKeyVault mockKeyVault;
  late ConsentDao consentDao;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));

    final episodeDao = EpisodeDao(db);
    final preferenceDao = PreferenceDao(db);
    final personDao = PersonDao(db);
    final profileDao = ProfileDao(db);
    final pluginDataDao = PluginDataDao(db);
    consentDao = ConsentDao(db);

    final vault = MemoryVaultImpl(
      episodeDao: episodeDao,
      preferenceDao: preferenceDao,
      personDao: personDao,
      profileDao: profileDao,
      pluginDataDao: pluginDataDao,
      consentDao: consentDao,
    );

    mockKeyVault = MockSecureKeyVault();

    repo = PreferencesRepositoryImpl(
      profileDao: profileDao,
      vault: vault,
      secureKeyVault: mockKeyVault,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> grantConsentFor(String scope) async {
    await consentDao.insert(
      consentType: 'data_storage',
      scope: scope,
      granted: true,
    );
  }

  group('PreferencesRepository — Profile', () {
    test('getActiveProfile returns null when no profile exists', () async {
      final result = await repo.getActiveProfile();
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('saveProfile creates new profile', () async {
      final result = await repo.saveProfile(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
        language: 'fr',
        ttsSpeed: 1.2,
        hapticEnabled: true,
      );
      expect(result.isSuccess, isTrue);

      final profile = (await repo.getActiveProfile()).getOrNull();
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Marie'));
      expect(profile.accessibilityProfile, equals('blind'));
      expect(profile.language, equals('fr'));
      expect(profile.ttsSpeed, equals(1.2));
      expect(profile.hapticEnabled, isTrue);
    });

    test('saveProfile updates existing profile', () async {
      // Create first
      await repo.saveProfile(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
        language: 'fr',
      );

      // Update via saveProfile (should update, not create)
      await repo.saveProfile(
        displayName: 'Marie Updated',
        language: 'en',
      );

      final profile = (await repo.getActiveProfile()).getOrNull();
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Marie Updated'));
      expect(profile.language, equals('en'));
      // accessibilityProfile should remain 'blind' (not overwritten)
      expect(profile.accessibilityProfile, equals('blind'));
    });

    test('updateProfile modifies profile by ID', () async {
      final idResult = await repo.saveProfile(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
      );
      final id = idResult.getOrNull()!;

      final updateResult = await repo.updateProfile(
        id,
        ttsSpeed: 1.5,
        ttsVoice: 'Amelie',
      );
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.getOrNull(), isTrue);

      final profile = (await repo.getActiveProfile()).getOrNull();
      expect(profile!.ttsSpeed, equals(1.5));
      expect(profile.ttsVoice, equals('Amelie'));
    });

    test('profile persists across simulated sessions', () async {
      // Session 1: Create profile
      await repo.saveProfile(
        displayName: 'Marie',
        accessibilityProfile: 'blind',
        language: 'fr',
        ttsSpeed: 1.2,
        hapticEnabled: true,
      );

      // Session 2: Read profile back (using same DB, simulating app restart)
      // Create a new repository instance to simulate restart
      final repo2 = PreferencesRepositoryImpl(
        profileDao: ProfileDao(db),
        vault: MemoryVaultImpl(
          episodeDao: EpisodeDao(db),
          preferenceDao: PreferenceDao(db),
          personDao: PersonDao(db),
          profileDao: ProfileDao(db),
          pluginDataDao: PluginDataDao(db),
          consentDao: ConsentDao(db),
        ),
        secureKeyVault: mockKeyVault,
      );

      final profile = (await repo2.getActiveProfile()).getOrNull();
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Marie'));
      expect(profile.accessibilityProfile, equals('blind'));
    });
  });

  group('PreferencesRepository — Preferences', () {
    test('getPreference returns null when not set', () async {
      final result = await repo.getPreference('theme');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('setPreference requires consent', () async {
      final result = await repo.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
      );
      expect(result.isFailure, isTrue);
    });

    test('setPreference succeeds with consent', () async {
      await grantConsentFor('semantic');

      final result = await repo.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
      );
      expect(result.isSuccess, isTrue);

      final value = (await repo.getPreference('theme')).getOrNull();
      expect(value, equals('dark'));
    });

    test('getAllPreferences returns stored preferences', () async {
      await grantConsentFor('semantic');

      await repo.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
      );
      await repo.setPreference(
        key: 'lang',
        value: 'fr',
        category: 'locale',
      );

      final prefs = (await repo.getAllPreferences()).getOrNull()!;
      expect(prefs, hasLength(2));
    });

    test('preferences persist across simulated sessions', () async {
      await grantConsentFor('semantic');

      await repo.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
      );

      // Session 2
      final repo2 = PreferencesRepositoryImpl(
        profileDao: ProfileDao(db),
        vault: MemoryVaultImpl(
          episodeDao: EpisodeDao(db),
          preferenceDao: PreferenceDao(db),
          personDao: PersonDao(db),
          profileDao: ProfileDao(db),
          pluginDataDao: PluginDataDao(db),
          consentDao: ConsentDao(db),
        ),
        secureKeyVault: mockKeyVault,
      );

      final value = (await repo2.getPreference('theme')).getOrNull();
      expect(value, equals('dark'));
    });
  });

  group('PreferencesRepository — Secure keys (API keys)', () {
    test('getApiKey returns null when not set', () async {
      final result = await repo.getApiKey('claude');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('setApiKey stores key securely', () async {
      final result = await repo.setApiKey('claude', 'sk-test-key-123');
      expect(result.isSuccess, isTrue);

      final key = (await repo.getApiKey('claude')).getOrNull();
      expect(key, equals('sk-test-key-123'));
    });

    test('hasApiKey returns true after storing', () async {
      await repo.setApiKey('claude', 'sk-test');

      final has = (await repo.hasApiKey('claude')).getOrNull()!;
      expect(has, isTrue);
    });

    test('hasApiKey returns false when not stored', () async {
      final has = (await repo.hasApiKey('openai')).getOrNull()!;
      expect(has, isFalse);
    });

    test('deleteApiKey removes the key', () async {
      await repo.setApiKey('claude', 'sk-test');
      await repo.deleteApiKey('claude');

      final key = (await repo.getApiKey('claude')).getOrNull();
      expect(key, isNull);
    });

    test('API keys are scoped by provider ID', () async {
      await repo.setApiKey('claude', 'sk-claude-123');
      await repo.setApiKey('openai', 'sk-openai-456');

      final claude = (await repo.getApiKey('claude')).getOrNull();
      final openai = (await repo.getApiKey('openai')).getOrNull();
      expect(claude, equals('sk-claude-123'));
      expect(openai, equals('sk-openai-456'));
    });

    test('secure storage failure propagates', () async {
      mockKeyVault.shouldFail = true;

      final result = await repo.getApiKey('claude');
      expect(result.isFailure, isTrue);
    });

    test('API keys persist across simulated sessions', () async {
      await repo.setApiKey('claude', 'sk-persistent-key');

      // Session 2 (same mockKeyVault simulates persistent secure storage)
      final repo2 = PreferencesRepositoryImpl(
        profileDao: ProfileDao(db),
        vault: MemoryVaultImpl(
          episodeDao: EpisodeDao(db),
          preferenceDao: PreferenceDao(db),
          personDao: PersonDao(db),
          profileDao: ProfileDao(db),
          pluginDataDao: PluginDataDao(db),
          consentDao: ConsentDao(db),
        ),
        secureKeyVault: mockKeyVault,
      );

      final key = (await repo2.getApiKey('claude')).getOrNull();
      expect(key, equals('sk-persistent-key'));
    });
  });
}
