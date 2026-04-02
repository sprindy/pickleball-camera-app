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
