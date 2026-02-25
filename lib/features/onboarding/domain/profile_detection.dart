/// Accessibility profile detection for automatic adaptation.
///
/// Detects OS accessibility features (VoiceOver/TalkBack, text scaling,
/// reduce motion, bold text, high contrast) and maps them to an
/// [AccessibilityProfile] for the onboarding flow.
library;

/// Detected accessibility profile category.
enum AccessibilityProfile {
  /// Screen reader active (VoiceOver/TalkBack/switch control).
  blind,

  /// Large text scaling (> 1.3x) without screen reader.
  lowVision,

  /// No accessibility features detected — general profile.
  general,
}

/// Snapshot of detected accessibility features and resolved profile.
class DetectedProfile {
  const DetectedProfile({
    required this.profile,
    required this.screenReader,
    required this.largeText,
    required this.reduceMotion,
    required this.boldText,
    required this.highContrast,
  });

  /// Pre-selected profile based on detected features.
  final AccessibilityProfile profile;

  /// Whether a screen reader (VoiceOver/TalkBack) is active.
  final bool screenReader;

  /// Whether text scale factor exceeds 1.3x.
  final bool largeText;

  /// Whether reduce-motion is requested by the OS.
  final bool reduceMotion;

  /// Whether bold text is requested by the OS.
  final bool boldText;

  /// Whether high contrast mode is active (iOS only).
  final bool highContrast;

  /// Default profile with no accessibility features detected.
  static const general = DetectedProfile(
    profile: AccessibilityProfile.general,
    screenReader: false,
    largeText: false,
    reduceMotion: false,
    boldText: false,
    highContrast: false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedProfile &&
          profile == other.profile &&
          screenReader == other.screenReader &&
          largeText == other.largeText &&
          reduceMotion == other.reduceMotion &&
          boldText == other.boldText &&
          highContrast == other.highContrast;

  @override
  int get hashCode => Object.hash(
        profile,
        screenReader,
        largeText,
        reduceMotion,
        boldText,
        highContrast,
      );

  @override
  String toString() =>
      'DetectedProfile(profile: $profile, screenReader: $screenReader, '
      'largeText: $largeText, reduceMotion: $reduceMotion, '
      'boldText: $boldText, highContrast: $highContrast)';
}

/// Interface for detecting OS accessibility features.
///
/// Implementations read platform accessibility settings and map them
/// to a [DetectedProfile]. Supports both one-shot detection at launch
/// and dynamic change monitoring.
abstract class ProfileDetection {
  /// Detect current accessibility features (one-shot).
  ///
  /// Should be called at app launch, before the first screen.
  DetectedProfile detect();

  /// Stream of profile changes when the user toggles
  /// accessibility features (e.g. enables VoiceOver mid-session).
  Stream<DetectedProfile> get onProfileChanged;

  /// Release resources (stream controller, binding observer).
  void dispose();
}
