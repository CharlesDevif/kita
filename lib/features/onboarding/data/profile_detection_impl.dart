import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../core/utils/logger.dart';
import '../domain/profile_detection.dart';

/// Resolves an [AccessibilityProfile] from raw platform features.
///
/// Priority: screenReader (blind) > largeText (lowVision) > general.
AccessibilityProfile resolveProfile({
  required bool screenReader,
  required bool largeText,
}) {
  if (screenReader) return AccessibilityProfile.blind;
  if (largeText) return AccessibilityProfile.lowVision;
  return AccessibilityProfile.general;
}

/// Whether the effective text scale exceeds the 1.3x threshold.
///
/// Uses [TextScaler.scale] on a base size of 16.0 to avoid the
/// deprecated `textScaleFactor` API.
bool isLargeTextScale(ui.FlutterView view) {
  // PlatformDispatcher gives us the view's devicePixelRatio-independent
  // text scale through the implicit view.
  final double scaledSize = view.platformDispatcher.textScaleFactor * 16.0;
  return scaledSize > 16.0 * 1.3;
}

/// Implementation of [ProfileDetection] backed by Flutter's
/// [AccessibilityFeatures] and [WidgetsBindingObserver].
///
/// Reads platform accessibility state synchronously via
/// [WidgetsBinding.instance.platformDispatcher] and emits dynamic
/// changes through a [StreamController].
class ProfileDetectionImpl
    with WidgetsBindingObserver
    implements ProfileDetection {
  ProfileDetectionImpl({
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;
  final _log = KitaLogger('ProfileDetection');
  final _controller = StreamController<DetectedProfile>.broadcast();
  bool _disposed = false;

  @override
  DetectedProfile detect() {
    final features = _binding.platformDispatcher.accessibilityFeatures;
    final view = _binding.platformDispatcher.implicitView;
    final largeText = view != null ? isLargeTextScale(view) : false;

    final detected = DetectedProfile(
      profile: resolveProfile(
        screenReader: features.accessibleNavigation,
        largeText: largeText,
      ),
      screenReader: features.accessibleNavigation,
      largeText: largeText,
      reduceMotion: features.reduceMotion,
      boldText: features.boldText,
      highContrast: features.highContrast,
    );

    _log.info('Profile detected: ${detected.profile.name}');
    return detected;
  }

  @override
  Stream<DetectedProfile> get onProfileChanged => _controller.stream;

  @override
  void didChangeAccessibilityFeatures() {
    if (_disposed) return;
    final updated = detect();
    _log.info('Accessibility features changed: ${updated.profile.name}');
    _controller.add(updated);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _binding.removeObserver(this);
    _controller.close();
    _log.info('Disposed');
  }
}
