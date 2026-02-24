import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kita_alert_plugin.dart';
import 'obstacle_detector.dart';

/// Provides an [ObstacleDetector] instance with managed lifecycle.
///
/// The detector is **not** initialized on creation — the caller must
/// call `initialize()` before using `detect()`.
///
/// The detector is disposed when the provider is destroyed.
final obstacleDetectorProvider = Provider<ObstacleDetector>((ref) {
  final detector = ObstacleDetector();
  ref.onDispose(() => unawaited(detector.dispose()));
  return detector;
});

/// Provides the [KitaAlertPlugin] agent instance.
///
/// Since KitaAlertPlugin was migrated to [KitaAgent], it no longer takes
/// constructor parameters. All services (TTS, haptics, profile adapter)
/// are injected via [AgentContext] at spawn time.
final kitaAlertPluginProvider = Provider<KitaAlertPlugin>((ref) {
  return KitaAlertPlugin();
});
