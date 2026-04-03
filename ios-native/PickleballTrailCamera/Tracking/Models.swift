import Foundation
import CoreGraphics

struct BallTrackPoint: Codable {
    var timestampMs: Int64
    var frameIndex: Int
    var x: CGFloat
    var y: CGFloat
    var confidence: CGFloat
}

struct RecordingSession {
    let id: UUID
    let videoFilePath: String
    var outputVideoFilePath: String?
    let startedAt: Int64
    var endedAt: Int64
    let videoWidth: Int
    let videoHeight: Int
    let fps: Int
    var trackPoints: [BallTrackPoint]
}
