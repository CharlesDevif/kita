/// Sealed class for typed error handling across the app.
/// All failures extend [KitaFailure] — never throw untyped exceptions.
///
/// Each failure provides:
/// - [userMessage]: safe for the user, passed to ProfileAdapter
/// - [logMessage]: technical, in English, zero PII
sealed class KitaFailure {
  const KitaFailure({
    required this.userMessage,
    required this.logMessage,
    this.cause,
    this.stackTrace,
  });

  /// Message safe pour l'utilisateur (passe au ProfileAdapter).
  final String userMessage;

  /// Message technique pour les logs internes — JAMAIS de PII.
  final String logMessage;

  /// Cause originale (exception, error).
  final Object? cause;

  /// Stack trace pour le debug.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $logMessage';
}

/// Network failures: timeout, DNS, connection errors.
final class NetworkFailure extends KitaFailure {
  const NetworkFailure({
    required super.userMessage,
    required super.logMessage,
    super.cause,
    super.stackTrace,
  });

  factory NetworkFailure.timeout({String? endpoint}) => NetworkFailure(
        userMessage: 'La connexion a expiré. Vérifiez votre réseau.',
        logMessage:
            'Network timeout${endpoint != null ? ' on $endpoint' : ''}',
      );

  factory NetworkFailure.noConnection() => const NetworkFailure(
        userMessage: 'Pas de connexion internet.',
        logMessage: 'No network connection available',
      );
}

/// AI provider failures: rate limit, API error, model unavailable.
final class AIProviderFailure extends KitaFailure {
  const AIProviderFailure({
    required super.userMessage,
    required super.logMessage,
    this.providerId,
    super.cause,
    super.stackTrace,
  });

  factory AIProviderFailure.rateLimited(String providerId) =>
      AIProviderFailure(
        userMessage: 'Le service IA est temporairement surchargé.',
        logMessage: 'Rate limited by provider $providerId',
        providerId: providerId,
      );

  factory AIProviderFailure.invalidApiKey(String providerId) =>
      AIProviderFailure(
        userMessage: 'La clé API est invalide. Vérifiez dans les réglages.',
        logMessage: 'Invalid API key for provider $providerId',
        providerId: providerId,
      );

  factory AIProviderFailure.modelUnavailable(
    String providerId,
    String model,
  ) =>
      AIProviderFailure(
        userMessage: 'Le modèle IA est indisponible.',
        logMessage: 'Model $model unavailable on provider $providerId',
        providerId: providerId,
      );

  final String? providerId;
}

/// Plugin failures: sandbox violation, timeout, crash.
final class PluginFailure extends KitaFailure {
  const PluginFailure({
    required super.userMessage,
    required super.logMessage,
    this.pluginId,
    super.cause,
    super.stackTrace,
  });

  factory PluginFailure.sandboxViolation(
    String pluginId,
    String permission,
  ) =>
      PluginFailure(
        userMessage: 'Le plugin a tenté un accès non autorisé.',
        logMessage: 'Sandbox violation: plugin $pluginId tried $permission',
        pluginId: pluginId,
      );

  factory PluginFailure.timeout(String pluginId) => PluginFailure(
        userMessage: "Le plugin n'a pas répondu à temps.",
        logMessage: 'Plugin $pluginId timed out',
        pluginId: pluginId,
      );

  final String? pluginId;
}

/// Storage failures: database, secure storage, file system.
final class StorageFailure extends KitaFailure {
  const StorageFailure({
    required super.userMessage,
    required super.logMessage,
    super.cause,
    super.stackTrace,
  });

  factory StorageFailure.databaseError(String operation) => StorageFailure(
        userMessage: 'Erreur de stockage interne.',
        logMessage: 'Database error during $operation',
      );

  factory StorageFailure.secureStorageError(String operation) =>
      StorageFailure(
        userMessage: "Erreur d'accès au stockage sécurisé.",
        logMessage: 'Secure storage error during $operation',
      );
}

/// Permission failures: camera, microphone, GPS, notification.
final class PermissionFailure extends KitaFailure {
  const PermissionFailure({
    required super.userMessage,
    required super.logMessage,
    this.permission,
    super.cause,
    super.stackTrace,
  });

  factory PermissionFailure.denied(String permission) => PermissionFailure(
        userMessage: 'Permission refusée. Activez-la dans les réglages.',
        logMessage: 'Permission denied: $permission',
        permission: permission,
      );

  factory PermissionFailure.permanentlyDenied(String permission) =>
      PermissionFailure(
        userMessage: 'Permission bloquée. Allez dans les réglages système.',
        logMessage: 'Permission permanently denied: $permission',
        permission: permission,
      );

  final String? permission;
}

/// Catch-all for unexpected errors.
final class UnexpectedFailure extends KitaFailure {
  const UnexpectedFailure({
    required super.logMessage,
    super.cause,
    super.stackTrace,
  }) : super(userMessage: 'Une erreur inattendue est survenue.');
}
