import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/consent_entry.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/memory/domain/person.dart';
import 'package:kita/features/memory/domain/preference.dart';

class MockMemoryVault implements MemoryVault {
  bool shouldFail = false;
  final List<KitaEpisode> savedEpisodes = [];
  final Map<String, String> preferences = {};
  final List<ConsentEntry> consents = [];
  final List<KitaPerson> persons = [];

  @override
  Future<Result<void>> forget(ForgetRequest request) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.databaseError('forget'));
    }
    savedEpisodes.clear();
    preferences.clear();
    persons.clear();
    return const Result.success(null);
  }

  @override
  Future<Result<Map<MemoryDomain, List<String>>>> whatDoYouKnow() async {
    return const Result.success({
      MemoryDomain.episodic: ['Scene at park', 'Meeting with Sophie'],
      MemoryDomain.semantic: ['Prefers dark mode'],
    });
  }

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    if (shouldFail) {
      return Result.failure(StorageFailure.databaseError('saveEpisode'));
    }
    savedEpisodes.add(episode);
    return const Result.success(null);
  }

  @override
  Future<Result<List<KitaEpisode>>> getEpisodes() async {
    return Result.success(List.unmodifiable(savedEpisodes));
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    return Result.success(preferences[key]);
  }

  @override
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
    required String source,
  }) async {
    preferences[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<List<KitaPreference>>> getPreferences() async {
    return const Result.success([]);
  }

  @override
  Future<Result<void>> savePerson(KitaPerson person) async {
    persons.add(person);
    return const Result.success(null);
  }

  @override
  Future<Result<List<KitaPerson>>> getPersons() async {
    return Result.success(List.unmodifiable(persons));
  }

  @override
  Future<Result<List<ConsentEntry>>> getConsents() async {
    return Result.success(List.unmodifiable(consents));
  }

  @override
  Future<Result<void>> grantConsent(ConsentEntry entry) async {
    consents.add(entry);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> revokeConsent(int consentId) async {
    consents.removeWhere((c) => c.id == consentId);
    return const Result.success(null);
  }

  @override
  Future<Result<bool>> hasConsent({
    required String consentType,
    required String scope,
  }) async {
    return Result.success(
      consents.any((c) =>
          c.consentType == consentType &&
          c.scope == scope &&
          c.granted &&
          c.revokedAt == null),
    );
  }

  @override
  Future<Result<bool>> auditForget(ForgetRequest request) async {
    return Result.success(
      savedEpisodes.isEmpty && preferences.isEmpty && persons.isEmpty,
    );
  }
}
