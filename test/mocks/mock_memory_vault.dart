import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/consent_entry.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';

class MockMemoryVault implements MemoryVault {
  bool shouldFail = false;
  final List<Episode> savedEpisodes = [];
  final Map<String, String> preferences = {};
  final List<ConsentEntry> consents = [];

  @override
  Future<Result<void>> forget(ForgetRequest request) async {
    if (shouldFail) {
      return Result.failure(
        StorageFailure.databaseError('forget'),
      );
    }
    savedEpisodes.clear();
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
  Future<Result<void>> saveEpisode(Episode episode) async {
    if (shouldFail) {
      return Result.failure(
        StorageFailure.databaseError('saveEpisode'),
      );
    }
    savedEpisodes.add(episode);
    return const Result.success(null);
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    return Result.success(preferences[key]);
  }

  @override
  Future<Result<void>> setPreference(String key, String value) async {
    preferences[key] = value;
    return const Result.success(null);
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
  Future<Result<void>> revokeConsent(String consentId) async {
    consents.removeWhere((c) => c.id == consentId);
    return const Result.success(null);
  }
}
