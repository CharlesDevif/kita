import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/domain/onboarding_state.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

void main() {
  group('OnboardingStep', () {
    test('has 6 steps in order', () {
      expect(OnboardingStep.values, hasLength(6));
      expect(OnboardingStep.values[0], OnboardingStep.detecting);
      expect(OnboardingStep.values[1], OnboardingStep.welcome);
      expect(OnboardingStep.values[2], OnboardingStep.profile);
      expect(OnboardingStep.values[3], OnboardingStep.permissions);
      expect(OnboardingStep.values[4], OnboardingStep.magic);
      expect(OnboardingStep.values[5], OnboardingStep.complete);
    });
  });

  group('OnboardingState', () {
    test('default state starts at detecting step', () {
      const state = OnboardingState();
      expect(state.step, OnboardingStep.detecting);
      expect(state.detectedProfile, isNull);
      expect(state.userName, isNull);
      expect(state.permissionsGranted, isEmpty);
      expect(state.onboardingComplete, isFalse);
    });

    test('copyWith creates a new state with updated fields', () {
      const initial = OnboardingState();
      final updated = initial.copyWith(
        step: OnboardingStep.welcome,
        detectedProfile: DetectedProfile.general,
        userName: 'Marie',
      );

      expect(updated.step, OnboardingStep.welcome);
      expect(updated.detectedProfile, DetectedProfile.general);
      expect(updated.userName, 'Marie');
      // Unchanged fields remain
      expect(updated.permissionsGranted, isEmpty);
      expect(updated.onboardingComplete, isFalse);
    });

    test('copyWith preserves existing values when not specified', () {
      final state = const OnboardingState().copyWith(
        step: OnboardingStep.profile,
        userName: 'Marie',
      );
      final updated = state.copyWith(
        step: OnboardingStep.permissions,
      );

      expect(updated.userName, 'Marie');
      expect(updated.step, OnboardingStep.permissions);
    });

    test('equality works correctly', () {
      const a = OnboardingState(step: OnboardingStep.welcome);
      const b = OnboardingState(step: OnboardingStep.welcome);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when step differs', () {
      const a = OnboardingState(step: OnboardingStep.welcome);
      const b = OnboardingState(step: OnboardingStep.profile);
      expect(a, isNot(equals(b)));
    });

    test('permissions set can be updated via copyWith', () {
      const state = OnboardingState();
      final updated = state.copyWith(
        permissionsGranted: {'camera', 'microphone'},
      );
      expect(updated.permissionsGranted, contains('camera'));
      expect(updated.permissionsGranted, contains('microphone'));
      expect(updated.permissionsGranted, hasLength(2));
    });

    test('toString contains step info', () {
      const state = OnboardingState(step: OnboardingStep.magic);
      expect(state.toString(), contains('magic'));
    });
  });
}
