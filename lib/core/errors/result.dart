import 'kita_failure.dart';

/// A Result type for typed error handling without exceptions.
///
/// Use [Result.success] for successful values, [Result.failure] for errors.
/// Pattern match with `switch` to handle both cases exhaustively.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(KitaFailure failure) = Failure<T>;

  /// Transforms the value if [Success], passes through [Failure].
  Result<U> map<U>(U Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Result.success(transform(value)),
      Failure(:final failure) => Result.failure(failure),
    };
  }

  /// Chains Results: transforms if [Success], short-circuits on [Failure].
  Result<U> flatMap<U>(Result<U> Function(T value) transform) {
    return switch (this) {
      Success(:final value) => transform(value),
      Failure(:final failure) => Result.failure(failure),
    };
  }

  /// Transforms the failure if [Failure], passes through [Success].
  Result<T> mapFailure(KitaFailure Function(KitaFailure failure) transform) {
    return switch (this) {
      Success() => this,
      Failure(:final failure) => Result.failure(transform(failure)),
    };
  }

  /// Callback pattern: calls the matching handler.
  void when({
    required void Function(T value) success,
    required void Function(KitaFailure failure) failure,
  }) {
    switch (this) {
      case Success(:final value):
        success(value);
      case Failure(failure: final f):
        failure(f);
    }
  }

  /// Returns the value if success, or calls [orElse] with the failure.
  T getOrElse(T Function(KitaFailure failure) orElse) {
    return switch (this) {
      Success(:final value) => value,
      Failure(:final failure) => orElse(failure),
    };
  }

  /// Returns the value if success, or null.
  T? getOrNull() {
    return switch (this) {
      Success(:final value) => value,
      Failure() => null,
    };
  }

  /// Returns true if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a [Failure].
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final KitaFailure failure;
}

/// Wraps a synchronous block, catching exceptions as [UnexpectedFailure].
Result<T> runCatching<T>(T Function() block) {
  try {
    return Result.success(block());
  } catch (e, stack) {
    return Result.failure(
      UnexpectedFailure(logMessage: e.toString(), cause: e, stackTrace: stack),
    );
  }
}

/// Wraps an async block, catching exceptions as [UnexpectedFailure].
Future<Result<T>> runCatchingAsync<T>(Future<T> Function() block) async {
  try {
    return Result.success(await block());
  } catch (e, stack) {
    return Result.failure(
      UnexpectedFailure(logMessage: e.toString(), cause: e, stackTrace: stack),
    );
  }
}
