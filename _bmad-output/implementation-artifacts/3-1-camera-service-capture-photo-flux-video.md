# Story 3.1 : CameraService — Capture photo et flux video

## Status: review

## Story (from epics.md)

As a **utilisateur de Kita**,
I want **que Kita puisse prendre une photo a la demande et streamer la video en continu**,
So that **le Plugin Describe peut capturer une photo et le Plugin Alert peut detecter des obstacles en temps reel**.

## Acceptance Criteria

- AC1: `CameraServiceImpl` implements `CameraService` interface (from E1 Story 1.7)
- AC2: `capturePhoto()` returns `Result<ImageData>` with a photo from the rear camera
- AC3: `startStream()` provides continuous video stream at 15-30 FPS (configurable)
- AC4: `stopStream()` stops the stream and releases resources
- AC5: Errors (permission denied, camera unavailable) return `Result.failure(PermissionFailure)`
- AC6: Uses the `camera` Flutter package (already in pubspec.yaml v0.11.4)
- AC7: Unit tests mock the camera controller and verify success/failure paths

## Technical Intelligence

### Package: camera ^0.11.4
- Uses `CameraController` for preview, photo capture, and image streaming
- `CameraController.initialize()` must be called before any operation
- `CameraController.takePicture()` returns `XFile` with path
- `CameraController.startImageStream()` provides `CameraImage` frames (YUV420/BGRA8888)
- `CameraController.stopImageStream()` stops streaming
- `availableCameras()` returns list of cameras — use `CameraLensDirection.back` for rear
- `ResolutionPreset` controls quality: use `medium` for stream (perf), `high` for photo
- Stream FPS controlled by camera hardware — no explicit FPS setter, but can throttle on Flutter side

### Platform considerations
- The `camera` package handles CameraX (Android) and AVFoundation (iOS) internally
- No need for custom platform channels — the package already bridges natively
- Architecture.md mentions `com.kita/camera` but the `camera` package provides its own channel
- We use the package API, not raw platform channels

### Key patterns from codebase
- `Result<T>` pattern from `lib/core/errors/result.dart`
- `KitaFailure` subclasses, especially `PermissionFailure` for camera access
- `ImageData` model from `lib/features/ai/domain/image_data.dart` (bytes, mimeType, width, height)
- `KitaLogger('IO')` for logging
- `runCatchingAsync` for wrapping async calls

## Tasks / Subtasks

1. **Create `CameraServiceImpl`** in `lib/features/io/data/camera_service_impl.dart`
   - Initialize camera controller on first use (lazy)
   - Handle camera lifecycle (initialize, dispose)
   - Implement `capturePhoto()` -> captures from rear camera -> converts to `ImageData`
   - Implement `startStream()` -> starts image stream -> converts frames -> calls callback
   - Implement `stopStream()` -> stops stream, keeps controller alive
   - FPS throttling for stream (configurable, default 15 FPS)

2. **Create Riverpod provider** in `lib/features/io/data/providers/camera_providers.dart`
   - `cameraServiceProvider` providing `CameraServiceImpl`

3. **Write unit tests** in `test/features/io/data/camera_service_impl_test.dart`
   - Test successful photo capture
   - Test permission denied error
   - Test camera unavailable error
   - Test stream start/stop
   - Test stream FPS throttling
   - Test `isAvailable` state

## Pitfalls & Gotchas

- `CameraController` must be initialized before use — guard all methods
- `startImageStream` and `takePicture` cannot run simultaneously on some devices
- Must stop image stream before taking a picture
- `CameraImage` format differs: YUV420 on Android, BGRA8888 on iOS
- Converting CameraImage to JPEG bytes is CPU-intensive — should be done only for capturePhoto, not every stream frame
- For stream frames, pass raw bytes as ImageData (for ML processing)
- Camera permissions must be requested BEFORE initializing controller
- `dispose()` must be called to release native resources

## Dev Agent Record

**Files created:**
- `lib/features/io/data/camera_service_impl.dart` — CameraServiceImpl with photo capture, FPS-throttled stream, error mapping
- `lib/features/io/data/providers/camera_providers.dart` — Riverpod provider with dispose lifecycle
- `test/features/io/data/camera_service_impl_test.dart` — 13 unit tests (all pass)

**Key decisions:**
- Used `camera` Flutter package (v0.11.4) instead of raw platform channels — package handles CameraX/AVFoundation internally
- FPS throttling implemented via DateTime comparison in stream callback (configurable, default 15)
- Stream frames use raw plane bytes (`image/raw`) for ML processing efficiency — no JPEG encoding per frame
- capturePhoto() auto-stops stream if active (hardware constraint: cannot stream and capture simultaneously)
- Lazy initialization pattern — controller created on first use
- CameraException codes mapped to PermissionFailure (access denied) or UnexpectedFailure

**Lint:** `dart analyze --fatal-infos` clean
**Tests:** 13/13 passing
