import '../../../core/errors/result.dart';
import 'consent_entry.dart';
import 'episode.dart';
import 'forget_request.dart';
import 'memory_domain.dart';
import 'person.dart';
import 'preference.dart';

abstract interface class MemoryVault {
  // --- Episodic domain ---
  Future<Result<void>> saveEpisode(KitaEpisode episode);
  Future<Result<List<KitaEpisode>>> getEpisodes();

  // --- Semantic domain ---
  Future<Result<String?>> getPreference(String key);
  Future<Result<void>> setPreference({
    required String key,
    required String value,
    required String category,
    required String source,
  });
  Future<Result<List<KitaPreference>>> getPreferences();

  // --- Relational domain ---
  Future<Result<void>> savePerson(KitaPerson person);
  Future<Result<List<KitaPerson>>> getPersons();

  // --- Consent management ---
  Future<Result<List<ConsentEntry>>> getConsents();
  Future<Result<void>> grantConsent(ConsentEntry entry);
  Future<Result<void>> revokeConsent(int consentId);
  Future<Result<bool>> hasConsent({
    required String consentType,
    required String scope,
  });

  // --- Transparency & Forget ---
  Future<Result<Map<MemoryDomain, List<String>>>> whatDoYouKnow();
  Future<Result<void>> forget(ForgetRequest request);

  /// Verifies that forget() was effective by checking for residual data.
  /// Returns true if the targeted scope is empty (0 data recoverable).
  Future<Result<bool>> auditForget(ForgetRequest request);
}
