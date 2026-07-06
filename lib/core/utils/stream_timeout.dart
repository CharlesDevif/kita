import 'dart:async';

/// Adds an inactivity timeout to an inference token stream.
extension InferenceTimeout on Stream<String> {
  /// Relays tokens; if no token arrives within [timeout] (before the first
  /// token or between two tokens), surfaces a [TimeoutException] and ends the
  /// stream. Prevents a stalled on-device inference from hanging forever with
  /// no spoken feedback.
  Stream<String> withInferenceTimeout(Duration timeout) {
    return this.timeout(
      timeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException('Inference produced no token within $timeout'),
        );
        sink.close();
      },
    );
  }
}
