import '../../../core/errors/result.dart';

class Position {
  const Position({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
}

class GeoAddress {
  const GeoAddress({
    this.street,
    this.city,
    this.country,
    this.postalCode,
    this.formattedAddress,
  });

  final String? street;
  final String? city;
  final String? country;
  final String? postalCode;
  final String? formattedAddress;
}

class POI {
  const POI({
    required this.name,
    required this.position,
    this.category,
    this.distance,
  });

  final String name;
  final Position position;
  final String? category;
  final double? distance;
}

abstract interface class LocationService {
  bool get isAvailable;
  Future<Result<Position>> getCurrentPosition();
  Future<Result<GeoAddress>> reverseGeocode(Position position);
  Future<Result<List<POI>>> getNearbyPOIs(
    Position position, {
    double radiusMeters = 500,
  });
}
