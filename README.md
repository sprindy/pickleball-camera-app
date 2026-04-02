# Pickleball Trail Camera

iOS-only pickleball camera app implemented from [`pickleball_ios_camera_app_spec.md`](./pickleball_ios_camera_app_spec.md) as the source of truth.

## Implemented v1 Scope

- iOS Camera-like capture flow with exactly two modes: `PHOTO` and `VIDEO`
- Rear-camera live preview, iPhone target only, and system auto-rotation behavior
- Explicit no-zoom behavior (no zoom UI, rear camera locked to 1x)
- Photo capture and save to iOS Photos by default (`photo_<timestamp>.jpg` local copy retained)
- Video recording and save to iOS Photos by default (`video_raw_<timestamp>.mp4` local copy retained)
- Pickleball tracking during recording with tracking states:
  - `not_started`, `searching`, `tracking`, `temporarily_lost`, `lost`
- Live yellow trajectory overlay (`#FFD400`, width `5`, round cap/join, recent `30` points)
- Smoothed trail rendering in live preview and exported video
- Export with burned-in trail (`video_trail_<timestamp>.mp4`)
- Graceful fallback when no ball is detected: raw video is still saved and returned
- Graceful fallback when overlay export fails: raw video is preserved and returned

## Project Structure

- `pages/camera/index.vue`: uni-app camera page (PHOTO/VIDEO interaction, status, permissions, capture flow)
- `pages/review/index.vue`: simple media review screen with back control
- `utils/nativeBridge.js`: uni-app bridge to native plugin methods/events
- `nativeplugins/PickleballTracker/ios/Sources/PickleballTrackerModule.m`: native AVFoundation + Vision + overlay + export implementation
- `ios/PickleballCameraApp.xcodeproj`: standalone Xcode app wired to the same native module sources

## Bridge API (uni-app <-> native)

Methods:
- `initCamera(options, callback)`
- `startPreview(options, callback)`
- `stopPreview(options, callback)`
- `takePhoto(options, callback)`
- `startRecording(options, callback)`
- `stopRecording(options, callback)`
- `getRecordingStatus(options, callback)`
- `onTrackingUpdate(options, callback)`
- `onRecordingFinished(options, callback)`
- `exportVideoWithOverlay(options, callback)`

Events:
- `PickleballTrackingUpdate`
- `PickleballRecordingFinished`

## Standalone iOS Project Sync Notes

`ios/PickleballCameraApp.xcodeproj` remains synchronized with source and runtime requirements:

- Source refs include app files plus plugin sources from `../nativeplugins/PickleballTracker/ios/Sources`
- Build phases include `PickleballTrackerModule.m`
- Frameworks linked: `AVFoundation`, `Vision`, `Photos`, `UIKit`, `CoreMedia`, `CoreVideo`, `CoreGraphics`, `QuartzCore`
- `Info.plist` includes camera/mic/photos usage strings and rotation support

## Build Check (CLI)

```bash
xcodebuild -project ios/PickleballCameraApp.xcodeproj \
  -scheme PickleballCameraApp \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/pickleball-camera-derived \
  CODE_SIGNING_ALLOWED=NO build
```

## Runtime Permissions Copy

- Camera: `Allow camera access to capture photos and videos.`
- Microphone: `Allow microphone access to record video audio.`
- Photos: `Allow Photos access to save captured photos and videos automatically.`
