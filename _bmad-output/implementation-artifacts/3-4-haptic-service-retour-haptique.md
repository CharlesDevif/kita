# Story 3.4 : HapticService — Retour haptique differencie

## Status: review

## Files created
- `lib/features/io/data/haptic_service_impl.dart` — Platform channel `com.kita/haptic` with fallback to HapticFeedback
- `lib/features/io/data/providers/haptic_providers.dart` — Riverpod provider
- `test/features/io/data/haptic_service_impl_test.dart` — 11 tests (all pass)

## Key decisions
- Uses `com.kita/haptic` platform channel with `triggerPattern` method
- Falls back to Flutter's `HapticFeedback` (light/medium/heavy) when channel unavailable
- 5 patterns: info, warning, danger, confirmation, custom
- Haptic is non-critical — fallback returns success even on failure
- Platform channel mocked in tests to verify correct arguments
