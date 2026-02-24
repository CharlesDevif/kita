import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/motion_service.dart';
import '../motion_service_impl.dart';

/// Provides the [MotionService] implementation.
final motionServiceProvider = Provider<MotionService>((ref) {
  final service = MotionServiceImpl();
  ref.onDispose(service.stopMonitoring);
  return service;
});
