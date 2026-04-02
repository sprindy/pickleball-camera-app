# Pickleball Camera App

iOS-only pickleball camera app implemented per [`pickleball_ios_camera_app_spec.md`](./pickleball_ios_camera_app_spec.md).

## What This Build Implements

- Minimal camera UX with exactly two modes: `PHOTO` and `VIDEO`
- Rear-camera preview only
- No zoom control
- Photo capture
- Video start/stop record toggle
- Pickleball tracking while recording
- Live yellow trajectory overlay
  - color: `#FFD400`
  - line width: `5`
  - line cap/join: `round`
  - recent history window: last `30` points
- Export video with burned-in trail
- If no ball is detected, recording is still saved successfully (raw fallback path)
- Save photos/videos to iOS Photos album by default (local file retained if Photos save fails)

## Project Layout

- `pages/camera/index.vue`: uni-app camera UI (PHOTO/VIDEO mode + capture control)
- `pages/review/index.vue`: simple captured media review screen
- `utils/nativeBridge.js`: uni-app JS bridge to native module
- `nativeplugins/PickleballTracker/ios/Sources/PickleballTrackerModule.m`: native iOS camera, tracking, overlay, export, Photos save logic
- `ios/PickleballCameraApp.xcodeproj`: standalone native Xcode project for direct build/run

## Native Module Bridge API

- `initCamera(options, callback)`
- `startPreview(options, callback)`
- `stopPreview(options, callback)`
- `takePhoto(options, callback)`
- `startRecording(options, callback)`
- `stopRecording(options, callback)`
- `exportVideoWithOverlay(options, callback)`
- `onTrackingUpdate(options, callback)`
- `onRecordingFinished(options, callback)`

Events:

- `PickleballTrackingUpdate`
- `PickleballRecordingFinished`

## Exact Build And Test Steps (iPhone 15 Pro)

### A) Direct Xcode Run (standalone project under `ios/`)

1. Connect an iPhone 15 Pro by USB, unlock it, and trust this Mac.
2. Open `ios/PickleballCameraApp.xcodeproj` in Xcode.
3. Select target `PickleballCameraApp`.
4. In `Signing & Capabilities`, keep `Automatically manage signing` enabled.
5. Choose your Apple Team.
6. Set a unique bundle id if needed (default: `com.example.PickleballCameraApp`).
7. Select the run destination `iPhone 15 Pro`.
8. Build and run (`Cmd+R`).
9. On first launch, allow Camera, Microphone, and Photos permissions.
10. Test:
    - tap `PHOTO`, then capture: photo should save
    - tap `VIDEO`, start and stop recording: video should save
    - record with a visible pickleball in frame: live yellow trail should appear
    - replay saved video in Photos: burned-in yellow trail should be visible
    - record without a visible ball: video should still save successfully

### B) CLI Build Validation

From repo root:

```bash
xcodebuild -project ios/PickleballCameraApp.xcodeproj \
  -scheme PickleballCameraApp \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/pickleball-camera-derived \
  CODE_SIGNING_ALLOWED=NO build
```

## Notes

- Xcode project links required frameworks including `AVFoundation`, `Vision`, `Photos`, `UIKit`, `CoreMedia`, `CoreVideo`, `CoreGraphics`, and `QuartzCore`.
- `ios/PickleballCameraApp/Info.plist` includes camera/mic/photos usage descriptions required for direct run.
