import 'dart:async';

import '../../../core/errors/result.dart';
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

  /// `true` si on ne doit PAS accorder le consentement.
  ///
  /// Fail-closed délibéré : une lecture du coffre sécurisé qui échoue (erreur
  /// Keystore/Keychain, panne transitoire...) est traitée comme un opt-out,
  /// **jamais** comme "jamais choisi". La règle inviolable est de ne jamais
  /// ré-accorder contre un refus explicite ; si on ne peut plus lire ce refus,
  /// le choix le plus sûr est de continuer à le respecter plutôt que de
  /// prendre le silence pour un feu vert. Ce fail-closed ne peut pas bloquer
  /// le tout premier lancement : une clé absente (pas encore de choix fait)
  /// reste un `Success(null)`, qui accorde normalement. Seule une vraie
  /// erreur de stockage suspend l'accord, et le prochain lancement qui
  /// parvient à lire le coffre le rétablit.
  static Future<bool> _optedOut(SecureKeyVault? keyVault) async {
    if (keyVault == null) return false;
    final result = await keyVault.read(memoryConsentOptOutKey);
    if (result.isFailure) {
      _log.warning('Could not read memory consent opt-out key, treating as opted out');
      return true;
    }
    return result.getOrNull() == 'true';
  }

  /// Verrou statique sérialisant les appels concurrents à [ensureGranted].
  ///
  /// `hasConsent` puis `grantConsent` ne sont pas atomiques : sans ce verrou,
  /// deux appels concurrents (ex. bootstrap au démarrage + ré-accord après
  /// `forget(everything)`) pourraient chacun constater "pas encore consenti"
  /// avant que l'autre n'ait inséré sa ligne, doublant les lignes de
  /// consentement pour le même scope.
  ///
  /// Modélisé sur `MemoryVaultImpl._withLock` : le verrou est remis à `null`
  /// dès qu'il est relâché, plutôt que de garder indéfiniment une référence
  /// vers un `Future` déjà résolu. Une chaîne `Future.then` statique qui
  /// persiste au-delà de son propre appel ne se propage plus une fois
  /// observée depuis un autre contexte d'exécution (constaté en test
  /// widget : deux `testWidgets` qui se suivent tournent dans des zones
  /// distinctes, et rattacher un `.then()` à un `Future` déjà réglé créé
  /// dans la zone précédente ne relance jamais son callback — la seconde
  /// exécution reste bloquée indéfiniment). Remettre le verrou à `null` une
  /// fois libéré évite de jamais retenir un `Future` d'un appel précédent.
  static Completer<void>? _ensureGrantedLock;

  /// Accorde le consentement pour les deux scopes, sauf opt-out explicite.
  ///
  /// Idempotent : `grantConsent` insère une ligne par appel, donc on vérifie
  /// `hasConsent` d'abord. Appelé au démarrage **et** après `forget(everything)`,
  /// qui supprime toutes les lignes de consentement. Sérialisé via
  /// [_ensureGrantedLock] pour éviter les doublons en cas d'appels concurrents.
  static Future<void> ensureGranted(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
    DateTime Function()? now,
  }) async {
    // Attend la fin de tout appel en cours avant de démarrer le sien.
    while (_ensureGrantedLock != null) {
      await _ensureGrantedLock!.future;
    }
    final myLock = Completer<void>();
    _ensureGrantedLock = myLock;
    try {
      await _ensureGrantedLocked(vault, keyVault: keyVault, now: now);
    } finally {
      _ensureGrantedLock = null;
      myLock.complete();
    }
  }

  static Future<void> _ensureGrantedLocked(
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
  ///
  /// L'opt-out est persisté **avant** toute révocation, et la révocation
  /// n'a lieu que si cette écriture réussit. Un interrupteur qui refuse de
  /// bouger (échec renvoyé à l'appelant, rien de révoqué) vaut mieux qu'un
  /// interrupteur qui ment : révoquer d'abord et perdre l'écriture de
  /// l'opt-out ferait ré-accorder le consentement au prochain bootstrap,
  /// contre le refus explicite de l'utilisateur.
  static Future<Result<void>> revokeAll(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    if (keyVault != null) {
      final writeResult = await keyVault.write(memoryConsentOptOutKey, 'true');
      if (writeResult.isFailure) {
        _log.warning('Could not persist memory consent opt-out, revocation aborted');
        return writeResult;
      }
    }

    final consents = (await vault.getConsents()).getOrNull() ?? const [];
    for (final entry in consents.where(
      (c) => c.granted && c.consentType == consentTypeDataStorage,
    )) {
      final result = await vault.revokeConsent(entry.id);
      if (result.isFailure) {
        _log.warning('Could not revoke a memory consent entry');
      }
    }
    _log.info('Memory consent revoked');
    return const Result.success(null);
  }

  /// Ré-autorise après un opt-out.
  ///
  /// La suppression de la clé d'opt-out est vérifiée avant de ré-accorder :
  /// si elle échoue, la clé d'opt-out reste potentiellement en place et on
  /// ne tente pas d'accorder par-dessus un état incertain.
  static Future<Result<void>> grantAgain(
    MemoryVault vault, {
    SecureKeyVault? keyVault,
  }) async {
    if (keyVault != null) {
      final deleteResult = await keyVault.delete(memoryConsentOptOutKey);
      if (deleteResult.isFailure) {
        _log.warning('Could not clear memory consent opt-out key, not granting again');
        return deleteResult;
      }
    }
    await ensureGranted(vault, keyVault: keyVault);
    return const Result.success(null);
  }
}
