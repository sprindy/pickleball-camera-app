# PickleballTracker Native Plugin

Native iOS uni-app module providing:

- Rear camera preview (rear camera only, auto-rotation)
- Photo capture (`photo_<timestamp>.jpg`)
- Video recording (`video_raw_<timestamp>.mp4`)
- Real-time pickleball detection/tracking while recording (`VNDetectTrajectoriesRequest`)
- Tracking states: `not_started`, `searching`, `tracking`, `temporarily_lost`, `lost`
- Live yellow trajectory overlay (`#FFD400`, width `5`, round joins/caps, last `30` points, smoothed path)
- Export compositing via `AVVideoComposition` to produce `video_trail_<timestamp>.mp4`
- Photos album save by default for captured photos and finished videos
- Raw-video fallback path when no ball is detected or overlay export fails

Minimum iOS target: `14.0`.

## Bridge API

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
- Event: `PickleballTrackingUpdate`
- Event: `PickleballRecordingFinished`

## iOS Source

- `ios/Sources/PickleballTrackerModule.h`
- `ios/Sources/PickleballTrackerModule.m`
