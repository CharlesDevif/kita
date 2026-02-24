import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/di/providers.dart';
import 'package:kita/core/utils/logger.dart';

void main() {
  group('Core providers', () {
    test('ProviderScope starts without error', () {
      final container = ProviderContainer.test();
      expect(() => container.read(kitaLoggerProvider), returnsNormally);
    });

    test('kitaLoggerProvider returns a KitaLogger', () {
      final container = ProviderContainer.test();
      final logger = container.read(kitaLoggerProvider);
      expect(logger, isA<KitaLogger>());
    });
  });
}
