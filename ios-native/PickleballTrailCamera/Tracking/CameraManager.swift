import Foundation
import AVFoundation
import UIKit

final class CameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "pickleball.camera.video.queue")

    private let tracker = BallTracker()
    private var activeInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var pendingPhotoCompletion: (([String: Any]) -> Void)?

    private var frameIndex = 0
    private(set) var isRecording = false
    private var recordingStartedAtMs: Int64 = 0
    private var currentRawVideoPath: String?
    private var sessions: [String: RecordingSession] = [:]

    func initCameraHost(viewId: String?) {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }

        configureSessionIfNeeded()
        attachPreviewToRootView()
    }

    func startPreview() {
        configureSessionIfNeeded()
        if !captureSession.isRunning {
            videoQueue.async { [weak self] in self?.captureSession.startRunning() }
        }
    }

    func stopPreview() {
        if captureSession.isRunning {
            videoQueue.async { [weak self] in self?.captureSession.stopRunning() }
        }
    }

    func takePhoto(completion: @escaping ([String: Any]) -> Void) {
        pendingPhotoCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !isRecording else { return }
        configureSessionIfNeeded()
        tracker.start()
        frameIndex = 0
        recordingStartedAtMs = nowMs()

        let rawPath = NSTemporaryDirectory() + "video_raw_\(recordingStartedAtMs).mp4"
        currentRawVideoPath = rawPath
        let url = URL(fileURLWithPath: rawPath)
        try? FileManager.default.removeItem(at: url)

        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() -> RecordingSession {
        guard isRecording else {
            let now = nowMs()
            return RecordingSession(
                id: UUID(),
                videoFilePath: "",
                outputVideoFilePath: nil,
                startedAt: now,
                endedAt: now,
                videoWidth: 1920,
                videoHeight: 1080,
                fps: 30,
                trackPoints: []
            )
        }

        movieOutput.stopRecording()
        isRecording = false

        let endedAt = nowMs()
        let path = currentRawVideoPath ?? ""
        let videoSize = videoDimensions(path: path) ?? CGSize(width: 1920, height: 1080)
        let fps = videoFPS(path: path) ?? 30
        let session = RecordingSession(
            id: UUID(),
            videoFilePath: path,
            outputVideoFilePath: nil,
            startedAt: recordingStartedAtMs,
            endedAt: endedAt,
            videoWidth: Int(videoSize.width),
            videoHeight: Int(videoSize.height),
            fps: fps,
            trackPoints: tracker.points
        )
        sessions[session.id.uuidString] = session
        return session
    }

    func session(id: String) -> RecordingSession? { sessions[id] }

    // MARK: - Session setup

    private func configureSessionIfNeeded() {
        guard activeInput == nil else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // Video input (rear)
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let videoInput = try? AVCaptureDeviceInput(device: camera),
           captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            activeInput = videoInput
        }

        // Audio input
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
        }

        // Photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        // Frame processing output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if let conn = videoOutput.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        if let conn = movieOutput.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }

        captureSession.commitConfiguration()
    }

    private func attachPreviewToRootView() {
        DispatchQueue.main.async {
            guard let rootView = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController?.view else {
                return
            }

            if self.previewLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                layer.videoGravity = .resizeAspectFill
                layer.frame = rootView.bounds
                rootView.layer.insertSublayer(layer, at: 0)
                self.previewLayer = layer
            } else {
                self.previewLayer?.frame = rootView.bounds
            }
        }
    }

    // MARK: - Tracking

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        frameIndex += 1
        let timestamp = nowMs()

        let candidate = detectYellowCandidate(pixelBuffer: pixelBuffer)
        let confidence: CGFloat = candidate == nil ? 0.0 : 0.9
        tracker.process(frameIndex: frameIndex, timestampMs: timestamp, candidate: candidate, confidence: confidence)

        emitTrackingEvent()
    }

    private func detectYellowCandidate(pixelBuffer: CVPixelBuffer) -> CGPoint? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let ptr = base.assumingMemoryBound(to: UInt8.self)

        var sumX: Double = 0
        var sumY: Double = 0
        var count = 0

        let step = 4 // downsample for speed
        for y in stride(from: 0, to: height, by: step) {
            let row = ptr.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: step) {
                let px = row.advanced(by: x * 4)
                let b = Int(px[0])
                let g = Int(px[1])
                let r = Int(px[2])

                // Simple pickleball-ish yellow gate
                if r > 170 && g > 140 && b < 130 && abs(r - g) < 90 {
                    sumX += Double(x)
                    sumY += Double(y)
                    count += 1
                }
            }
        }

        guard count > 20 else { return nil }
        return CGPoint(x: sumX / Double(count), y: sumY / Double(count))
    }

    private func emitTrackingEvent() {
        let last = tracker.points.last
        let recent = tracker.points.suffix(30).map {
            ["x": $0.x, "y": $0.y, "confidence": $0.confidence]
        }

        let payload: [String: Any] = [
            "type": "trackingUpdate",
            "payload": [
                "state": tracker.state.rawValue,
                "currentPoint": last.map { ["x": $0.x, "y": $0.y, "confidence": $0.confidence] } ?? [:],
                "recentPoints": recent
            ]
        ]

        NotificationCenter.default.post(name: Notification.Name("PickleballCameraEvent"), object: nil, userInfo: payload)
    }

    // MARK: - Helpers

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func videoDimensions(path: String) -> CGSize? {
        guard !path.isEmpty else { return nil }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    private func videoFPS(path: String) -> Int? {
        guard !path.isEmpty else { return nil }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let fps = Int(round(track.nominalFrameRate))
        return fps > 0 ? fps : nil
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processFrame(sampleBuffer)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else {
            pendingPhotoCompletion?(["error": "photo capture failed"])
            pendingPhotoCompletion = nil
            return
        }

        let ts = nowMs()
        let path = NSTemporaryDirectory() + "photo_\(ts).jpg"
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            pendingPhotoCompletion?(["path": path])
        } catch {
            pendingPhotoCompletion?(["error": "failed to save photo"])
        }
        pendingPhotoCompletion = nil
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let _ = error {
            // Keep fallback behavior graceful; caller can still use path when present.
        }
    }
}
