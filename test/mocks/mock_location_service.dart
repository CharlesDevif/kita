import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/location_service.dart';

class MockLocationService implements LocationService {
  bool shouldFail = false;

  @override
  bool get isAvailable => !shouldFail;

  @override
  Future<Result<Position>> getCurrentPosition() async {
    if (shouldFail) {
      return Result.failure(
        PermissionFailure.denied('location'),
      );
    }
    return const Result.success(
      Position(latitude: 48.8566, longitude: 2.3522, accuracy: 10.0),
    );
  }

  @override
  Future<Result<GeoAddress>> reverseGeocode(Position position) async {
    if (shouldFail) {
      return const Result.failure(
        NetworkFailure(
          userMessage: 'Impossible de localiser',
          logMessage: 'Geocoding failed',
        ),
      );
    }
    return const Result.success(
      GeoAddress(
        street: '5 Avenue Anatole France',
        city: 'Paris',
        country: 'France',
        postalCode: '75007',
        formattedAddress: '5 Avenue Anatole France, 75007 Paris, France',
      ),
    );
  }

  @override
  Future<Result<List<POI>>> getNearbyPOIs(
    Position position, {
    double radiusMeters = 500,
  }) async {
    if (shouldFail) return const Result.success([]);
    return const Result.success([
      POI(
        name: 'Tour Eiffel',
        position: Position(latitude: 48.8584, longitude: 2.2945),
        category: 'landmark',
        distance: 150.0,
      ),
    ]);
  }
}
