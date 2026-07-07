import 'dart:async';

import '../../../core/data/database.dart' as db;
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
    this.database,
    this.onPurgeExternal,
  });

  final EpisodeDao episodeDao;
  final PreferenceDao preferenceDao;
  final PersonDao personDao;
  final ProfileDao profileDao;
  final PluginDataDao pluginDataDao;
  final ConsentDao consentDao;

  /// Shared Drift database, used to run [forget] deletes in a single atomic
  /// transaction. When null, deletes run sequentially (still correct, but not
  /// atomic).
  final db.KitaDatabase? database;

  /// Optional hook invoked by `forget(everything)` after the local tables are
  /// cleared, to purge data owned by other features that this feature must not
  /// depend on directly — namely the AI `request_cache` table (plaintext
  /// prompts/responses) and the secure key vault (API keys). Wiring is provided
  /// by DI to avoid a memory->ai or memory->secure-storage dependency.
  final Future<void> Function()? onPurgeExternal;

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
    // Acquire the same lock as storage operations so a revoke cannot race with
    // an in-flight consent-guarded write (TOCTOU).
    return _withLock(() async {
      final entryResult = await consentDao.getById(consentId);
      if (entryResult case Failure<ConsentEntry?>(:final failure)) {
        return Result.failure(failure);
      }
      final entry = entryResult.getOrNull();
      if (entry == null) {
        _log.warning('Revoke consent: no consent found for the given id');
        return const Result.failure(StorageFailure(
          userMessage: 'Ce consentement est introuvable.',
          logMessage: 'Revoke consent: id not found',
        ));
      }
      // grantConsent inserts a new row per grant, so revoke ALL active rows for
      // this (type, scope) — otherwise a multi-granted consent stays active.
      final result = await consentDao.revokeAllActive(
        consentType: entry.consentType,
        scope: entry.scope,
      );
      return result.map((_) {
        _log.info('Consent revoked for ${entry.consentType}/${entry.scope}');
      });
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
        userMessage: 'Confirmation requise pour effacer les données.',
        logMessage: 'Forget request rejected: confirmation=false',
      ));
    }

    try {
      switch (request.scope) {
        case ForgetScope.everything:
          final localDb = database;
          if (localDb != null) {
            await localDb.transaction(_deleteEverything);
          } else {
            await _deleteEverything();
          }
          // Purge data owned by other features (AI request_cache, secure keys)
          // via the injected hook. Runs after the local commit; a failure here
          // makes forget report failure so the caller knows the purge was
          // incomplete.
          final purge = onPurgeExternal;
          if (purge != null) {
            await purge();
          }
          _log.info('All data deleted (forget everything)');

        case ForgetScope.domain:
          final domain = request.domain;
          if (domain == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Domaine non spécifié.',
              logMessage: 'Forget domain request without domain specified',
            ));
          }
          await _forgetDomain(domain);
          _log.info('Domain data deleted');

        case ForgetScope.plugin:
          final pluginId = request.pluginId;
          if (pluginId == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Plugin non spécifié.',
              logMessage: 'Forget plugin request without pluginId specified',
            ));
          }
          await pluginDataDao.deleteByPlugin(pluginId);
          _log.info('Plugin data deleted');

        case ForgetScope.olderThan:
          final before = request.before;
          if (before == null) {
            return const Result.failure(StorageFailure(
              userMessage: 'Date non spécifiée.',
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
    } on _ForgetAborted catch (aborted) {
      // A delete inside the transaction failed; the transaction was rolled
      // back so no partial deletion happened. Surface the typed failure.
      _log.error('Forget rolled back: ${aborted.failure.logMessage}');
      return Result.failure(aborted.failure);
    } catch (e, stack) {
      _log.error('Forget operation failed', error: e, stackTrace: stack);
      return Result.failure(StorageFailure.databaseError('forget'));
    }
  }

  /// Clears every persisted table. Any DAO failure throws [_ForgetAborted] so
  /// that, when run inside a transaction, the whole delete is rolled back
  /// (DAOs swallow their own exceptions, so a thrown marker is required to
  /// trigger the rollback).
  Future<void> _deleteEverything() async {
    final results = <Result<int>>[
      await episodeDao.deleteAll(),
      await preferenceDao.deleteAll(),
      await personDao.deleteAll(),
      await profileDao.deleteAll(),
      await pluginDataDao.deleteAll(),
      await consentDao.deleteAll(),
    ];
    for (final result in results) {
      if (result case Failure<int>(:final failure)) {
        throw _ForgetAborted(failure);
      }
    }
  }

  // --- Private helpers ---

  /// Serializes [action] against every other consent-guarded operation.
  ///
  /// Both storage (check-then-write) and [revokeConsent] acquire this lock so
  /// a revoke cannot interleave with an in-flight write (TOCTOU).
  Future<Result<T>> _withLock<T>(Future<Result<T>> Function() action) async {
    // Wait for any in-flight consent-guarded operation to complete.
    while (_consentLock != null) {
      await _consentLock!.future;
    }
    _consentLock = Completer<void>();
    try {
      return await action();
    } finally {
      final lock = _consentLock;
      _consentLock = null;
      lock?.complete();
    }
  }

  /// Atomically checks consent and executes [action] under the shared lock.
  ///
  /// Prevents TOCTOU race where consent could be revoked between the check
  /// and the storage operation.
  Future<Result<T>> _withConsentLock<T>({
    required String consentType,
    required String scope,
    required Future<Result<T>> Function() action,
  }) async {
    return _withLock(() async {
      final consentResult = await _requireConsent(
        consentType: consentType,
        scope: scope,
      );
      if (consentResult.isFailure) {
        return Result.failure((consentResult as Failure).failure);
      }
      return await action();
    });
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
        userMessage: 'Consentement requis pour stocker ces données.',
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
          final counts = <Result<int>>[
            await episodeDao.count(),
            await preferenceDao.count(),
            await personDao.count(),
            await profileDao.count(),
            await pluginDataDao.count(),
            await consentDao.count(),
          ];
          var total = 0;
          for (final count in counts) {
            // A failed count must never be compensated by another table's
            // count: fail the audit instead of silently reporting success.
            if (count case Failure<int>(:final failure)) {
              _log.warning('Audit forget everything: a table count failed');
              return Result.failure(failure);
            }
            total += count.getOrElse((_) => 0);
          }
          _log.info('Audit forget everything: $total remaining rows');
          return Result.success(total == 0);

        case ForgetScope.domain:
          final countResult = await _countDomain(request.domain!);
          if (countResult case Failure<int>(:final failure)) {
            _log.warning('Audit forget domain: count failed');
            return Result.failure(failure);
          }
          final count = countResult.getOrElse((_) => 0);
          _log.info('Audit forget domain: $count remaining rows');
          return Result.success(count == 0);

        case ForgetScope.plugin:
          // A failed residual query must fail the audit, never claim success.
          final entriesResult =
              await pluginDataDao.getByPlugin(request.pluginId!);
          if (entriesResult.isFailure) {
            _log.warning('Audit forget plugin: residual query failed');
            return Result.failure((entriesResult as Failure).failure);
          }
          final entries = entriesResult.getOrNull()!;
          _log.info('Audit forget plugin: ${entries.length} remaining rows');
          return Result.success(entries.isEmpty);

        case ForgetScope.olderThan:
          final remainingResult =
              await episodeDao.getExpiredBefore(request.before!);
          if (remainingResult.isFailure) {
            _log.warning('Audit forget olderThan: residual query failed');
            return Result.failure((remainingResult as Failure).failure);
          }
          final remaining = remainingResult.getOrNull()!;
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

  Future<Result<int>> _countDomain(MemoryDomain domain) async {
    switch (domain) {
      case MemoryDomain.episodic:
        return episodeDao.count();
      case MemoryDomain.semantic:
        return preferenceDao.count();
      case MemoryDomain.relational:
        return personDao.count();
      case MemoryDomain.working:
        // Working memory is RAM-only; there is nothing persisted to count.
        return const Result.success(0);
    }
  }
}

/// Internal marker thrown to abort (and roll back) a `forget(everything)`
/// transaction when a DAO delete reports a failure. Carries the typed failure
/// so it can be surfaced to the caller.
class _ForgetAborted implements Exception {
  const _ForgetAborted(this.failure);

  final KitaFailure failure;
}
