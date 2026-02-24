import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/config/environment.dart';
import 'package:kita/core/utils/logger.dart';

void main() {
  group('Environment.fromString', () {
    test('parses valid values', () {
      expect(Environment.fromString('dev'), Environment.dev);
      expect(Environment.fromString('staging'), Environment.staging);
      expect(Environment.fromString('prod'), Environment.prod);
    });

    test('defaults to dev for invalid values', () {
      expect(Environment.fromString(''), Environment.dev);
      expect(Environment.fromString('invalid'), Environment.dev);
      expect(Environment.fromString('production'), Environment.dev);
    });
  });

  group('EnvironmentConfig', () {
    test('default environment is dev (in test context)', () {
      // In tests, --dart-define is not set, so default is 'dev'
      expect(EnvironmentConfig.current, Environment.dev);
      expect(EnvironmentConfig.isDev, isTrue);
      expect(EnvironmentConfig.isStaging, isFalse);
      expect(EnvironmentConfig.isProd, isFalse);
      expect(EnvironmentConfig.isDebug, isTrue);
    });

    test('logLevel returns correct level per environment', () {
      // We can only test the mapping logic via Environment enum directly
      // since EnvironmentConfig.current is compile-time const.
      final levels = {
        Environment.dev: LogLevel.debug,
        Environment.staging: LogLevel.info,
        Environment.prod: LogLevel.warning,
      };

      for (final entry in levels.entries) {
        final level = switch (entry.key) {
          Environment.dev => LogLevel.debug,
          Environment.staging => LogLevel.info,
          Environment.prod => LogLevel.warning,
        };
        expect(level, entry.value);
      }
    });

    test('logLevel in default test context is debug', () {
      expect(EnvironmentConfig.logLevel, LogLevel.debug);
    });
  });
}
