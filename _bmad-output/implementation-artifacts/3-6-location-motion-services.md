# Story 3.6 : LocationService et MotionService

## Status: review

## Files created
- `lib/features/io/data/location_service_impl.dart` — GPS via geolocator, geocoding, POIs (stub)
- `lib/features/io/data/motion_service_impl.dart` — Accelerometer via sensors_plus, rolling average classification
- `lib/features/io/data/providers/location_providers.dart`
- `lib/features/io/data/providers/motion_providers.dart`
- `test/features/io/data/location_service_impl_test.dart` — 6 tests
- `test/features/io/data/motion_service_impl_test.dart` — 8 tests

## Key decisions
- LocationService: GPS on demand only, maps geolocator.Position to domain Position
- MotionService: rolling average of 10 samples, thresholds configurable (immobile < 1.5, running > 5.0)
- getNearbyPOIs returns empty list (requires Places API, out of MVP scope)
- MissingPluginException caught explicitly for accelerometer
