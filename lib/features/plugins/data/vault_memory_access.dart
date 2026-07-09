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

  /// Future en vol mémoïsé : évite d'appeler [_vaultLoader] plusieurs fois
  /// si des appels concurrents arrivent avant la première résolution.
  /// Remis à `null` une fois résolu (succès -> [_vault] sert de cache ;
  /// échec -> aucun cache, le prochain appel retente).
  Future<MemoryVault>? _pending;

  /// Résolution paresseuse : `pluginSandboxProvider` est synchrone alors que
  /// `memoryVaultProvider` est un `FutureProvider`. Charger ici évite de
  /// bloquer le démarrage de l'app.
  ///
  /// Chargé au plus une fois : le [Future] retourné par [_vaultLoader] est
  /// lui-même mémoïsé dans [_pending] pendant qu'il est en vol, donc des
  /// appels concurrents avant la première résolution partagent le même
  /// chargement au lieu d'en déclencher un par appel. Cette garantie ne
  /// dépend plus d'un détail externe (mémoïsation du provider) : elle tient
  /// même si [_vaultLoader] est appelé plusieurs fois par des callers
  /// différents.
  Future<MemoryVault?> _resolve() async {
    final cached = _vault;
    if (cached != null) return cached;
    try {
      _pending ??= _vaultLoader();
      final vault = await _pending!;
      _vault = vault;
      _pending = null;
      return vault;
    } on Object catch (e, stack) {
      // KitaFailure n'est pas une Exception : `on Object` est obligatoire.
      _pending = null;
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
