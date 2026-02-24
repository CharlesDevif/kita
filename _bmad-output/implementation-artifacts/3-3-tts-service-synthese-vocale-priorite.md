# Story 3.3 : TTSService — Synthese vocale avec file de priorite

## Status: review

## Files created
- `lib/features/io/data/tts_service_impl.dart` — TTSServiceImpl with SplayTreeSet priority queue
- `lib/features/io/data/providers/tts_providers.dart` — Riverpod provider
- `test/features/io/data/tts_service_impl_test.dart` — 10 tests (all pass)

## Key decisions
- Priority queue using SplayTreeSet (critical=0 > urgent=1 > standard=2)
- Critical messages interrupt lower-priority speech via `_tts.stop()` + re-queue
- `speak()` enqueues and returns immediately (fire-and-forget) — completion handler drives queue processing
- French language (`fr-FR`) as default
- flutter_tts method channel mocked in tests with `setMockMethodCallHandler`
