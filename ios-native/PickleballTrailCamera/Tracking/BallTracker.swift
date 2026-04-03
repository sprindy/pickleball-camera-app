import Foundation
import CoreGraphics
import CoreImage

final class BallTracker {
    enum State: String { case notStarted, searching, tracking, temporarilyLost, lost }

    private(set) var state: State = .notStarted
    private(set) var points: [BallTrackPoint] = []
    private var lastPoint: CGPoint?
    private var lostSince: CFAbsoluteTime?
    private let maxPoints = 30

    func start() { state = .searching; points.removeAll(); lastPoint = nil; lostSince = nil }

    func process(frameIndex: Int, timestampMs: Int64, candidate: CGPoint?, confidence: CGFloat) {
        guard let candidate else {
            handleLoss()
            return
        }

        let smoothed: CGPoint
        if let last = lastPoint {
            smoothed = CGPoint(x: 0.6 * candidate.x + 0.4 * last.x, y: 0.6 * candidate.y + 0.4 * last.y)
        } else {
            smoothed = candidate
        }
        lastPoint = smoothed
        state = .tracking
        lostSince = nil

        points.append(BallTrackPoint(timestampMs: timestampMs, frameIndex: frameIndex, x: smoothed.x, y: smoothed.y, confidence: confidence))
        if points.count > maxPoints { points.removeFirst(points.count - maxPoints) }
    }

    private func handleLoss() {
        let now = CFAbsoluteTimeGetCurrent()
        if lostSince == nil { lostSince = now }
        let delta = now - (lostSince ?? now)
        state = delta > 1.0 ? .lost : .temporarilyLost
        if delta > 1.0 { lastPoint = nil }
    }
}
