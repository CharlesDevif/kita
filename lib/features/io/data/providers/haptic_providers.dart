import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/haptic_service.dart';
import '../haptic_service_impl.dart';

/// Provides the [HapticService] implementation.
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticServiceImpl();
});
