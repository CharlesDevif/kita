import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';

void main() {
  const failure = NetworkFailure(
    userMessage: 'User msg',
    logMessage: 'Network error',
  );

  group('Result basics', () {
    test('Success: isSuccess, getOrNull, getOrElse', () {
      const result = Result.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.getOrNull(), 42);
      expect(result.getOrElse((_) => 0), 42);
    });

    test('Failure: isFailure, getOrNull, getOrElse', () {
      const result = Result<int>.failure(failure);
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.getOrNull(), isNull);
      expect(result.getOrElse((_) => -1), -1);
    });
  });

  group('map', () {
    test('transforms Success value', () {
      const result = Result.success(10);
      final mapped = result.map((v) => v * 2);
      expect(mapped.getOrNull(), 20);
    });

    test('passes through Failure', () {
      const result = Result<int>.failure(failure);
      final mapped = result.map((v) => v * 2);
      expect(mapped.isFailure, isTrue);
    });
  });

  group('flatMap', () {
    test('chains Success', () {
      const result = Result.success(5);
      final chained = result.flatMap((v) => Result.success('value: $v'));
      expect(chained.getOrNull(), 'value: 5');
    });

    test('short-circuits Failure', () {
      const result = Result<int>.failure(failure);
      var called = false;
      final chained = result.flatMap((v) {
        called = true;
        return Result.success(v);
      });
      expect(chained.isFailure, isTrue);
      expect(called, isFalse);
    });
  });

  group('mapFailure', () {
    test('transforms Failure', () {
      const result = Result<int>.failure(failure);
      final mapped = result.mapFailure(
        (f) => StorageFailure(
          userMessage: f.userMessage,
          logMessage: 'Wrapped: ${f.logMessage}',
        ),
      );
      expect(mapped.isFailure, isTrue);
      expect(
        (mapped as Failure<int>).failure.logMessage,
        contains('Wrapped'),
      );
    });

    test('passes through Success', () {
      const result = Result.success(42);
      final mapped = result.mapFailure(
        (f) => const UnexpectedFailure(logMessage: 'nope'),
      );
      expect(mapped.getOrNull(), 42);
    });
  });

  group('when', () {
    test('calls success callback on Success', () {
      const result = Result.success('hello');
      String? captured;
      result.when(
        success: (v) => captured = v,
        failure: (_) => fail('should not be called'),
      );
      expect(captured, 'hello');
    });

    test('calls failure callback on Failure', () {
      const result = Result<String>.failure(failure);
      KitaFailure? captured;
      result.when(
        success: (_) => fail('should not be called'),
        failure: (f) => captured = f,
      );
      expect(captured, isA<NetworkFailure>());
    });
  });

  group('exhaustive pattern matching', () {
    test('switch covers Success and Failure without default', () {
      const Result<int> success = Result.success(1);
      const Result<int> fail = Result.failure(failure);

      for (final r in [success, fail]) {
        final label = switch (r) {
          Success(:final value) => 'success: $value',
          Failure(:final failure) => 'failure: ${failure.logMessage}',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('runCatching', () {
    test('wraps successful result', () {
      final result = runCatching(() => 42);
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), 42);
    });

    test('wraps exception as UnexpectedFailure', () {
      final result = runCatching<int>(() => throw Exception('boom'));
      expect(result.isFailure, isTrue);
      final f = (result as Failure<int>).failure;
      expect(f, isA<UnexpectedFailure>());
      expect(f.logMessage, contains('boom'));
      expect(f.cause, isA<Exception>());
      expect(f.stackTrace, isNotNull);
    });
  });

  group('runCatchingAsync', () {
    test('wraps successful async result', () async {
      final result = await runCatchingAsync(() async => 'ok');
      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), 'ok');
    });

    test('wraps async exception as UnexpectedFailure', () async {
      final result = await runCatchingAsync<int>(
        () async => throw StateError('async boom'),
      );
      expect(result.isFailure, isTrue);
      final f = (result as Failure<int>).failure;
      expect(f, isA<UnexpectedFailure>());
      expect(f.logMessage, contains('async boom'));
    });
  });
}
