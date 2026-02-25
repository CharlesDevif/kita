import 'dart:async';

/// Injectable clock abstraction for deterministic testing.
///
/// All time-dependent components (OutputCoordinator cooldowns,
/// DescribeAgent silence timeout, etc.) receive a [Clock] instance
/// instead of using `DateTime.now()` or `Timer` directly.
///
/// In production, use [SystemClock]. In tests, use [FakeClock].
abstract class Clock {
  /// Returns the current time.
  DateTime now();

  /// Creates a periodic timer that fires every [duration].
  Timer periodic(Duration duration, void Function(Timer timer) callback);

  /// Creates a one-shot timer that fires after [duration].
  Timer delayed(Duration duration, void Function() callback);

  /// Returns a Future that completes after [duration].
  Future<void> wait(Duration duration);
}

/// Production clock using real system time and dart:async timers.
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();

  @override
  Timer periodic(Duration duration, void Function(Timer timer) callback) {
    return Timer.periodic(duration, callback);
  }

  @override
  Timer delayed(Duration duration, void Function() callback) {
    return Timer(duration, callback);
  }

  @override
  Future<void> wait(Duration duration) => Future.delayed(duration);
}

/// Fake clock for deterministic testing.
///
/// Time does not advance automatically. Use [advance] to move time forward
/// and trigger any pending timers or waits that have reached their deadline.
///
/// **Important for async tests:** After calling [advance], you may need
/// to flush microtasks for async callbacks to complete:
///
/// ```dart
/// fakeClock.advance(const Duration(seconds: 5));
/// await Future.microtask(() {}); // flush microtasks
/// expect(callbackExecuted, isTrue);
/// ```
class FakeClock implements Clock {
  /// Creates a [FakeClock] starting at [initialTime].
  ///
  /// Defaults to 2026-01-01T00:00:00 if not specified.
  FakeClock({DateTime? initialTime})
      : _currentTime = initialTime ?? DateTime(2026, 1, 1);

  DateTime _currentTime;
  final List<_PendingTimer> _pendingTimers = [];
  final List<_PendingWait> _pendingWaits = [];

  /// The current simulated time.
  DateTime get currentTime => _currentTime;

  @override
  DateTime now() => _currentTime;

  @override
  Timer periodic(Duration duration, void Function(Timer timer) callback) {
    final timer = _FakePeriodicTimer(duration: duration, callback: callback);
    _pendingTimers.add(_PendingTimer(
      fireAt: _currentTime.add(duration),
      timer: timer,
    ));
    return timer;
  }

  @override
  Timer delayed(Duration duration, void Function() callback) {
    final timer = _FakeDelayedTimer(callback: callback);
    _pendingTimers.add(_PendingTimer(
      fireAt: _currentTime.add(duration),
      timer: timer,
    ));
    return timer;
  }

  @override
  Future<void> wait(Duration duration) {
    final completer = Completer<void>();
    _pendingWaits.add(_PendingWait(
      completeAt: _currentTime.add(duration),
      completer: completer,
    ));
    return completer.future;
  }

  /// Advances the simulated time by [duration] and fires any pending
  /// timers and waits that have reached their deadline.
  ///
  /// Timers and waits are fired in chronological order.
  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
    _firePendingTimers();
    _completePendingWaits();
  }

  void _firePendingTimers() {
    // Process timers that are due. We iterate with an index because
    // periodic timers re-add themselves during iteration.
    // Sort before each scan to guarantee chronological execution order.
    var i = 0;
    _pendingTimers.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    while (i < _pendingTimers.length) {
      final pending = _pendingTimers[i];
      if (pending.timer.isCancelled) {
        _pendingTimers.removeAt(i);
        continue;
      }
      if (!_currentTime.isBefore(pending.fireAt)) {
        _pendingTimers.removeAt(i);
        if (pending.timer is _FakePeriodicTimer) {
          final periodicTimer = pending.timer as _FakePeriodicTimer;
          periodicTimer.incrementTick();
          periodicTimer.callback(periodicTimer);
          // Re-schedule for the next period if not cancelled.
          if (!periodicTimer.isCancelled) {
            _pendingTimers.add(_PendingTimer(
              fireAt: pending.fireAt.add(periodicTimer.duration),
              timer: periodicTimer,
            ));
          }
        } else if (pending.timer is _FakeDelayedTimer) {
          pending.timer.markFired();
          (pending.timer as _FakeDelayedTimer).callback();
        }
        // Re-sort and restart from beginning since list may have been modified.
        _pendingTimers.sort((a, b) => a.fireAt.compareTo(b.fireAt));
        i = 0;
      } else {
        i++;
      }
    }
  }

  void _completePendingWaits() {
    _pendingWaits.removeWhere((pending) {
      if (!_currentTime.isBefore(pending.completeAt)) {
        pending.completer.complete();
        return true;
      }
      return false;
    });
  }
}

/// Internal: a pending timer entry in [FakeClock].
class _PendingTimer {
  _PendingTimer({
    required this.fireAt,
    required this.timer,
  });

  final DateTime fireAt;
  final _FakeTimerBase timer;
}

/// Internal: a pending wait entry in [FakeClock].
class _PendingWait {
  _PendingWait({
    required this.completeAt,
    required this.completer,
  });

  final DateTime completeAt;
  final Completer<void> completer;
}

/// Base class for fake timers that support cancellation.
abstract class _FakeTimerBase implements Timer {
  bool _isCancelled = false;
  bool _hasFired = false;
  int _tick = 0;

  bool get isCancelled => _isCancelled;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _isCancelled = true;
  }

  @override
  bool get isActive => !_isCancelled && !_hasFired;

  /// Marks the timer as having fired (for one-shot timers).
  void markFired() {
    _hasFired = true;
  }

  /// Increments the tick count.
  void incrementTick() {
    _tick++;
  }
}

/// Internal: a fake periodic timer.
class _FakePeriodicTimer extends _FakeTimerBase {
  _FakePeriodicTimer({
    required this.duration,
    required this.callback,
  });

  final Duration duration;
  final void Function(Timer timer) callback;
}

/// Internal: a fake one-shot delayed timer.
class _FakeDelayedTimer extends _FakeTimerBase {
  _FakeDelayedTimer({required this.callback});

  final void Function() callback;
}
