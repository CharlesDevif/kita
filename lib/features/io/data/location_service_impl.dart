import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart' as geolocator;

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/location_service.dart';

/// Implementation of [LocationService] using `geolocator` and `geocoding`.
///
/// GPS is activated on demand only (not continuously by default).
class LocationServiceImpl implements LocationService {
  static final _log = KitaLogger('IO');

  @override
  bool get isAvailable => true;

  @override
  Future<Result<Position>> getCurrentPosition() async {
    try {
      final permission = await _checkPermission();
      if (permission.isFailure) {
        return Result.failure((permission as Failure<void>).failure);
      }

      final pos = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _log.info('Position acquired successfully');
      return Result.success(Position(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        accuracy: pos.accuracy,
      ));
    } catch (e, stack) {
      _log.error('Position acquisition failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Position acquisition failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<GeoAddress>> reverseGeocode(Position position) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        return const Result.success(GeoAddress());
      }

      final p = placemarks.first;
      return Result.success(GeoAddress(
        street: p.street,
        city: p.locality,
        country: p.country,
        postalCode: p.postalCode,
        formattedAddress: [p.street, p.locality, p.country]
            .where((s) => s != null && s.isNotEmpty)
            .join(', '),
      ));
    } catch (e, stack) {
      _log.error('Reverse geocoding failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Reverse geocoding failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<List<POI>>> getNearbyPOIs(
    Position position, {
    double radiusMeters = 500,
  }) async {
    // POI discovery requires a places API (Google Places, OpenStreetMap, etc.)
    // which is not in scope for the MVP. Return empty list for now.
    _log.debug('getNearbyPOIs called — not yet implemented');
    return const Result.success([]);
  }

  Future<Result<void>> _checkPermission() async {
    try {
      final serviceEnabled =
          await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Result.failure(
          PermissionFailure.denied('location_service_disabled'),
        );
      }

      var permission = await geolocator.Geolocator.checkPermission();
      if (permission == geolocator.LocationPermission.denied) {
        permission = await geolocator.Geolocator.requestPermission();
        if (permission == geolocator.LocationPermission.denied) {
          return Result.failure(PermissionFailure.denied('location'));
        }
      }

      if (permission == geolocator.LocationPermission.deniedForever) {
        return Result.failure(PermissionFailure.permanentlyDenied('location'));
      }

      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Location permission check failed',
          error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Location permission check failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }
}
