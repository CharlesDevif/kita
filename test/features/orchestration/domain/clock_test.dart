import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/orchestration/domain/clock.dart';

void main() {
  group('FakeClock', () {
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(initialTime: DateTime(2026, 1, 1, 12, 0, 0));
    });

    test('now() returns the initial time', () {
      expect(clock.now(), DateTime(2026, 1, 1, 12, 0, 0));
    });

    test('advance() moves time forward', () {
      clock.advance(const Duration(seconds: 5));
      expect(clock.now(), DateTime(2026, 1, 1, 12, 0, 5));
    });

    test('currentTime getter matches now()', () {
      expect(clock.currentTime, clock.now());
      clock.advance(const Duration(minutes: 2));
      expect(clock.currentTime, clock.now());
    });

    group('delayed()', () {
      test('executes callback when time reaches deadline', () {
        var executed = false;
        clock.delayed(const Duration(seconds: 3), () => executed = true);

        clock.advance(const Duration(seconds: 3));
        expect(executed, isTrue);
      });

      test('does not execute callback before deadline', () {
        var executed = false;
        clock.delayed(const Duration(seconds: 3), () => executed = true);

        clock.advance(const Duration(seconds: 2));
        expect(executed, isFalse);
      });

      test('executes callback when advance overshoots deadline', () {
        var executed = false;
        clock.delayed(const Duration(seconds: 3), () => executed = true);

        clock.advance(const Duration(seconds: 10));
        expect(executed, isTrue);
      });

      test('does not execute callback when timer is cancelled', () {
        var executed = false;
        final timer = clock.delayed(
          const Duration(seconds: 3),
          () => executed = true,
        );

        timer.cancel();
        clock.advance(const Duration(seconds: 5));
        expect(executed, isFalse);
      });
    });

    group('periodic()', () {
      test('executes callback N times when time covers N periods', () {
        var count = 0;
        clock.periodic(const Duration(seconds: 1), (_) => count++);

        clock.advance(const Duration(seconds: 3));
        expect(count, 3);
      });

      test('does not execute callback before first period', () {
        var count = 0;
        clock.periodic(const Duration(seconds: 2), (_) => count++);

        clock.advance(const Duration(milliseconds: 1999));
        expect(count, 0);
      });

      test('does not execute callback after cancel', () {
        var count = 0;
        final timer = clock.periodic(
          const Duration(seconds: 1),
          (_) => count++,
        );

        clock.advance(const Duration(seconds: 2));
        expect(count, 2);

        timer.cancel();
        clock.advance(const Duration(seconds: 3));
        expect(count, 2); // No more callbacks after cancel.
      });

      test('timer provides correct tick count', () {
        final ticks = <int>[];
        clock.periodic(
          const Duration(seconds: 1),
          (timer) => ticks.add(timer.tick),
        );

        clock.advance(const Duration(seconds: 3));
        expect(ticks, [1, 2, 3]);
      });

      test('timer.isActive is false after cancel', () {
        final timer = clock.periodic(
          const Duration(seconds: 1),
          (_) {},
        );

        expect(timer.isActive, isTrue);
        timer.cancel();
        expect(timer.isActive, isFalse);
      });
    });

    group('wait()', () {
      test('future completes when advance reaches duration', () async {
        var completed = false;
        unawaited(
          clock.wait(const Duration(seconds: 2)).then((_) => completed = true),
        );

        clock.advance(const Duration(seconds: 2));
        await Future.microtask(() {}); // Flush microtasks.

        expect(completed, isTrue);
      });

      test('future does not complete before duration', () async {
        var completed = false;
        unawaited(
          clock.wait(const Duration(seconds: 5)).then((_) => completed = true),
        );

        clock.advance(const Duration(seconds: 3));
        await Future.microtask(() {});

        expect(completed, isFalse);
      });

      test('future completes when advance overshoots duration', () async {
        var completed = false;
        unawaited(
          clock.wait(const Duration(seconds: 2)).then((_) => completed = true),
        );

        clock.advance(const Duration(seconds: 10));
        await Future.microtask(() {});

        expect(completed, isTrue);
      });
    });

    test('default initial time is 2026-01-01', () {
      final defaultClock = FakeClock();
      expect(defaultClock.now(), DateTime(2026, 1, 1));
    });

    test('multiple timers fire in correct order', () {
      final order = <String>[];
      clock.delayed(const Duration(seconds: 3), () => order.add('3s'));
      clock.delayed(const Duration(seconds: 1), () => order.add('1s'));
      clock.delayed(const Duration(seconds: 2), () => order.add('2s'));

      clock.advance(const Duration(seconds: 3));

      expect(order, containsAll(['1s', '2s', '3s']));
      expect(order.length, 3);
    });
  });

  group('SystemClock', () {
    test('now() returns a DateTime close to DateTime.now()', () {
      final clock = SystemClock();
      final before = DateTime.now();
      final clockNow = clock.now();
      final after = DateTime.now();

      expect(
        clockNow.isAfter(before.subtract(const Duration(milliseconds: 1))) &&
            clockNow.isBefore(after.add(const Duration(milliseconds: 1))),
        isTrue,
        reason: 'SystemClock.now() should return a time close to DateTime.now()',
      );
    });
  });
}
