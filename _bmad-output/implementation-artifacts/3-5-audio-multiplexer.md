# Story 3.5 : AudioMultiplexer — Multiplexage microphone

## Status: review

## Files created
- `lib/features/io/data/audio_service_impl.dart` — AudioMultiplexerImpl with STT/ambient modes
- `lib/features/io/data/providers/audio_providers.dart` — Riverpod provider
- `test/features/io/data/audio_service_impl_test.dart` — 12 tests (all pass)

## Key decisions
- 3 modes: idle, stt, ambient
- STT has priority — ambient is stopped when STT starts, resumed when STT stops
- Ambient can be queued while STT is active
- Uses MockSTTService in tests for full multiplexing behavior verification
