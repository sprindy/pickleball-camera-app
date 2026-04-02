# Pickleball Camera App (uni-app + iOS Native Plugin)

iOS-only camera app built with uni-app for UI/routing and a native iOS plugin for AVFoundation capture, Vision trajectory detection, live trail rendering, and burned-in video export.

Minimum iOS target for the native plugin is `14.0`.

## Features

- Rear camera live preview
- Photo capture button
- Video record toggle
- No zoom support (camera locked at 1x)
- iOS auto-rotation
- During recording:
  - detect pickleball trajectory with Vision
  - draw live yellow trail (`#FFD400`, 5px, round cap/join, last 30 points)
- Export path:
  - raw recording: `video_raw_<timestamp>.mp4`
  - trail render export: `video_trail_<timestamp>.mp4`
  - if no ball is detected, video still exports successfully

## Structure

- `pages/camera/index.vue`: camera page UI and controls
- `pages/review/index.vue`: captured media review
- `utils/nativeBridge.js`: JS bridge to native plugin methods/events
- `nativeplugins/PickleballTracker`: iOS native module
  - `ios/Sources/PickleballTrackerModule.h`
  - `ios/Sources/PickleballTrackerModule.m`

## Native Plugin API

- `initCamera(options, callback)`
- `startPreview(options, callback)`
- `stopPreview(options, callback)`
- `takePhoto(options, callback)`
- `startRecording(options, callback)`
- `stopRecording(options, callback)`
- `onTrackingUpdate(options, callback)`
- `onRecordingFinished(options, callback)`
- `exportVideoWithOverlay(options, callback)`

## Events

- `PickleballTrackingUpdate`
- `PickleballRecordingFinished`

## Output Naming

- `photo_<timestamp>.jpg`
- `video_raw_<timestamp>.mp4`
- `video_trail_<timestamp>.mp4`

## Standalone Xcode Project (Direct Build/Run)

A standalone native iOS project is available at:

- `ios/PickleballCameraApp.xcodeproj`

It includes:

- app target: `PickleballCameraApp`
- plugin source integration from `nativeplugins/PickleballTracker/ios/Sources`
- linked frameworks: `AVFoundation`, `Vision`, `UIKit`, `CoreMedia`, `CoreVideo`, `CoreGraphics`, `QuartzCore`
- a native demo screen with buttons for preview, photo capture, recording, and trail-export

### Build/Run On iPhone 15 Pro (Xcode)

1. Connect your iPhone 15 Pro to your Mac and unlock it.
2. Open `ios/PickleballCameraApp.xcodeproj` in Xcode.
3. In Xcode, select target `PickleballCameraApp`.
4. Go to `Signing & Capabilities` and keep `Automatically manage signing` enabled.
5. Choose your Apple Developer Team from the `Team` dropdown.
6. If needed, change `Bundle Identifier` from `com.example.PickleballCameraApp` to a unique identifier under your team.
7. In the scheme/device picker, select your connected `iPhone 15 Pro`.
8. Press `Run` (`Cmd+R`).
9. On first launch, allow Camera and Microphone permissions.
10. Use the on-screen buttons to test `Init + Preview`, `Take Photo`, `Start Recording`, and `Stop Recording + Export`.

### Optional CLI validation

From repo root:

```bash
xcodebuild -project ios/PickleballCameraApp.xcodeproj \
  -scheme PickleballCameraApp \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/pickleball-camera-derived \
  CODE_SIGNING_ALLOWED=NO build
```
