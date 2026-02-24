/// Accessibility constraint tokens for WCAG 2.1 AA+ compliance.
///
/// These are absolute minimums — components can (and should) exceed them.
class KitaAccessibility {
  KitaAccessibility._();

  // --- Contrast Ratios ---

  /// Minimum contrast for normal text (WCAG AA)
  static const double contrastTextMin = 4.5;

  /// Minimum contrast for large text (WCAG AA)
  static const double contrastLargeTextMin = 3.0;

  /// Minimum contrast for UI components (WCAG AA)
  static const double contrastUIMin = 3.0;

  /// Target contrast for primary text (WCAG AAA)
  static const double contrastTextTarget = 7.0;

  // --- Touch Targets ---

  /// Minimum touch target size (WCAG)
  static const double touchTargetMin = 48.0;

  /// Recommended touch target for critical actions
  static const double touchTargetCritical = 56.0;

  /// Minimum spacing between touch targets
  static const double touchTargetSpacing = 8.0;

  // --- Text Sizes ---

  /// Minimum text size (never smaller)
  static const double textSizeMin = 14.0;

  /// Default body text size
  static const double textSizeBody = 16.0;

  /// Text scale factor range — user adjustable
  static const double textScaleMin = 0.8;
  static const double textScaleMax = 2.0;

  // --- Focus ---

  /// Focus indicator width
  static const double focusIndicatorWidth = 3.0;

  // --- Readability ---

  /// Line height multiplier for readable text
  static const double lineHeightMultiplier = 1.5;
}
