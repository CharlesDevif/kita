import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';

/// Recognized voice command types.
enum VoiceCommand {
  describe,
  read,
  stop,
  help,
  thanks,
  repeat,
  moreDetails,
}

/// Handles voice command recognition from STT transcripts.
///
/// Recognizes French commands with case-insensitive, accent-tolerant matching.
/// Supported commands: "decris", "lis ca", "stop", "aide", "merci", "repete".
class VoiceCommandHandler {
  static final _log = KitaLogger('IO');

  /// Maps normalized trigger words to their [VoiceCommand].
  ///
  /// Each command has multiple accepted variations for tolerance.
  /// STT commonly mishears "décris" as phonetically similar phrases,
  /// so extra variants are included for robust matching.
  static final Map<VoiceCommand, List<String>> _commandPatterns = {
    VoiceCommand.describe: [
      'decris',
      'decrit',
      'decrie',
      'decri',
      'decrire',
      'decrivez',
      'decris-moi',
      'describe',
      'description',
      'ecris', // STT often hears "décris" as "tu écris"
      // Common STT misrecognitions of "décris":
      'des cris', // phonetically close
      'des crit', // variant
      'decran', // "d'écran" after apostrophe stripping
      'des crits', // plural variant
    ],
    VoiceCommand.read: [
      'lis',
      'lis ca',
      'lis ça',
      'lit ca',
      'lit ça',
      'lire',
      'lecture',
    ],
    VoiceCommand.stop: [
      'stop',
      'arrete',
      'arrête',
      'arreter',
      'pause',
    ],
    VoiceCommand.help: [
      'aide',
      'aidez',
      'aider',
      'help',
      'au secours',
    ],
    VoiceCommand.thanks: [
      'merci',
      'remercie',
      'merci beaucoup',
    ],
    VoiceCommand.repeat: [
      'repete',
      'répète',
      'repeter',
      'répéter',
      'repetez',
      'redis',
      'encore',
    ],
    VoiceCommand.moreDetails: [
      'plus de details',
      'plus de détails',
      'details',
      'détails',
      'detaille',
      'détaille',
      'approfondi',
      'approfondir',
      'en detail',
      'en détail',
    ],
  };

  /// Attempts to recognize a [VoiceCommand] from the given [transcript].
  ///
  /// Returns `Result.success(command)` if recognized, or
  /// `Result.failure` if the transcript doesn't match any command.
  static Result<VoiceCommand> recognize(String transcript) {
    final normalized = _normalize(transcript);

    if (normalized.isEmpty) {
      return const Result.failure(
        UnexpectedFailure(
          logMessage: 'Voice command empty transcript',
        ),
      );
    }

    for (final entry in _commandPatterns.entries) {
      for (final pattern in entry.value) {
        if (normalized.contains(pattern)) {
          _log.info('Voice command recognized: ${entry.key.name}');
          return Result.success(entry.key);
        }
      }
    }

    _log.debug('Voice command not recognized: $normalized');
    return Result.failure(
      UnexpectedFailure(
        logMessage: 'Unrecognized voice command: $normalized',
      ),
    );
  }

  /// Normalizes text for command matching: lowercase, trim, strip accents,
  /// and remove apostrophes/curly quotes that STT inserts in contractions.
  static String _normalize(String text) {
    final stripped = _stripAccents(text.toLowerCase().trim());
    // Remove apostrophes/curly quotes so "d'écran" -> "decran"
    // Covers: ' (U+0027), \u2019 (right single quote), \u02BC (modifier apostrophe)
    return stripped.replaceAll(RegExp("['\\u2019\\u02BC]"), '');
  }

  /// Strips common French diacritical marks for tolerant matching.
  static String _stripAccents(String text) {
    const accented = 'àâäéèêëïîôùûüÿçœæ';
    const replaced = 'aaaeeeeiiouuuycoa';

    final buffer = StringBuffer();
    for (final char in text.runes) {
      final s = String.fromCharCode(char);
      final idx = accented.indexOf(s);
      if (idx >= 0) {
        buffer.write(replaced[idx]);
      } else {
        buffer.write(s);
      }
    }
    return buffer.toString();
  }
}
