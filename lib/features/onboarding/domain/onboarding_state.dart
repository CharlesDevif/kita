import 'profile_detection.dart';

/// Steps of the onboarding flow.
///
/// Progresses linearly: detecting -> welcome -> profile -> permissions
/// -> magic -> complete.
enum OnboardingStep {
  /// Initial accessibility detection (transparent to user).
  detecting,

  /// Welcome screen — Kita introduces herself.
  welcome,

  /// Profile confirmation/selection screen.
  profile,

  /// Permission storytelling flow.
  permissions,

  /// First "magic moment" — demonstrate core value.
  magic,

  /// Onboarding complete — transition to main app.
  complete,
}

/// State of the onboarding flow.
///
/// Tracks the current step, detected profile, user name,
/// permission grants, and completion flag.
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.detecting,
    this.detectedProfile,
    this.userName,
    this.permissionsGranted = const {},
    this.onboardingComplete = false,
  });

  /// Current step in the onboarding flow.
  final OnboardingStep step;

  /// Profile detected from OS accessibility features.
  final DetectedProfile? detectedProfile;

  /// User's name (collected during onboarding).
  final String? userName;

  /// Set of permissions granted during onboarding.
  final Set<String> permissionsGranted;

  /// Whether the onboarding has been fully completed.
  final bool onboardingComplete;

  /// Create a copy with updated fields.
  OnboardingState copyWith({
    OnboardingStep? step,
    DetectedProfile? detectedProfile,
    String? userName,
    Set<String>? permissionsGranted,
    bool? onboardingComplete,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      detectedProfile: detectedProfile ?? this.detectedProfile,
      userName: userName ?? this.userName,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          step == other.step &&
          detectedProfile == other.detectedProfile &&
          userName == other.userName &&
          onboardingComplete == other.onboardingComplete &&
          permissionsGranted.length == other.permissionsGranted.length &&
          permissionsGranted.containsAll(other.permissionsGranted);

  @override
  int get hashCode => Object.hash(
        step,
        detectedProfile,
        userName,
        Object.hashAll(permissionsGranted),
        onboardingComplete,
      );

  @override
  String toString() =>
      'OnboardingState(step: $step, profile: ${detectedProfile?.profile}, '
      'complete: $onboardingComplete)';
}
