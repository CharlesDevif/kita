import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('all timeouts are positive', () {
      expect(AppConfig.aiCloudTimeout, greaterThan(Duration.zero));
      expect(AppConfig.aiLocalTimeout, greaterThan(Duration.zero));
      expect(AppConfig.pluginTimeout, greaterThan(Duration.zero));
      expect(AppConfig.networkTimeout, greaterThan(Duration.zero));
    });

    test('cacheTtlCritical is zero (never cached)', () {
      expect(AppConfig.cacheTtlCritical, Duration.zero);
    });

    test('cache TTLs are ordered by priority', () {
      expect(AppConfig.cacheTtlCritical, lessThan(AppConfig.cacheTtlUrgent));
      expect(AppConfig.cacheTtlUrgent, lessThan(AppConfig.cacheTtlStandard));
      expect(
        AppConfig.cacheTtlStandard,
        lessThan(AppConfig.cacheTtlBackground),
      );
    });

    test('aiCloudTimeout <= networkTimeout', () {
      expect(AppConfig.aiCloudTimeout, lessThanOrEqualTo(AppConfig.networkTimeout));
    });

    test('episode retention is positive', () {
      expect(AppConfig.episodeRetention, greaterThan(Duration.zero));
    });

    test('version constants are set', () {
      expect(AppConfig.appVersion, isNotEmpty);
      expect(AppConfig.minAndroidSdk, greaterThanOrEqualTo(31));
      expect(AppConfig.minIosVersion, isNotEmpty);
    });
  });
}
