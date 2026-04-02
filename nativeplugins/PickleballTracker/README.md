# PickleballTracker Native Plugin

Native iOS uni-app module providing:

- Rear camera preview (rear camera only, auto-rotation)
- Photo capture (`photo_<timestamp>.jpg`)
- Video recording (`video_raw_<timestamp>.mp4`)
- Real-time pickleball detection/tracking while recording (`VNDetectTrajectoriesRequest`)
- Live yellow trajectory overlay (`#FFD400`, width `5`, round joins/caps, last `30` points)
- Export compositing via `AVVideoComposition` to produce `video_trail_<timestamp>.mp4`
- Raw-video fallback path when no ball is detected

Minimum iOS target: `14.0`.

## Bridge API

- `initCamera(options, callback)`
- `startPreview(options, callback)`
- `stopPreview(options, callback)`
- `takePhoto(options, callback)`
- `startRecording(options, callback)`
- `stopRecording(options, callback)`
- `onTrackingUpdate(options, callback)`
- `onRecordingFinished(options, callback)`
- `exportVideoWithOverlay(options, callback)`
- Event: `PickleballTrackingUpdate`
- Event: `PickleballRecordingFinished`

## iOS Source

- `ios/Sources/PickleballTrackerModule.h`
- `ios/Sources/PickleballTrackerModule.m`
