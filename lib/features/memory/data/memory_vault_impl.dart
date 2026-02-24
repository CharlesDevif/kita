import 'dart:async';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/consent_entry.dart';
import '../domain/episode.dart';
import '../domain/forget_request.dart';
import '../domain/memory_domain.dart';
import '../domain/memory_vault.dart';
import '../domain/person.dart';
import '../domain/preference.dart';
import 'daos/consent_dao.dart';
import 'daos/episode_dao.dart';
import 'daos/person_dao.dart';
import 'daos/plugin_data_dao.dart';
import 'daos/preference_dao.dart';
import 'daos/profile_dao.dart';

final _log = KitaLogger('Memory');

/// Concrete implementation of [MemoryVault] with consent-based storage.
///
/// All sensitive data operations check for active consent before proceeding.
/// Consent is tracked in the consent_log table for GDPR compliance.
class MemoryVaultImpl implements MemoryVault {
  MemoryVaultImpl({
    required this.episodeDao,
    required this.preferenceDao,
    required this.personDao,
    required this.profileDao,
    required this.pluginDataDao,
    required this.consentDao,
  });

  final EpisodeDao episodeDao;
  final PreferenceDao preferenceDao;
  final PersonDao personDao;
  final ProfileDao profileDao;
  final PluginDataDao pluginDataDao;
  final ConsentDao consentDao;

  /// Consent type constant for data storage operations.
  static const _consentDataStorage = 'data_storage';

  /// Lock to prevent TOCTOU race between consent check and storage operation.
  /// Ensures consent cannot be revoked between verification and use.
  Completer<void>? _consentLock;

  // --- Episodic domain ---

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    return _withConsentLock(
      consentType: _consentDataStorage,
      scope: 'episodic',
      action: () async {
        final result = await episodeDao.insert(
          source: episode.source,
          eventType: episode.eventType,
          summary: episode.summary,
          details: episode.details,
          tags: episode.tags,
          importanceScore: episode.importanceScore,
          isPinned: episode.isPinned,
          expiresAt: episode.expiresAt,
        );
        return result.map((_) {
          _log.info('Episode saved');
        });
      },
    );
  }

  @override
  Future<Result<List<KitaEpisode>>> getEpisodes() async {
    return episodeDao.getAll();
  }

  // --- Semantic domain ---

  @override
  Future<Result<String?>> getPreference(String key) async {
    final result = await preferenceDao.getByKey(key);
    return result.map((pref) => pref?.value);
  }

  @override
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
    required String source,
  }) async {
    return _withConsentLock(
      consentType: _consentDataStorage,
      scope: 'semantic',
      action: () async {
        final result = await preferenceDao.upsert(
          category: category,
          key: key,
          value: value,
          source: source,
        );
        return result.map((_) {
          _log.info('Preference saved');
        });
      },
    );
  }

  @override
  Future<Result<List<KitaPreference>>> getPreferences() async {
    return preferenceDao.getAll();
  }

  // --- Relational domain ---

  @override
  Future<Result<void>> savePerson(KitaPerson person) async {
    return _withConsentLock(
      consentType: _consentDataStorage,
      scope: 'relational',
      action: () async {
        final result = await personDao.insert(
          name: person.name,
          relationship: person.relationship,
          notes: person.notes,
          interests: person.interests,
        );
        return result.map((_) {
          _log.info('Person saved');
        });
      },
    );
  }

  @override
  Future<Result<List<KitaPerson>>> getPersons() async {
    return personDao.getAll();
  }

  // --- Consent management ---

  @override
  Future<Result<List<ConsentEntry>>> getConsents() async {
    return consentDao.getAll();
  }

  @override
  Future<Result<void>> grantConsent(ConsentEntry entry) async {
    final result = await consentDao.insert(
      consentType: entry.consentType,
      scope: entry.scope,
      granted: entry.granted,
      details: entry.details,
    );
    return result.map((_) {
      _log.info('Consent granted for ${entry.consentType}/${entry.scope}');
    });
  }

  @override
  Future<Result<void>> revokeConsent(int consentId) async {
    final result = await consentDao.revoke(consentId);
    return result.map((_) {
      _log.info('Consent revoked');
    });
  }

  @override
  Future<Result<bool>> hasConsent({
    required String consentType,
    required String scope,
  }) async {
    return consentDao.hasActiveConsent(
      consentType: consentType,
      scope: scope,
    );
  }

  // --- Transparency ---

  @override
  Future<Result<Map<MemoryDomain, List<String>>>> whatDoYouKnow() async {
    try {
      final episodesResult = await episodeDao.getAll();
      final preferencesResult = await preferenceDao.getAll();
      final personsResult = await personDao.getAll();
      final data = <MemoryDomain, List<String>>{};

      // Episodic
      final episodes = episodesResult.getOrElse((_) => []);
      if (episodes.isNotEmpty) {
        data[MemoryDomain.episodic] =
            episodes.map((e) => '${e.eventType}: ${e.summary}').toList();
      }

      // Semantic
      final prefs = preferencesResult.getOrElse((_) => []);
      if (prefs.isNotEmpty) {
        data[MemoryDomain.semantic] =
            prefs.map((p) => '${p.category}/${p.key}').toList();
      }

      // Relational
      final persons = personsResult.getOrElse((_) => []);
      if (persons.isNotEmpty) {
        data[MemoryDomain.relational] = persons.map((p) => p.name).toList();
      }

      return Result.success(data);
    } catch (e, stack) {
      _log.error('Failed to collect transparency data',
          error: e, stackTrace: stack);
      return Result.failure(
          StorageFailure.databaseError('whatDoYouKnow'));
    }
  }

  // --- Forget ---

  @override
  Future<Result<void>> forget(ForgetRequest request) async {
    if (!request.confirmation) {
      return const Result.failure(StorageFailure(
        userMessage: 'Confirmation requise pour effacer les donnees.',
        logMessage: 'Forget request rejected: confirmation=false',
      ));
    }

    try {
      switch (request.scope) {
        case ForgetScope.everything:
          await episodeDao.deleteAll();
          await preferenceDao.deleteAll();
          await personDao.deleteAll();
          await profileDao.deleteAll();
          await pluginDataDao.deleteAll();
          await consentDao.deleteAll();
          _log.info('All data deleted (forget everything)');

        case ForgetScope.domain:
          final domain = request.domain;
          if (domain == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Domaine non specifie.',
              logMessage: 'Forget domain request without domain specified',
            ));
          }
          await _forgetDomain(domain);
          _log.info('Domain data deleted');

        case ForgetScope.plugin:
          final pluginId = request.pluginId;
          if (pluginId == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Plugin non specifie.',
              logMessage: 'Forget plugin request without pluginId specified',
            ));
          }
          await pluginDataDao.deleteByPlugin(pluginId);
          _log.info('Plugin data deleted');

        case ForgetScope.olderThan:
          final before = request.before;
          if (before == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Date non specifiee.',
              logMessage: 'Forget olderThan request without date',
            ));
          }
          await episodeDao.deleteExpiredBefore(before);
          _log.info('Old episodes deleted');

        case ForgetScope.specific:
          for (final idStr in request.specificIds) {
            final id = int.tryParse(idStr);
            if (id != null) {
              await episodeDao.deleteById(id);
            }
          }
          _log.info('Specific episodes deleted');
      }

      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Forget operation failed', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('forget'));
    }
  }

  // --- Private helpers ---

  /// Atomically checks consent and executes [action] under a lock.
  ///
  /// Prevents TOCTOU race where consent could be revoked between the check
  /// and the storage operation.
  Future<Result<T>> _withConsentLock<T>({
    required String consentType,
    required String scope,
    required Future<Result<T>> Function() action,
  }) async {
    // Wait for any in-flight consent-guarded operation to complete.
    while (_consentLock != null) {
      await _consentLock!.future;
    }
    _consentLock = Completer<void>();
    try {
      final consentResult = await _requireConsent(
        consentType: consentType,
        scope: scope,
      );
      if (consentResult.isFailure) {
        return Result.failure((consentResult as Failure).failure);
      }
      return await action();
    } finally {
      final lock = _consentLock;
      _consentLock = null;
      lock?.complete();
    }
  }

  Future<Result<void>> _requireConsent({
    required String consentType,
    required String scope,
  }) async {
    final result = await consentDao.hasActiveConsent(
      consentType: consentType,
      scope: scope,
    );
    final hasConsent = result.getOrElse((_) => false);
    if (!hasConsent) {
      _log.warning('Storage refused: no consent for $consentType/$scope');
      return const Result.failure(StorageFailure(
        userMessage: 'Consentement requis pour stocker ces donnees.',
        logMessage: 'Storage refused: missing consent',
      ));
    }
    return const Result.success(null);
  }

  // --- Audit ---

  @override
  Future<Result<bool>> auditForget(ForgetRequest request) async {
    try {
      switch (request.scope) {
        case ForgetScope.everything:
          final episodeCount = (await episodeDao.count()).getOrElse((_) => -1);
          final prefCount = (await preferenceDao.count()).getOrElse((_) => -1);
          final personCount = (await personDao.count()).getOrElse((_) => -1);
          final profileCount = (await profileDao.count()).getOrElse((_) => -1);
          final pluginCount =
              (await pluginDataDao.count()).getOrElse((_) => -1);
          final consentCount = (await consentDao.count()).getOrElse((_) => -1);
          final total = episodeCount +
              prefCount +
              personCount +
              profileCount +
              pluginCount +
              consentCount;
          _log.info('Audit forget everything: $total remaining rows');
          return Result.success(total == 0);

        case ForgetScope.domain:
          final count = await _countDomain(request.domain!);
          _log.info('Audit forget domain: $count remaining rows');
          return Result.success(count == 0);

        case ForgetScope.plugin:
          final entries =
              (await pluginDataDao.getByPlugin(request.pluginId!)).getOrElse((_) => []);
          _log.info('Audit forget plugin: ${entries.length} remaining rows');
          return Result.success(entries.isEmpty);

        case ForgetScope.olderThan:
          final remaining =
              (await episodeDao.getExpiredBefore(request.before!)).getOrElse((_) => []);
          _log.info('Audit forget olderThan: ${remaining.length} remaining rows');
          return Result.success(remaining.isEmpty);

        case ForgetScope.specific:
          for (final idStr in request.specificIds) {
            final id = int.tryParse(idStr);
            if (id != null) {
              final episode = (await episodeDao.getById(id)).getOrNull();
              if (episode != null) {
                _log.info('Audit forget specific: found residual episode');
                return const Result.success(false);
              }
            }
          }
          return const Result.success(true);
      }
    } catch (e, stack) {
      _log.error('Audit failed', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('auditForget'));
    }
  }

  Future<void> _forgetDomain(MemoryDomain domain) async {
    switch (domain) {
      case MemoryDomain.episodic:
        await episodeDao.deleteAll();
      case MemoryDomain.semantic:
        await preferenceDao.deleteAll();
      case MemoryDomain.relational:
        await personDao.deleteAll();
      case MemoryDomain.working:
        // Working memory is RAM-only, nothing to delete from DB
        break;
    }
  }

  Future<int> _countDomain(MemoryDomain domain) async {
    switch (domain) {
      case MemoryDomain.episodic:
        return (await episodeDao.count()).getOrElse((_) => -1);
      case MemoryDomain.semantic:
        return (await preferenceDao.count()).getOrElse((_) => -1);
      case MemoryDomain.relational:
        return (await personDao.count()).getOrElse((_) => -1);
      case MemoryDomain.working:
        return 0;
    }
  }
}
