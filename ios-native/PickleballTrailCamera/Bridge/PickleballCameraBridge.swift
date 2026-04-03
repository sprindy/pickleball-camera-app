import Foundation
import AVFoundation
import UIKit

@objc(PickleballCameraBridge)
class PickleballCameraBridge: NSObject {
    private let manager = CameraManager()

    @objc func initCamera(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        manager.initCameraHost(viewId: params["viewId"] as? String)
        callback(["ok": true])
    }

    @objc func startPreview(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        manager.startPreview()
        callback(["ok": true])
    }

    @objc func stopPreview(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        manager.stopPreview()
        callback(["ok": true])
    }

    @objc func takePhoto(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        manager.takePhoto { result in callback(result as NSDictionary) }
    }

    @objc func startRecording(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        manager.startRecording()
        callback(["ok": true])
    }

    @objc func stopRecording(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        let session = manager.stopRecording()
        callback(["sessionId": session.id.uuidString, "rawVideoPath": session.videoFilePath])
    }

    @objc func exportVideoWithOverlay(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        guard let id = params["sessionId"] as? String, let session = manager.session(id: id) else {
            callback(["error": "invalid sessionId"])
            return
        }
        VideoOverlayExporter.export(session: session) { outputPath in
            callback(["outputPath": outputPath ?? session.videoFilePath])
        }
    }

    @objc func getRecordingStatus(_ params: NSDictionary, callback: @escaping (NSDictionary) -> Void) {
        callback(["recording": manager.isRecording])
    }
}
