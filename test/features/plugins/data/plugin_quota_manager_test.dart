import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/plugins/data/plugin_quota_manager.dart';

void main() {
  group('PluginQuotaManager', () {
    late DateTime _now;
    late PluginQuotaManager manager;

    setUp(() {
      _now = DateTime(2026, 1, 1, 12, 0, 0);
      manager = PluginQuotaManager(
        maxCallsPerMinute: 3,
        clock: () => _now,
      );
    });

    test('allows calls within quota', () {
      final result = manager.checkQuota('com.kita.test');
      expect(result.isSuccess, isTrue);
    });

    test('tracks calls and enforces quota', () {
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');

      final result = manager.checkQuota('com.kita.test');
      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.logMessage, contains('Quota exceeded'));
    });

    test('allows calls again after window expires', () {
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');

      // Advance time past the 1-minute window
      _now = _now.add(const Duration(minutes: 1, seconds: 1));

      final result = manager.checkQuota('com.kita.test');
      expect(result.isSuccess, isTrue);
    });

    test('tracks quotas independently per plugin', () {
      manager.recordCall('com.kita.a');
      manager.recordCall('com.kita.a');
      manager.recordCall('com.kita.a');

      // Plugin A is at quota
      expect(manager.checkQuota('com.kita.a').isFailure, isTrue);

      // Plugin B still has quota
      expect(manager.checkQuota('com.kita.b').isSuccess, isTrue);
    });

    test('remainingCalls returns correct count', () {
      expect(manager.remainingCalls('com.kita.test'), equals(3));

      manager.recordCall('com.kita.test');
      expect(manager.remainingCalls('com.kita.test'), equals(2));

      manager.recordCall('com.kita.test');
      expect(manager.remainingCalls('com.kita.test'), equals(1));

      manager.recordCall('com.kita.test');
      expect(manager.remainingCalls('com.kita.test'), equals(0));
    });

    test('remainingCalls recovers after window expires', () {
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');
      expect(manager.remainingCalls('com.kita.test'), equals(1));

      _now = _now.add(const Duration(minutes: 1, seconds: 1));
      expect(manager.remainingCalls('com.kita.test'), equals(3));
    });

    test('reset clears quota for a specific plugin', () {
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');
      expect(manager.checkQuota('com.kita.test').isFailure, isTrue);

      manager.reset('com.kita.test');
      expect(manager.checkQuota('com.kita.test').isSuccess, isTrue);
    });

    test('resetAll clears quota for all plugins', () {
      manager.recordCall('com.kita.a');
      manager.recordCall('com.kita.a');
      manager.recordCall('com.kita.a');
      manager.recordCall('com.kita.b');
      manager.recordCall('com.kita.b');
      manager.recordCall('com.kita.b');

      manager.resetAll();

      expect(manager.checkQuota('com.kita.a').isSuccess, isTrue);
      expect(manager.checkQuota('com.kita.b').isSuccess, isTrue);
    });

    test('uses Limits.maxPluginApiCallsPerMinute as default', () {
      final defaultManager = PluginQuotaManager(clock: () => _now);
      // Default is 10 calls/min from Limits
      for (var i = 0; i < 10; i++) {
        defaultManager.recordCall('com.kita.test');
      }
      expect(defaultManager.checkQuota('com.kita.test').isFailure, isTrue);
    });

    test('sliding window removes only expired entries', () {
      // Record 2 calls at T=0
      manager.recordCall('com.kita.test');
      manager.recordCall('com.kita.test');

      // Advance 30 seconds and record 1 more
      _now = _now.add(const Duration(seconds: 30));
      manager.recordCall('com.kita.test');

      // At quota now (3 calls in last minute)
      expect(manager.checkQuota('com.kita.test').isFailure, isTrue);

      // Advance to 61 seconds after first two calls (they expire)
      _now = _now.add(const Duration(seconds: 31));

      // The first 2 calls are now > 1 minute old, only 1 remains
      expect(manager.remainingCalls('com.kita.test'), equals(2));
      expect(manager.checkQuota('com.kita.test').isSuccess, isTrue);
    });
  });
}
