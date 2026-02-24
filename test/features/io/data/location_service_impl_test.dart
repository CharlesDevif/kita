import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/location_service_impl.dart';
import 'package:kita/features/io/domain/location_service.dart';

void main() {
  group('LocationServiceImpl', () {
    late LocationServiceImpl service;

    setUp(() {
      service = LocationServiceImpl();
    });

    test('implements LocationService interface', () {
      expect(service, isA<LocationService>());
    });

    test('isAvailable is true', () {
      expect(service.isAvailable, isTrue);
    });

    test('getCurrentPosition returns failure in test env', () async {
      // In test environment, geolocator has no platform channel
      final result = await service.getCurrentPosition();
      expect(result.isFailure, isTrue);
    });

    test('reverseGeocode returns failure in test env', () async {
      final result = await service.reverseGeocode(
        const Position(latitude: 48.8566, longitude: 2.3522),
      );
      expect(result.isFailure, isTrue);
    });

    test('getNearbyPOIs returns empty list (not yet implemented)', () async {
      final result = await service.getNearbyPOIs(
        const Position(latitude: 48.8566, longitude: 2.3522),
      );
      expect(result.isSuccess, isTrue);
      result.when(
        success: (pois) => expect(pois, isEmpty),
        failure: (_) => fail('Expected success'),
      );
    });

    test('getNearbyPOIs accepts custom radius', () async {
      final result = await service.getNearbyPOIs(
        const Position(latitude: 48.8566, longitude: 2.3522),
        radiusMeters: 1000,
      );
      expect(result.isSuccess, isTrue);
    });
  });
}
