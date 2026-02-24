import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'obstacle_detector.dart';

/// Provides an [ObstacleDetector] instance with managed lifecycle.
///
/// The detector is initialized on first access and disposed when
/// the provider is destroyed.
final obstacleDetectorProvider = Provider<ObstacleDetector>((ref) {
  final detector = ObstacleDetector();
  ref.onDispose(() async {
    await detector.dispose();
  });
  return detector;
});
