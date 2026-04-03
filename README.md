# Pickleball Trail Camera (uni-app + iOS native)

This implementation follows `pickleball_ios_camera_app_spec.md` as **source-of-truth**.

## What is implemented
- iOS-only uni-app pages:
  - `pages/camera/index.vue` (minimal camera UI: Photo / Record / Review)
  - `pages/review/index.vue` (photo/video review)
- Native bridge contract in `common/cameraBridge.js`:
  - `initCamera`, `startPreview`, `stopPreview`, `takePhoto`, `startRecording`, `stopRecording`, `getRecordingStatus`, `exportVideoWithOverlay`
- iOS native module implementation:
  - `ios-native/PickleballTrailCamera/Bridge/PickleballCameraBridge.swift`
  - `ios-native/PickleballTrailCamera/Tracking/*`
  - `ios-native/PickleballTrailCamera/Export/VideoOverlayExporter.swift`

## Spec-aligned behaviors
- Rear camera preview on launch
- Photo capture flow
- Video record start/stop with visible state
- Tracking state updates (`tracking`, `temporarilyLost`, `lost`)
- Yellow trail spec (`#FFD400`, width 5, round caps/joins)
- Export path uses raw video fallback when overlay output unavailable
- No zoom controls included

## Build/run (HBuilderX / uni-app iOS)
1. Open folder in HBuilderX.
2. Configure iOS App build and include native plugin source under `ios-native/` in your iOS target.
3. Ensure iOS permissions in Info.plist:
   - Camera: `Allow camera access to capture photos and videos.`
   - Microphone: `Allow microphone access to record video audio.`
   - Photos (optional): `Allow Photos access to save captured media.`
4. Run on iPhone.

## Sanity check
```bash
node scripts/check-structure.js
```

## Notes
- This codebase is intentionally minimal and spec-driven.
- `VideoOverlayExporter` now performs AVVideoComposition-based burn-in for the yellow trail, with graceful fallback to raw video path on export failure.
