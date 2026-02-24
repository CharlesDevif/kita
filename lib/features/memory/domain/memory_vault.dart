import '../../../core/errors/result.dart';
import 'consent_entry.dart';
import 'episode.dart';
import 'forget_request.dart';
import 'memory_domain.dart';

abstract interface class MemoryVault {
  Future<Result<void>> forget(ForgetRequest request);
  Future<Result<Map<MemoryDomain, List<String>>>> whatDoYouKnow();
  Future<Result<void>> saveEpisode(Episode episode);
  Future<Result<String?>> getPreference(String key);
  Future<Result<void>> setPreference(String key, String value);
  Future<Result<List<ConsentEntry>>> getConsents();
  Future<Result<void>> grantConsent(ConsentEntry entry);
  Future<Result<void>> revokeConsent(String consentId);
}
