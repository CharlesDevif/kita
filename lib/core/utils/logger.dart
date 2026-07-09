import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

/// Log severity levels, mapped to dart:developer level values.
enum LogLevel implements Comparable<LogLevel> {
  debug(0),
  info(800),
  warning(900),
  error(1000),
  critical(1200);

  const LogLevel(this.value);
  final int value;

  @override
  int compareTo(LogLevel other) => value.compareTo(other.value);
}

/// Log entry captured by [KitaLogger.testLogHandler] during tests.
typedef LogEntry = ({
  String message,
  LogLevel level,
  Object? error,
  StackTrace? stackTrace,
});

/// One captured log line for the in-app journal (Réglages → Journal).
///
/// Les logs Kita sont garantis sans PII (règle stricte du projet), le
/// journal est donc sûr à afficher et à copier pour le diagnostic.
typedef JournalEntry = ({
  DateTime timestamp,
  LogLevel level,
  String message,
});

/// Centralized logger for the Kita app.
///
/// Format: `[Source] Message` — zero PII in logs.
///
/// Uses `dart:developer log()` for native DevTools integration.
class KitaLogger {
  const KitaLogger._(this._source);

  /// Create a logger for a given source tag.
  factory KitaLogger(String source) => KitaLogger._(source);

  final String _source;

  static LogLevel _minLevel = LogLevel.debug;

  /// Set minimum log level. In prod, set to [LogLevel.warning].
  static void setMinLevel(LogLevel level) => _minLevel = level;

  /// Hook for tests — when set, log entries go here instead of dart:developer.
  @visibleForTesting
  static void Function(LogEntry entry)? testLogHandler;

  void debug(String message) => _log(message, level: LogLevel.debug);

  void info(String message) => _log(message, level: LogLevel.info);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.warning, error: error, stackTrace: stackTrace);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);

  void critical(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: LogLevel.critical, error: error, stackTrace: stackTrace);

  /// Ring buffer of the most recent log lines, shown in Réglages → Journal.
  static final List<JournalEntry> _journal = [];
  static const int _journalCapacity = 300;

  /// The recent log lines (oldest first). Safe to display: zero PII by rule.
  static List<JournalEntry> get journal => List.unmodifiable(_journal);

  /// Clears the in-memory journal (tests, or user request).
  static void clearJournal() => _journal.clear();

  void _log(
    String message, {
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < _minLevel.value) return;

    final formatted = '[$_source] $message';
    final errorSuffix = error != null ? ' | $error' : '';

    _journal.add((
      timestamp: DateTime.now(),
      level: level,
      message: '$formatted$errorSuffix',
    ));
    if (_journal.length > _journalCapacity) {
      _journal.removeAt(0);
    }

    if (testLogHandler != null) {
      testLogHandler!(
        (message: formatted, level: level, error: error, stackTrace: stackTrace),
      );
      return;
    }

    // dart:developer log() est INVISIBLE en build release (il ne va qu'au
    // VM service, pas à logcat). On imprime donc aussi via debugPrint pour
    // que `adb logcat` capte les logs sur un vrai appareil ; _minLevel
    // borne déjà le volume (prod = info).
    debugPrint('kita: $formatted$errorSuffix');

    dev.log(
      formatted,
      level: level.value,
      name: 'kita',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
