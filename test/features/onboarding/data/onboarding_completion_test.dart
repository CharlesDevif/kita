import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/data/onboarding_completion.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

void main() {
  group('OnboardingCompletion', () {
    test('isCompleted is false initially', () {
      final completion = OnboardingCompletion();
      expect(completion.isCompleted, isFalse);
    });

    test('completeOnboarding persists profile via callback', () async {
      String? persistedName;
      AccessibilityProfile? persistedProfile;

      final completion = OnboardingCompletion(
        onPersistProfile: (name, profile) async {
          persistedName = name;
          persistedProfile = profile;
        },
      );

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.blind,
      );

      expect(persistedName, 'Marie');
      expect(persistedProfile, AccessibilityProfile.blind);
    });

    test('completeOnboarding marks completion via callback', () async {
      bool markCompleteCalled = false;

      final completion = OnboardingCompletion(
        onMarkComplete: () async {
          markCompleteCalled = true;
        },
      );

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.general,
      );

      expect(markCompleteCalled, isTrue);
    });

    test('isCompleted is true after completeOnboarding', () async {
      final completion = OnboardingCompletion();

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.general,
      );

      expect(completion.isCompleted, isTrue);
    });

    test('duplicate completeOnboarding call is ignored', () async {
      int callCount = 0;

      final completion = OnboardingCompletion(
        onPersistProfile: (_, __) async {
          callCount++;
        },
      );

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.blind,
      );
      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.blind,
      );

      expect(callCount, 1);
      expect(completion.isCompleted, isTrue);
    });

    test('works without callbacks (no-op persistence)', () async {
      final completion = OnboardingCompletion();

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.general,
      );

      expect(completion.isCompleted, isTrue);
    });

    test('supports caregiver mode parameters', () async {
      String? persistedName;

      final completion = OnboardingCompletion(
        onPersistProfile: (name, profile) async {
          persistedName = name;
        },
      );

      await completion.completeOnboarding(
        userName: 'Marie',
        profile: AccessibilityProfile.blind,
        isConfiguredByCaregiver: true,
        caregiverName: 'Sophie',
      );

      expect(persistedName, 'Marie');
      expect(completion.isCompleted, isTrue);
    });
  });
}
