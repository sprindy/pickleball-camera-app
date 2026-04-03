import Foundation
import AVFoundation
import CoreImage
import UIKit

enum VideoOverlayExporter {
    static func export(session: RecordingSession, completion: @escaping (String?) -> Void) {
        guard !session.videoFilePath.isEmpty else {
            completion(nil)
            return
        }

        let inputURL = URL(fileURLWithPath: session.videoFilePath)
        let asset = AVURLAsset(url: inputURL)

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(nil)
            return
        }

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video,
                                                               preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil)
            return
        }

        do {
            try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration),
                                               of: videoTrack,
                                               at: .zero)
            compVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            completion(nil)
            return
        }

        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                            preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration),
                                                of: audioTrack,
                                                at: .zero)
        }

        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let renderSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        let startMs = session.startedAt

        let videoComposition = AVVideoComposition(asset: composition) { request in
            let source = request.sourceImage.clampedToExtent()
            let tMs = Int64(CMTimeGetSeconds(request.compositionTime) * 1000.0) + startMs
            let minMs = tMs - 1500

            let points = session.trackPoints.filter { $0.timestampMs >= minMs && $0.timestampMs <= tMs }
            guard points.count >= 2 else {
                request.finish(with: source.cropped(to: request.sourceImage.extent), context: nil)
                return
            }

            let overlay = makeOverlayImage(points: points,
                                           renderSize: renderSize,
                                           sourceExtent: request.sourceImage.extent)
            if let overlay {
                let composited = overlay.composited(over: source).cropped(to: request.sourceImage.extent)
                request.finish(with: composited, context: nil)
            } else {
                request.finish(with: source.cropped(to: request.sourceImage.extent), context: nil)
            }
        }
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(max(session.fps, 30)))

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory() + "video_trail_\(Int(Date().timeIntervalSince1970 * 1000)).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }

        exporter.videoComposition = videoComposition
        exporter.outputFileType = .mp4
        exporter.outputURL = outputURL
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(outputURL.path)
                } else {
                    completion(nil)
                }
            }
        }
    }

    private static func makeOverlayImage(points: [BallTrackPoint],
                                         renderSize: CGSize,
                                         sourceExtent: CGRect) -> CIImage? {
        guard renderSize.width > 0, renderSize.height > 0 else { return nil }

        UIGraphicsBeginImageContextWithOptions(renderSize, false, 1)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setStrokeColor(UIColor(red: 1.0, green: 0.831, blue: 0.0, alpha: 1.0).cgColor) // #FFD400
        ctx.setLineWidth(5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        guard let first = points.first else { return nil }
        ctx.move(to: convert(point: first, renderSize: renderSize, sourceExtent: sourceExtent))
        for p in points.dropFirst() {
            ctx.addLine(to: convert(point: p, renderSize: renderSize, sourceExtent: sourceExtent))
        }
        ctx.strokePath()

        guard let image = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = image.cgImage else {
            return nil
        }
        return CIImage(cgImage: cgImage)
    }

    private static func convert(point: BallTrackPoint, renderSize: CGSize, sourceExtent: CGRect) -> CGPoint {
        let sourceW = sourceExtent.width > 0 ? sourceExtent.width : renderSize.width
        let sourceH = sourceExtent.height > 0 ? sourceExtent.height : renderSize.height
        let sx = renderSize.width / sourceW
        let sy = renderSize.height / sourceH

        // Pixel buffer origin is top-left for our processing assumption.
        // CoreGraphics draw space is also top-left in UIGraphics image context.
        return CGPoint(x: point.x * sx, y: point.y * sy)
    }
}
