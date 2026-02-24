import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/camera_service.dart';
import '../camera_service_impl.dart';

/// Provides the [CameraService] implementation.
///
/// Uses [keepAlive] so the camera controller persists across widget rebuilds.
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraServiceImpl();
  ref.onDispose(service.dispose);
  return service;
});
