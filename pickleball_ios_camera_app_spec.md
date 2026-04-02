# Pickleball Camera App Spec Pack

## 1. Product Requirements Document (PRD)

### 1.1 Product Name
**Pickleball Trail Camera**

### 1.2 Goal
Build a very simple iOS camera app using **uni-app** that can:
- match the **iOS Camera app UI and interaction style** as closely as practical for v1
- provide exactly two capture modes: **Photo** and **Video**
- use interaction patterns that feel the same as the iOS Camera app for switching modes and capturing media
- take photos
- record video
- while recording video, detect a **pickleball** entering the camera view
- track the ball’s motion over time
- draw a **yellow trajectory trail** following the ball
- save photos and videos to the **iOS Photos album by default**
- save the recorded video with the trajectory overlay visible in playback/export

This document is optimized so an AI coding agent can implement the app with minimal ambiguity.

### 1.3 Target Platform trail** following the ball
- save photos and videos to the **iOS Photos album by default**
- save the recorded video with the trajectory overlay visible in playback/export

This document is optimized so an AI coding agent can implement the app with minimal ambiguity.

### 1.3 Target Platform
- **Primary platform:** iOS
- **Framework:** uni-app
- **Build target:** iPhone only for initial versio### 1.5 Core User Stories
1. As a user, I want to open the app and immediately see a camera interface that feels like the iOS Camera app.
2. As a user, I want to switch between **Photo** and **Video** modes like in the iOS Camera app.
3. As a user, I want the shutter and recording interactions to behave like the iOS Camera app.
4. As a user, I want captured photos to be saved to the Photos album by default.
5. As a user, I want recorded videos to be saved to the Photos album by default.
6. As a user, while video is recording, I want the app to detect a pickleball when it flies into frame.
7. As a user, I want the ball’s recent trajectory to be drawn behind it in **yellow**.
8. As a user, I want the saved video to include the visible yellow trail overlay.
9. As a user, I do not want complex controls like zoom, filters, editing, or account features.

### 1.6 Non-Goals for v1aDo **not** include:
- zoom in / zoom out
- multiple lenses selection
- manual exposure/focus controls
- slow motion mode
- replay editor
- object detection for anything other than the pickleball use case
- login/account/cloud sync
- Android support
- social sharing features
- advanced physics analysis or bounce prediction
- custom camera interaction patterns that differ from the iOS Camera app unless technically necessaryry### 1.7 Functional Requirements

#### FR-0 Camera UI and Mode Structure
- The main camera screen should visually and behaviorally resemble the **iOS Camera app** as closely as practical.
- There must be exactly **two modes** on the main capture interface:
  - `Photo`
  - `Video`
- Mode switching interaction should follow the iOS Camera app pattern as closely as practical in uni-app.
- The active mode must be visually clear.
- The capture button behavior must match the active mode:
  - in `Photo` mode, tapping the shutter captures a still image
  - in `Video` mode, tapping the record control starts/stops video recording
- The app should avoid adding extra visible controls that are not necessary for v1.

#### FR-1 Camera Previewt the saved video to include the visible yellow trail overlay.
9. As a user, I do not want complex controls like zoom, filters, editi#### FR-2 Photo Capture
- User can enter `Photo` mode and tap the shutter button to capture a still image.
- The photo capture interaction should feel like the iOS Camera app.
- The captured photo is saved to the app’s local storage first if needed by implementati#### FR-3 Video Recording
- User can enter `Video` mode and tap the record control to start recording.
- User can tap again to stop recording.
- The recording interaction and visual state should feel like the iOS Camera app.
- Recording state must be visually obvious.
- While recording, pickleball detection/tracking runs in near real time.
- The finished video must be saved to the **iOS Photos album by default**.
- If saving to Photos fails, the app should preserve the exported local file and notify the user.

#### FR-4 Pickleball Detectionfeatures
- advanced physics analysis or bounce prediction
- custom camera interaction patterns that differ from the iOS Camera app unless technically necessary

### 1.7 Functional Requirements

#### FR-0 Camera UI and Mode Structure
- The main camera screen should visually and behaviorally resemble the **iOS Camera app** as closely as practical.
- There must be exactly **two modes** on the main capture interface:
  - `Photo`
  - `Video`
- Mode switching interaction should follow the iOS Camera app pattern as closely as practical in uni-app.
- The active mode must be visually clear.
- The capture button behavior must match the active mode:
  - in `Photo` mode, tapping the shutter captures a still image
  - in `Video` mode, tapping the record control starts/stops video recording
- The app should avoid adding extra visible controls that are not necessary for v1.

#### FR-1 Camera Preview
- App launches directly into a live camera preview.
- Rear camera is default.
- Preview fills the main screen.
- No zoom controls.

#### FR-2 Photo Capture
- User can enter `Photo` mode and tap the shutter button to capture a still image.
- The photo capture interaction should feel like the iOS Camera app.
- The captured photo is saved to the app’s local storage first if needed by implementati#### FR-3 Video Recording
- User can enter `Video` mode and tap the record control to start recording.
- User can tap again to stop recording.
- The recording interaction and visual state should feel like the iOS Camera app.
- Recording state must be visually obvious.
- While recording, pickleball detection/tracking runs in near real time.
- The finished video must be saved to the **iOS Photos album by default**.
- If saving to Photos fails, the app should preserve the exported local file and notify the user.

#### FR-4 Pickleball Detectiontton to start recording.
- User c### 1.8 UX Requirements
- Very simple UI.
- The camera interface should mimic the **iOS Camera app** layout and interaction style as closely as practical.
- The main mode selector should show exactly two modes:
  - `PHOTO`
  - `VIDEO`
- The shutter/record control should behave like the iOS Camera app based on the selected mode.
- The active recording state must be visually obvious.
- No zoom UI.
- Do not add unnecessary extra controls.
- Save behavior should feel automatic and native: captured photos and finished videos should go to the Photos album by default.

### 1.9 Performance Requirementssmall fast-moving ball-like object.
- For v1, assume a single pickleball is the only target object.

#### FR-5 Trajectory Tracking
- Once the ball is detected, the app tracks the ball center point frame by frame.
- The trajectory is represented as a sequence of 2D screen coordinates.
- The trail should follow the historical motion of the ball.
- If the ball is lost briefly, the system may keep the last short track and attempt reacquisition.
- If the ball is lost for too long, tracking session resets.

#### FR-6 Trajectory Rendering
- The trajectory must be drawn as a **yellow line** behind the moving ball.
- Yellow should be vivid and highly visible.
- Recommended color: `#FFD400`.
- Tra### 1.11 Permissions
- Camera permission required.
- Microphone permission required for video recording with audio.
- Photo library permission required because photos and videos are saved to the iOS Photos album by default.

### 1.12 Success Criteria for v1.- User can capture a photo.
- User can record a video.
- The camera UI and interaction feel substantially like the iOS Camera app for Photo and Video modes.
- Captured photos are saved to the Photos album by default.
- Recorded videos are saved to the Photos album by default.
- During a recording, when a pickleball clearly enters frame, the app detects and tracks it for at least a short sequence.
- The saved video visibly includes a yellow trajectory behind the ball.
- The app remains stable during normal use., recording raw video plus synchronized tracking data and compositing a- uni-app iOS camera app
- camera UI modeled after the iOS Camera app
- exactly two modes: Photo and Video
- rear camera preview
- photo capture
- video recordingser can view the resulting video in a simple playback screen.
- After photo capture, user can view the photo in a simple preview screen.

### 1.8 UX Requirements
- Very simple UI.
- The camera interface should mimic the **iOS Camera app** layout and interaction style as closely as practical.
- The main mode selector should show exactly two modes:
  - `PHOTO`
  - `VIDEO`
- The shutter/record control should behave like the iOS Camera app based on the selected mode.
- The active recording state must be visually obvious.
- No zoom UI.
- Do not add unnecessary extra controls.
- Save behavior should feel automatic and native: captured photos and finished videos should go to the Photos album by default.

### 1.9 Performance Requirements
- Camera preview should feel responsive.
- During recording, tracking should run as smoothly as possible.
- Initial target performance:
  - preview: user-perceived real time
  - tracking processing: best effort, target 15–30 fps equivalent processing
- Video duration for v1 can be capped if needed for stability, for example 3–5 minutes max.

### 1.10 Accuracy Requirements
- v1 does not need perfect sports-analysis-grade accuracy.
- The goal is visually plausible trail rendering for a fun experience.
- The app should track obvious visible pickleball motion in good lighting.
- Edge cases such as motion blur, occlusion, background clutter, and similar ball-colored objects may fail in v1.

### 1.11 Permissions
- Camera permission required.
- Microphone permission required for video recording with audio.
- Photo library permission required because photos and videos are saved to the iOS Photos album by default.

### 1.12 Success Criteria for v1
- User can capture a photo.
- User can record a video.
- The camera UI and interaction feel substantially like the iOS Camera app for Photo and Video modes.
- Captured photos are saved to the Photos album by default.
- Recorded videos are saved to the Photos album by default.
- During a recording, when a pickleball clearly enters frame, the app detects and tracks it for at least a short sequence.
- The saved video visibly includes a yellow trajectory behind the ball.
- The app remains stable during normal use.

---

## 2. Product Scope Summary for AI Coding Agent

### Build This
- uni-app iOS camera app
- camera UI modeled after the iOS Camera app
- exactly two modes: Photo and Video
- rear camera preview
- photo capture
- video recording
- ball detection + tracking during video recording
- yellow trajectory overlay
- output video with overlay
- minimal review screens

### Do Not Build
- zoom
- advanced settings
- accounts
- cloud storage
- multi-object tracking
- Android version
- social features
- advanced analytics dashboard

---

## 3. Suggested Technical Approach

### 3.1 High-Level Architecture
Use a **hybrid architecture**:
1. **uni-app UI layer** for screens, buttons, permissions, and user flow
2. **native iOS plugin/module** for camera frame access and ball detection/tracking
3. **overlay renderer** to draw yellow path over preview
4. **video compositor/exporter** to burn the trajectory overlay into the saved video

Reason: pure cross-platform JS logic is likely not reliable enough for frame-by-frame### 4.1 Main Camera Screen
The main camera screen should visually and behaviorally mirror the standard iOS Camera app as closely as practical within product and technical constraints.

#### Elementsk- full-screen camera preview
- iOS-style mode selector with exactly two modes:
  - PHOTO
  - VIDEO
- iOS-style main capture control area
- optional thumbnail/review entry consistent with native camera feel
- overlay layer for yellow trajectory during video recordingco#### Behavior
- on launch, request permissions if needed
- if denied, show permission help state
- default to rear camera
- user can switch between PHOTO and VIDEO modes
- in PHOTO mode, tapping the shutter captures a photo
- in VIDEO mode, tapping the record control starts/stops recording
- media should be saved to the iOS Photos album by default
- pickleball tracking behavior remains unchanged and runs only during video recording

### 4.2 Recording Statesxporting video with the yellow trail burned in

### 3.3 Detection Strategy for v1
Use the simplest robust strategy first.

#### Option A: Motion + Color/Shape Heuristic
Good for v1 prototype if environment is controlled.
- Analyze video frames at a reduced processing resolution
- Detect moving blobs
- Filter candidates by:
  - approximate circular shape
  - small size range
  - yellow-green / light ball-like color range if helpful
  - motion continuity between frames
- Select the best candidate and track centroid

Pros:
- easier to prototype
- lower complexity

Cons:
- less robust in cluttered scenes

#### Option B: Small Custom Object Detector + Tracker
- Run a lightweight ball detector model every N frames
- Use optical flow or centroid tracking between detections

Pros:
- more robust

Cons:
- much more implementation complexity
- model packaging/training needed

### Decision for v1
Use **Option A first** unless the team already has a trained model.

### 3.4 Tracking Model
Track the ball as a stream of points:
- each point contains:
  - timestamp
  - frame index
  - x
  - y
  - confidence

Use:
- nearest-neighbor association from previous point
- optPurpose: live preview and capture with an iOS Camera-like interface.

**Components**
- Camera preview surface
- Overlay layer for yellow trajectory during video recording
- Mode selector with exactly two modes: PHOTO and VIDEO
- Main shutter / record control styled and behaving like the iOS Camera app
- Minimal status label only when needed0`
- Alpha: 1.0 for v1, or slightly faded for older segments if easy
- Width: 5 px default
- Join style: round
- Cap style: round
- Render only recent history window, e.g. last 1.5–2.0 seconds of points
- Smooth using line interpolation or quadratic path smoothing

### 3.6 Export Strategy
Recommended export pipeline:
1. Record raw video normally.
2. Save tracking points with timestamps during recording.
3. After recording stops, generate overlay frames/path timed to the recorded video.- Photos: `Allow Photos access to save captured photos and videos automatically.`Reason: easier and more reliable than trying to permanently burn overlay directly during live capture.

---

## 4. Detailed Functional Spec

### 4.1 Main Camera Screen
The main camera screen should visually and behaviorally mirror the standard iOS Camera app as closely as practical within product and technical constraints.

#### Elements
- full-screen camera preview
- iOS-style mode selector with exactly two modes:
  - PHOTO
  - VIDEO
- iOS-style main capture control area
- optional thumbnail/review entry consistent with native camera feel
- overlay layer for yellow trajectory during video recording

#### Behavior
- on launch, request permissions if needed
- if denied, show permission help state
- default to rear camera
- user can switch between PHOTO and VIDEO modes
- in PHOTO mode, tapping the shutter captures a photo
- in VIDEO mode, tapping the record control starts/stops recording
- media should be saved to the iOS Photos album by default
- pickleball tracking behavior remains unchanged and runs only during video recording

### 4.2 Recording States
- `idle`
- `recording`
- `processing_export`
- `review_ready`
- `error`

### 4.3 Tracking States
- `not_started`
- `searching`
- `tracking`
- `temporarily_lost`
- `lost`

### 4.4 Tracking Session Rules
- Tracking starts when video recording starts.
- The system processes frames continuously.
- Once a candidate ball is found with enough confidence, state becomes `tracking`.
- Append each tracked center point to the trajectory buffer.
- If confidence drops for a short duration, switch to `temporarily_lost`.
- If no reliable match is found for a threshold duration, clear current track and return to `searching`.

Suggested thresholds:
- temporary loss threshold: 0.3 seconds
- reset threshold: 1.0 second

### 4.5 Coordinate Space Rules
Be explicit about coordinate transforms.
- Detection may run on downscaled frame coordinates.
- Overlay draws in preview coordinates.
- Export draws in recorded video coordinates.

Therefore define mapping functions:
- `frameProcessingSpace -> previewSpace`
- `frameProcessingSpace -> outputVideoSpace`

All points must be stored with enough metadata to map accurately at export time.

---

## 5. Screens

### 5.1 Camera Screen
Purpose: live preview and capture

**Components**
- Camera preview surface
- Overlay layer for yellow trajectory
- Photo button
- Record button
- Status label

### 5.2 Media Review Screen
Purpose: view last captured photo or processed video

**For photo**
- display image
- back button

**For video**
- video player
- back button
- optional save/share button in future, but not required for v1

### 5.3 Permissions Screen / Empty State
Purpose: help user grant camera/mic access

---

## 6. UX Copy

### Permission Prompts
- Camera: `Allow camera access to capture photos and videos.`
- Microphone: `Allow microphone access to record video audio.`
- Photos optional: `Aedia.`

### Status Messages
- `Ready`
- `Recording...`
- `Tracking ball...`
- `Ball lost`
- `Processing video...`
- `Saved`
- `Permission required`

---

## 7. Dat"frameIndex": 0,
  "x": 0,
  "y": 0,
  "confidence": 0.0
}
```

### 7.2 RecordingSession
```json
{
  "id": "uuid",
  "videoFilePath": "string",
  "outputVideoFilePath": "string",
  "startedAt": 0,
  "endedAt": 0,
  "videoWidth": 0,
  "videoHeight": 0,
  "fps": 0,
  "trackPoints": []
}
```

### 7.3 DetectionCandidate
```json
{
  "x": 0,
  "y": 0,
  "radius": 0,
  "confidence": 0.0,
  "velocityX": 0.0,
  "velocityY": 0.0
}
```

---

## 8. Engineering Requirements

### 8.1 uni-app Layer Respo- capture photo
- save local file if needed by implementation
- save photo to iOS Photos album by default
- return file path / asset reference to uni-app
- show review screen i### 11.2 Video Flow
- start recording raw video
- record tracking data during capture
- stop recording
- process/export composited video with yellow trail
- save output video to iOS Photos album by default
- return output file path / asset reference
- show review screen

### 11.3 File Naminging track point timestamps
- exporting final composited video

### 8.3 API Boundary Between uni-app and Native Layer
Suggested bridge methods:
- `initCamera()`
- `startPreview()`
- `stopPreview()`
- `takePhoto()`
- `startRecording()`
- `stopRec- export failure
- saving to Photos album failure
- no ball detected during recordingte(callback)`
- `onRecordi### Expected Behavior
- show user-friendly error message
- do not crash
- if no ball detected, still save plain recorded video
- if overlay export fails, preserve raw video
- if saving to Photos fails, preserve the local media file and notify the user

## 13. Acceptance CriteriatPoints": [
    { "x": 118, "y": 350 },
    { "x": 119, "y": 345 },
    { "x": 120, "y": 340 }
  ]
}
```

---

## 9. Detection and Tra### AC-2 Photo Capture
- Given the user is on the camera screen in PHOTO mode,
- when the shutter button is tapped,
- then a photo is captured and sa### AC-3 Start/Stop Recording
- Given the user is on the camera screen in VIDEO mode,
- when the record control is tapped,
- then recording starts and recording UI is visible.
- When tapped again, recording stops and the output video is saved to the Photos album by default.

### AC-4 Ball Trackingwith existing track
7. Smooth point
8. Append point to trajectory buffer
9. Update live overlay

### 9.2 Candidate Filtering Heuristics
Filter by:
- area in acceptable range for a ball at likely distances
- roundness / circularity score
- motion magnitude above threshold
- continuity with previous known position
- optional color mask for pickleball-like hues

### 9.3 Reacquisition Logic
If track is lost:
- widen search area briefly
- continue searching whole frame
- if a plausible candidate reappears near predicted path, reconnect
- otherwise res### AC-7 No Zoom
- On the camera screen, no zoom in/out functionality is available.

### AC-8 iOS Camera-like Interaction
- The app provides exactly two modes: PHOTO and VIDEO.
- The camera UI and interaction model substantially match the iOS Camera app for these two modes.

---thing or moving average over recent points
- reject extreme outlier jumps unless consistent for 2 frames

Example:
```text
smoothedX = alpha * currentX + (1 - alpha) * previousSmoothedX
smoothedY = alpha * currentY + (1 - alpha) * previousSmoothedY
alpha = 0.6
```

---

## 10. Rendering Spec

### 10.1 Live Preview Overlay
- Draw on a dedicated overlay layer above the camera preview.
- Re-render whenever a new track point is added.
- Use only recent points to keep the trail short and clear.

### 10.2 Path Style
- stroke color: yellow `#FFD400`
- line width: 5
- line cap: round
- line join: round
- no fill

### 10.3 Trail Length
Recommended default:
- keep last `30` points or last `1.5` seconds of track data, whichever is easier to implement consistently

### 10.4 Optional Enhancement
- brighter dot on current ba- Prefer a native iOS plugin for detection/tracking/export rather than trying to do all frame processing in JavaScript.
- Keep uni-app responsible mainly for UI and flow.
- Replicate the iOS Camera app interaction model for PHOTO and VIDEO modes as closely as practical, but keep the pickleball tracking logic unchanged from the original spec.
### 11.2 Video Flow
- start recording raw video
- record tracking data during capture
- stop recording
- process/export composited video with yellow trail
- return outpue Naming
- photo: `photo_<timestamp>.jpg`
- raw--

## 12. Error Handling

### Cases
- camera permission denied
- microphone permission denied
- recording start failure
- export failure
- no ball detected during recording
- teria

### AC-1 Launch and Preview
- Given the user grants permissions,
- when the app launches,
- then the rear camera preview is shown.

### AC-2 Photo Capture
- Given the user is on the camera screen,
- when the photo button is tapped,
- then a photo is captured and shown in review.

### AC-3 Start/Stop Recording
- Given the user is on the camera screen,
- when the video button is tapped,
- then recording starts and recording UI is visible.
- When tapped again, recording sto## 17. Build Brief for Code-Generating AI

Use this brief directly with a coding model:

> Build an iOS-only camera app using uni-app. The app UI and interaction should match the iOS Camera app as closely as practical. The app must have exactly two modes: PHOTO and VIDEO. It should follow iOS system auto-rotation behavior. In PHOTO mode, tapping the shutter captures a photo. In VIDEO mode, tapping the record control starts and stops recording. Photos and videos must be saved to the iOS Photos album by default. Do not implement zoom. While video recording is active, the app must detect and track a pickleball when it flies into the camera view. Draw a yellow trajectory trail behind the ball in real time, and ensure the saved output video includes the same yellow trajectory overlay. Use a native iOS plugin/module for camera frame access, tracking, overlay rendering, saving to Photos, and export compositing, while keeping uni-app for UI, routing, and permissions. Use yellow color #FFD400 for the trajectory. If no ball is detected, still save the recorded video without failing.

--- video with pickleball crossing frame in good lighting
5. Verify yellow trail is shown live
6. Verify yellow trail exists in saved output video

### Edge Case Tests
1. Deny camera permission
2. Deny microphone permission
3. Start and stop recording quickly
4. Ball enters and exits frame very quickly
5. Ball partially occluded
6. Bright yellow objects in background
7. Fast motion blur
8. Long recording duration near cap
9. App goes background during recording

### Device Tests
- at least two modern iPhone models
- different lighting conditions

---

## 15. Implementation Notes for AI Coding Agent

### Important Guidance
- Prefer a native iOS plugin for detection/tracking/export rather than trying to do ## 20. Final v1 Decision Summary
This app should be treated as a **minimal iOS Camera-like app with a native sports-object tracking extension**. The simplest path is:
- uni-app for UI
- iOS native plugin for heavy camera/tracking work
- post-record export composition for reliable final overlay video
- standard normal camera mode, not portraiacking
- live yellow trail overlay

#### Milestone 4
- export video with burned-in trail
- review screen

---

## 16. Open Questions / Assumptions
For v1, assume:
1. only one pickleball needs tracking
2. follow iOS system auto-rotation behavior instead of portrait-only
3. rear camera only
4. normal-speed video only
5. yellow trail only
6. track rendering appears only during video recording, not photo capture
7. if tracking fails, raw video is still acceptable

---

## 17. Build Brief for Code-Generating AI

Use this brief directly with a coding model:

> Build an iOS-only camera app using uni-app. The app must have a very simple UI with a live rear camera preview, one photo capture button, and one video record toggle button. Do not implement zoom. While video recording is active, the app must detect and track a pickleball when it flies into the camera view. Draw a yellow trajectory trail behind the ball in real time, and ensure the saved output video includes the same yellow trajectory overlay. Use a native iOS plugin/module for camera frame access, tracking, overlay rendering, and export compositing, while keeping uni-app for UI, routing, and permissions. Use yellow color #FFD400 for the trajectory. If no ball is detected, still save the recorded video without failing.

---

## 18. Developer Task Breakdown

### Frontend / uni-app
- camera page UI
- state management
- permission prompts
- review pages
- native bridge integration

### Native iOS
- AVFoundation camera manager
- photo capture
- video recording manager
- frame processing pipeline
- ball detector/tracker
- overlay renderer
- export compositor

### QA
- permission tests
- recording stability
- detection tests with sample pickleball footage
- output video verification

---

## 19. Nice-to-Have Backlog (Not for v1)
- current ball highlight dot
- trajectory fade effect
- front camera support
- slow motion support
- clip trimming
- multiple color choices
- speed estimation
- bounce markers
- shot replay mode

---

## 20. Final v1 Decision Summary
This app should be treated as a **minimal camera app with a native sports-object tracking extension**. The simplest path is:
- uni-app for UI
- iOS native plugin for heavy camera/tracking work
- post-record export composition for reliable final overlay video
- standard normal camera mode, not portrait mode
- follow iOS system auto-rotation behavior rather than locking to portrait-only

That is the recommended implementation path for an AI coding agent.

