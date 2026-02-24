import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/location_service.dart';
import '../location_service_impl.dart';

/// Provides the [LocationService] implementation.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationServiceImpl();
});
