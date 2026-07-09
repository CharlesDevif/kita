import '../../../core/utils/logger.dart';
import '../domain/consent_entry.dart';
import '../domain/memory_vault.dart';
import '../domain/secure_key_vault.dart';

/// Type de consentement exigé par `MemoryVaultImpl._withConsentLock`.
const String consentTypeDataStorage = 'data_storage';

/// Scopes verrouillés : `saveEpisode` exige `episodic`, `setPreference` exige
/// `semantic`.
const List<String> memoryConsentScopes = ['episodic', 'semantic'];

/// Clé de l'opt-out utilisateur. Stockée hors du domaine sémantique : celui-ci
/// exige justement le consentement, ce qui créerait un interblocage.
const String memoryConsentOptOutKey = 'memory_consent_opt_out';

/// Le coffre refuse toute écriture sans consentement `data_storage`. Personne
/// ne le demandait : la mémoire était morte pour cette raison autant que par le
/// `memoryAccess` manquant.
class MemoryConsent {
  MemoryConsent._();

  static final _log = KitaLogger('Memory.Consent');

  static Future<bool> _optedOut(SecureKeyVault? keyVault) async {
    if (keyVault == null) return false;
    final value = (await keyVault.read(memoryConsentOptOutKey)).getOrNull();
    return value == 'true';
  }

  /// Accorde le consentement pour les deux scopes, sauf opt-out explicite.
  ///
  /// Idempotent : `grantConsent` insère une ligne par appel, donc on vérifie
  /// `hasConsent` d'abord. Appelé au démarrage **et** après `forget(everything)`,
  /// qui supprime toutes les lignes de consentement.
  static Future<void> ensureGranted(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
    DateTime Function()? now,
  }) async {
    if (await _optedOut(keyVault)) {
      _log.info('Memory consent opted out by user, not granting');
      return;
    }
    final timestamp = (now ?? DateTime.now)();
    for (final scope in memoryConsentScopes) {
      final already = (await vault.hasConsent(
        consentType: consentTypeDataStorage,
        scope: scope,
      )).getOrElse((_) => false);
      if (already) continue;

      final result = await vault.grantConsent(ConsentEntry(
        id: 0,
        consentType: consentTypeDataStorage,
        scope: scope,
        granted: true,
        grantedAt: timestamp,
      ));
      if (result.isFailure) {
        _log.warning('Could not grant memory consent for scope $scope');
      }
    }
    _log.info('Memory consent ensured');
  }

  /// `true` si les deux scopes verrouillés (`episodic`, `semantic`) sont
  /// actuellement consentis.
  static Future<bool> isGranted(MemoryVault vault) async {
    for (final scope in memoryConsentScopes) {
      final granted = (await vault.hasConsent(
        consentType: consentTypeDataStorage,
        scope: scope,
      )).getOrElse((_) => false);
      if (!granted) return false;
    }
    return true;
  }

  /// Révoque les deux scopes et mémorise l'opt-out, pour que le bootstrap du
  /// prochain démarrage ne ré-accorde pas dans le dos de l'utilisateur.
  static Future<void> revokeAll(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    final consents = (await vault.getConsents()).getOrNull() ?? const [];
    for (final entry in consents.where(
      (c) => c.granted && c.consentType == consentTypeDataStorage,
    )) {
      await vault.revokeConsent(entry.id);
    }
    await keyVault?.write(memoryConsentOptOutKey, 'true');
    _log.info('Memory consent revoked');
  }

  /// Ré-autorise après un opt-out.
  static Future<void> grantAgain(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    await keyVault?.delete(memoryConsentOptOutKey);
    await ensureGranted(vault, keyVault: keyVault);
  }
}
