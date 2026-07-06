import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/utils/stream_timeout.dart';

void main() {
  group('withInferenceTimeout', () {
    test('relays tokens that arrive in time', () async {
      final source = Stream<String>.fromIterable(['a', 'b', 'c']);
      final result =
          await source.withInferenceTimeout(const Duration(seconds: 1)).toList();
      expect(result, ['a', 'b', 'c']);
    });

    test('emits a TimeoutException when the stream stalls', () async {
      final controller = StreamController<String>();
      final events = <String>[];
      Object? error;
      final done = Completer<void>();

      controller.stream
          .withInferenceTimeout(const Duration(milliseconds: 50))
          .listen(
        events.add,
        onError: (Object e) => error = e,
        onDone: done.complete,
      );

      controller.add('first');
      // Then never add another token → should time out.
      await done.future;
      expect(events, ['first']);
      expect(error, isA<TimeoutException>());
      await controller.close();
    });
  });
}
