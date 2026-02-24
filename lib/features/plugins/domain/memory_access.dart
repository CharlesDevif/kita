import '../../../core/errors/result.dart';
import '../../memory/domain/episode.dart';

abstract interface class MemoryAccess {
  Future<Result<void>> saveEpisode(KitaEpisode episode);
  Future<Result<String?>> getPreference(String key);
  Future<Result<void>> setPreference(String key, String value);
}
