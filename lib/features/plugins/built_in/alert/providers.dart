import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../io/data/providers/haptic_providers.dart';
import '../../../io/data/providers/tts_providers.dart';
import '../../../../shared/multi_modal/profile_adapter_provider.dart';
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

/// Provides the [KitaAlertPlugin] instance with injected dependencies.
///
/// Reads [ttsServiceProvider], [hapticServiceProvider], and
/// [profileAdapterProvider] to construct the plugin with all required
/// services for multi-modal alert output.
final kitaAlertPluginProvider = Provider<KitaAlertPlugin>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final haptic = ref.watch(hapticServiceProvider);
  final profileAdapter = ref.watch(profileAdapterProvider);
  return KitaAlertPlugin(
    ttsService: tts,
    hapticService: haptic,
    profileAdapter: profileAdapter,
  );
});
