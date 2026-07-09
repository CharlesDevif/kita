import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../memory/domain/episode.dart';
import '../../memory/domain/memory_vault.dart';
import '../domain/memory_access.dart';

/// Maillon terminal entre les plugins et le coffre chiffré.
///
/// `SandboxedMemoryAccess` ne fait que déléguer ; sans cet adaptateur, la
/// chaîne n'aboutit nulle part et `context.memory` reste `null`.
class VaultMemoryAccess implements MemoryAccess {
  VaultMemoryAccess({required Future<MemoryVault> Function() vaultLoader})
      : _vaultLoader = vaultLoader;

  static final _log = KitaLogger('Plugin.MemoryAccess');

  final Future<MemoryVault> Function() _vaultLoader;
  MemoryVault? _vault;

  /// Résolution paresseuse : `pluginSandboxProvider` est synchrone alors que
  /// `memoryVaultProvider` est un `FutureProvider`. Charger ici évite de
  /// bloquer le démarrage de l'app.
  Future<MemoryVault?> _resolve() async {
    final cached = _vault;
    if (cached != null) return cached;
    try {
      final vault = await _vaultLoader();
      _vault = vault;
      return vault;
    } on Object catch (e, stack) {
      // KitaFailure n'est pas une Exception : `on Object` est obligatoire.
      _log.error('Memory vault unavailable', error: e, stackTrace: stack);
      return null;
    }
  }

  static const _unavailable = StorageFailure(
    userMessage: 'La mémoire est indisponible.',
    logMessage: 'Memory vault could not be loaded',
  );

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    return vault.saveEpisode(episode);
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    return vault.getPreference(key);
  }

  @override
  Future<Result<void>> setPreference(String key, String value) async {
    final vault = await _resolve();
    if (vault == null) return const Result.failure(_unavailable);
    // MemoryAccess ne transporte ni category ni source : valeurs par défaut
    // pour les écritures de plugin. Les faits utilisateur passent directement
    // par MemoryVault (voir user_facts.dart).
    return vault.setPreference(
      key: key,
      value: value,
      category: 'plugin_data',
      source: 'plugin',
    );
  }
}
