import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/theme/multi_modal_tokens.dart';

void main() {
  group('KitaAnimationDurations', () {
    test('micro is 150ms', () {
      expect(KitaAnimationDurations.micro.inMilliseconds, 150);
    });

    test('transition is 300ms', () {
      expect(KitaAnimationDurations.transition.inMilliseconds, 300);
    });

    test('state is 500ms', () {
      expect(KitaAnimationDurations.state.inMilliseconds, 500);
    });

    test('durations are ordered: micro < transition < state', () {
      expect(KitaAnimationDurations.micro, lessThan(KitaAnimationDurations.transition));
      expect(KitaAnimationDurations.transition, lessThan(KitaAnimationDurations.state));
    });

    test('zero is Duration.zero', () {
      expect(KitaAnimationDurations.zero, Duration.zero);
    });
  });

  group('HapticPatterns', () {
    test('confirmation is 1 light vibration', () {
      expect(KitaHapticPatterns.confirmation.intensity, HapticIntensity.light);
      expect(KitaHapticPatterns.confirmation.repetitions, 1);
    });

    test('warning is 2 medium vibrations', () {
      expect(KitaHapticPatterns.warning.intensity, HapticIntensity.medium);
      expect(KitaHapticPatterns.warning.repetitions, 2);
    });

    test('danger is 3 heavy vibrations', () {
      expect(KitaHapticPatterns.danger.intensity, HapticIntensity.heavy);
      expect(KitaHapticPatterns.danger.repetitions, 3);
    });

    test('info is 1 light vibration', () {
      expect(KitaHapticPatterns.info.intensity, HapticIntensity.light);
      expect(KitaHapticPatterns.info.repetitions, 1);
    });
  });
}
