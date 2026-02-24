import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/logger.dart';

void main() {
  late List<LogEntry> captured;

  setUp(() {
    captured = [];
    KitaLogger.testLogHandler = (entry) => captured.add(entry);
    KitaLogger.setMinLevel(LogLevel.debug);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    KitaLogger.setMinLevel(LogLevel.debug);
  });

  group('KitaLogger format', () {
    test('log format is [Source] Message', () {
      final logger = KitaLogger('AIRouter');
      logger.info('Routing to cloud');
      expect(captured, hasLength(1));
      expect(captured.first.message, '[AIRouter] Routing to cloud');
    });

    test('source tag is preserved', () {
      final logger = KitaLogger('Plugin.Describe');
      logger.debug('Photo captured');
      expect(captured.first.message, startsWith('[Plugin.Describe]'));
    });
  });

  group('Log levels', () {
    test('debug level', () {
      KitaLogger('T').debug('msg');
      expect(captured.first.level, LogLevel.debug);
    });

    test('info level', () {
      KitaLogger('T').info('msg');
      expect(captured.first.level, LogLevel.info);
    });

    test('warning level with error', () {
      final err = Exception('warn');
      KitaLogger('T').warning('msg', error: err);
      expect(captured.first.level, LogLevel.warning);
      expect(captured.first.error, err);
    });

    test('error level with stackTrace', () {
      final stack = StackTrace.current;
      KitaLogger('T').error('msg', stackTrace: stack);
      expect(captured.first.level, LogLevel.error);
      expect(captured.first.stackTrace, stack);
    });

    test('critical level', () {
      KitaLogger('T').critical('msg');
      expect(captured.first.level, LogLevel.critical);
    });
  });

  group('setMinLevel filtering', () {
    test('filters messages below threshold', () {
      KitaLogger.setMinLevel(LogLevel.warning);
      final logger = KitaLogger('T');
      logger.debug('filtered');
      logger.info('filtered');
      logger.warning('kept');
      logger.error('kept');
      logger.critical('kept');
      expect(captured, hasLength(3));
      expect(captured.map((e) => e.level), [
        LogLevel.warning,
        LogLevel.error,
        LogLevel.critical,
      ]);
    });

    test('debug level captures everything', () {
      KitaLogger.setMinLevel(LogLevel.debug);
      final logger = KitaLogger('T');
      logger.debug('d');
      logger.info('i');
      logger.warning('w');
      logger.error('e');
      logger.critical('c');
      expect(captured, hasLength(5));
    });
  });

  group('LogLevel ordering', () {
    test('levels are ordered by severity', () {
      expect(LogLevel.debug.value < LogLevel.info.value, isTrue);
      expect(LogLevel.info.value < LogLevel.warning.value, isTrue);
      expect(LogLevel.warning.value < LogLevel.error.value, isTrue);
      expect(LogLevel.error.value < LogLevel.critical.value, isTrue);
    });

    test('compareTo works correctly', () {
      expect(LogLevel.debug.compareTo(LogLevel.critical), isNegative);
      expect(LogLevel.critical.compareTo(LogLevel.debug), isPositive);
      expect(LogLevel.info.compareTo(LogLevel.info), isZero);
    });
  });

  group('PII prevention (documentary test)', () {
    test('log messages must not contain common PII patterns', () {
      // Fixture: sample log messages that an agent might write.
      // This test documents the pattern — agents must write similar tests.
      final sampleLogMessages = [
        'Network timeout on /api/chat',
        'Rate limited by provider openai',
        'Plugin com.kita.describe timed out',
        'Database error during insert',
        'Permission denied: camera',
        'Model gpt-4 unavailable on provider openai',
      ];

      final piiPatterns = [
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), // email
        RegExp(r'\b\d{10,}\b'), // phone-like numbers
        RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'), // US phone
        RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), // IP address
      ];

      for (final msg in sampleLogMessages) {
        for (final pattern in piiPatterns) {
          expect(
            pattern.hasMatch(msg),
            isFalse,
            reason: 'Log message "$msg" matches PII pattern ${pattern.pattern}',
          );
        }
      }
    });
  });
}
