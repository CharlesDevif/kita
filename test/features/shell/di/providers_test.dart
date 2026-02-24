import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/shell/di/providers.dart';

void main() {
  group('Shell providers', () {
    test('shellGreetingProvider returns a greeting string', () {
      final container = ProviderContainer.test();
      final greeting = container.read(shellGreetingProvider);
      expect(greeting, isA<String>());
      expect(greeting, isNotEmpty);
    });

    test('shellStateProvider starts as idle', () {
      final container = ProviderContainer.test();
      final state = container.read(shellStateProvider);
      expect(state, 'idle');
    });

    test('ShellState notifier can update state', () {
      final container = ProviderContainer.test();
      expect(container.read(shellStateProvider), 'idle');

      container.read(shellStateProvider.notifier).updateState('active');
      expect(container.read(shellStateProvider), 'active');
    });

    test('shellInitializerProvider returns AsyncValue', () async {
      final container = ProviderContainer.test();
      final asyncValue = container.read(shellInitializerProvider);
      expect(asyncValue, isA<AsyncValue<bool>>());

      // Wait for the future to complete
      await container.read(shellInitializerProvider.future);
      final result = container.read(shellInitializerProvider);
      expect(result.value, isTrue);
    });
  });
}
