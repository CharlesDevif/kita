import 'profile_detection.dart';

/// Steps of the onboarding flow.
///
/// Standard flow: detecting -> welcome -> modeChoice -> profile ->
///   permissions -> magic -> complete.
/// Caregiver flow: detecting -> welcome -> modeChoice -> caregiver -> complete.
enum OnboardingStep {
  /// Initial accessibility detection (transparent to user).
  detecting,

  /// Welcome screen — Kita introduces herself.
  welcome,

  /// Choose "Pour moi" or "Pour quelqu'un d'autre".
  modeChoice,

  /// Profile confirmation/selection screen (standard flow).
  profile,

  /// Permission storytelling flow (standard flow).
  permissions,

  /// First "magic moment" — demonstrate core value (standard flow).
  magic,

  /// Caregiver flow — configure for a third party.
  caregiver,

  /// Onboarding complete — transition to main app.
  complete,
}

/// State of the onboarding flow.
///
/// Tracks the current step, detected profile, user name,
/// permission grants, caregiver mode, and completion flag.
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.detecting,
    this.detectedProfile,
    this.userName,
    this.permissionsGranted = const {},
    this.onboardingComplete = false,
    this.isCaregiverMode = false,
    this.isConfiguredByCaregiver = false,
  });

  /// Current step in the onboarding flow.
  final OnboardingStep step;

  /// Profile detected from OS accessibility features.
  final DetectedProfile? detectedProfile;

  /// User's name (collected during onboarding).
  /// In caregiver mode, this is the target user's name (e.g. "Marie").
  final String? userName;

  /// Set of permissions granted during onboarding.
  final Set<String> permissionsGranted;

  /// Whether the onboarding has been fully completed.
  final bool onboardingComplete;

  /// Whether the current onboarding is in caregiver mode
  /// ("Pour quelqu'un d'autre").
  final bool isCaregiverMode;

  /// Whether the onboarding was completed by a caregiver.
  final bool isConfiguredByCaregiver;

  /// Create a copy with updated fields.
  OnboardingState copyWith({
    OnboardingStep? step,
    DetectedProfile? detectedProfile,
    String? userName,
    Set<String>? permissionsGranted,
    bool? onboardingComplete,
    bool? isCaregiverMode,
    bool? isConfiguredByCaregiver,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      detectedProfile: detectedProfile ?? this.detectedProfile,
      userName: userName ?? this.userName,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isCaregiverMode: isCaregiverMode ?? this.isCaregiverMode,
      isConfiguredByCaregiver:
          isConfiguredByCaregiver ?? this.isConfiguredByCaregiver,
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
          isCaregiverMode == other.isCaregiverMode &&
          isConfiguredByCaregiver == other.isConfiguredByCaregiver &&
          permissionsGranted.length == other.permissionsGranted.length &&
          permissionsGranted.containsAll(other.permissionsGranted);

  @override
  int get hashCode => Object.hash(
        step,
        detectedProfile,
        userName,
        Object.hashAll(permissionsGranted),
        onboardingComplete,
        isCaregiverMode,
        isConfiguredByCaregiver,
      );

  @override
  String toString() =>
      'OnboardingState(step: $step, profile: ${detectedProfile?.profile}, '
      'caregiver: $isCaregiverMode, complete: $onboardingComplete)';
}
