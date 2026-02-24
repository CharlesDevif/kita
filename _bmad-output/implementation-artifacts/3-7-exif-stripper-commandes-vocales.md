# Story 3.7 : ExifStripper et commandes vocales

## Status: review

## Files created
- `lib/features/io/data/exif_stripper.dart` — Strips EXIF metadata using `image` package (decode + clear + re-encode)
- `lib/features/io/data/voice_command_handler.dart` — French voice command recognition with accent/case tolerance
- `test/features/io/data/exif_stripper_test.dart` — 6 tests
- `test/features/io/data/voice_command_handler_test.dart` — 18 tests

## Key decisions
- ExifStripper: decode -> exif.clear() -> re-encode as JPEG (quality 95)
- VoiceCommandHandler: 6 commands (decris, lis ca, stop, aide, merci, repete)
- Accent stripping for tolerance (e/e/e -> e)
- Case-insensitive matching
- Recognizes command even with trailing words ("decris ce que tu vois")
