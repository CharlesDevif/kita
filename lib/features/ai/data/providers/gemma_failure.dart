import '../../../../core/errors/kita_failure.dart';

/// Maps ANY thrown object (Exception or Error, e.g. [StateError]) coming out
/// of the native Gemma layer into a typed [AIProviderFailure].
///
/// Native/plugin code can throw `Error` subtypes that would otherwise slip
/// through `catch (Exception)` clauses. Always route Gemma failures here so a
/// user (Marie, blind) hears an honest spoken message instead of a raw crash.
AIProviderFailure gemmaFailure(
  Object error, {
  String? userMessage,
  StackTrace? stackTrace,
}) {
  return AIProviderFailure(
    userMessage:
        userMessage ?? "La reconnaissance n'a pas pu aboutir. Réessaie.",
    logMessage: 'Gemma failure: $error',
    providerId: 'gemma',
    cause: error,
    stackTrace: stackTrace,
  );
}
