# Story 3.2 : STTService — Reconnaissance vocale locale

## Status: review

## Story (from epics.md)

As a **utilisateur de Kita**,
I want **que Kita transcrive ma voix en texte en < 200ms**,
So that **je peux donner des commandes vocales naturellement**.

## Acceptance Criteria

- AC1: `STTServiceImpl` implements `STTService` interface (from E1)
- AC2: `startRecognition()` begins transcription, emits stream of partial results
- AC3: `stopRecognition()` stops transcription
- AC4: Default language is French
- AC5: Errors (mic permission denied) return `Result.failure(PermissionFailure)`
- AC6: Unit tests verify success/permission-denied paths

## Technical Intelligence

### Package: speech_to_text ^7.3.0
- `SpeechToText().initialize()` must be called first, returns bool
- `SpeechToText().listen(onResult:, localeId:, listenOptions:)` starts listening
- `SpeechToText().stop()` stops listening (waits for final result)
- `SpeechToText().cancel()` cancels (no final result)
- `SpeechListenOptions(partialResults: true, onDevice: true)` for local processing
- French locale: `fr_FR` or `fr-FR` depending on platform
- `isAvailable` and `isListening` getters available

## Tasks
1. Create `STTServiceImpl` in `lib/features/io/data/stt_service_impl.dart`
2. Create Riverpod provider in `lib/features/io/data/providers/stt_providers.dart`
3. Write tests in `test/features/io/data/stt_service_impl_test.dart`

## Dev Agent Record

**Files created:**
- `lib/features/io/data/stt_service_impl.dart` — STTServiceImpl with lazy init, French locale, partial results
- `lib/features/io/data/providers/stt_providers.dart` — Riverpod provider
- `test/features/io/data/stt_service_impl_test.dart` — 8 tests (all pass)

**Key decisions:**
- Uses `speech_to_text` package (v7.3.0) with `SpeechListenOptions(onDevice: true)` for local processing
- Default locale `fr_FR` for French recognition
- Lazy initialization pattern (init on first use)
- `ListenMode.confirmation` for voice commands (short phrases)

**Lint:** clean, **Tests:** 8/8 passing
