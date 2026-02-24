/// Animation duration tokens — coherent across the app.
///
/// Durees from UX spec:
/// - Micro interactions: 150ms (instant feedback)
/// - Transitions page/viewport: 300ms (passive -> active)
/// - State animations: 500ms (responding -> passive)
class KitaAnimationDurations {
  KitaAnimationDurations._();

  /// Micro-interactions: button feedback, acknowledgement
  static const Duration micro = Duration(milliseconds: 150);

  /// Screen transitions, viewport slide, orb resize
  static const Duration transition = Duration(milliseconds: 300);

  /// State animations: orb responding -> passive
  static const Duration state = Duration(milliseconds: 500);

  /// No animation (prefers-reduced-motion)
  static const Duration zero = Duration.zero;
}

/// Haptic intensity levels mapped to native APIs by HapticService (E3).
enum HapticIntensity {
  /// Light feedback — confirmation, acknowledgement
  light,

  /// Medium feedback — warning, attention
  medium,

  /// Heavy feedback — danger, critical alert
  heavy,
}

/// A haptic feedback pattern definition.
class HapticPattern {
  const HapticPattern({
    required this.intensity,
    required this.repetitions,
  });

  final HapticIntensity intensity;
  final int repetitions;
}

/// Predefined haptic patterns for multi-modal feedback.
///
/// HapticService (E3) implements the native platform calls.
class KitaHapticPatterns {
  KitaHapticPatterns._();

  /// Confirmation: 1 light vibration
  static const HapticPattern confirmation = HapticPattern(
    intensity: HapticIntensity.light,
    repetitions: 1,
  );

  /// Warning: 2 medium vibrations
  static const HapticPattern warning = HapticPattern(
    intensity: HapticIntensity.medium,
    repetitions: 2,
  );

  /// Danger: 3 heavy vibrations
  static const HapticPattern danger = HapticPattern(
    intensity: HapticIntensity.heavy,
    repetitions: 3,
  );

  /// Info: 1 light vibration
  static const HapticPattern info = HapticPattern(
    intensity: HapticIntensity.light,
    repetitions: 1,
  );
}
