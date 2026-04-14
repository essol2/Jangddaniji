import AVFoundation
import CoreImage
import Foundation
import QuartzCore
import UIKit

final class DiaryVideoService {
    static let shared = DiaryVideoService()
    private init() {}

    // MARK: - 클립 합산 + 시각 오버레이 내보내기

    func exportDiaryVideo(
        clipPaths: [String],
        dayRouteID: UUID
    ) async throws -> String {
        guard !clipPaths.isEmpty else { throw DiaryVideoError.noClips }

        let assets = clipPaths.compactMap { path -> (Int, AVAsset)? in
            let url = URL(fileURLWithPath: path)
            let hour = Int(url.deletingPathExtension().lastPathComponent) ?? 0
            let asset = AVURLAsset(url: url)
            return (hour, asset)
        }.sorted { $0.0 < $1.0 }

        guard !assets.isEmpty else { throw DiaryVideoError.noClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DiaryVideoError.compositionFailed
        }

        var currentTime = CMTime.zero
        var layerInstructions: [AVVideoCompositionLayerInstruction] = []
        var timeRanges: [(CMTimeRange, Int)] = [] // (range, hour)

        for (hour, asset) in assets {
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            if let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: srcVideoTrack, at: currentTime)

                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                let transform = try await srcVideoTrack.load(.preferredTransform)
                instruction.setTransform(transform, at: currentTime)
                layerInstructions.append(instruction)
            }

            if let srcAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: srcAudioTrack, at: currentTime)
            }

            timeRanges.append((CMTimeRange(start: currentTime, duration: duration), hour))
            currentTime = CMTimeAdd(currentTime, duration)
        }

        // 비디오 사이즈 결정
        let renderSize = CGSize(width: 1080, height: 1920)

        // 텍스트 오버레이 레이어 구성
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
        overlayLayer.isGeometryFlipped = true

        for (timeRange, hour) in timeRanges {
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(
                x: 0,
                y: renderSize.height * 0.4,
                width: renderSize.width,
                height: renderSize.height * 0.2
            )
            textLayer.string = String(format: "%02d:00", hour)
            textLayer.font = UIFont.boldSystemFont(ofSize: 120) as CFTypeRef
            textLayer.fontSize = 120
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.isWrapped = false
            textLayer.isGeometryFlipped = false

            // 배경 반투명
            let bgLayer = CALayer()
            bgLayer.frame = CGRect(
                x: 0,
                y: renderSize.height * 0.38,
                width: renderSize.width,
                height: renderSize.height * 0.24
            )
            bgLayer.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor

            // 클립 구간에만 표시
            let startTime = timeRange.start
            let endTime = CMTimeAdd(timeRange.start, timeRange.duration)

            let bgAnim = CAKeyframeAnimation(keyPath: "opacity")
            bgAnim.values = [0, 1, 1, 0]
            bgAnim.keyTimes = [
                NSNumber(value: startTime.seconds),
                NSNumber(value: startTime.seconds + 0.01),
                NSNumber(value: endTime.seconds - 0.01),
                NSNumber(value: endTime.seconds)
            ]
            bgAnim.duration = currentTime.seconds
            bgAnim.beginTime = AVCoreAnimationBeginTimeAtZero
            bgAnim.isRemovedOnCompletion = false
            bgAnim.fillMode = .both
            bgLayer.opacity = 0
            bgLayer.add(bgAnim, forKey: "opacity")
            overlayLayer.addSublayer(bgLayer)

            let textAnim = bgAnim.mutableCopy() as! CAKeyframeAnimation
            textLayer.opacity = 0
            textLayer.add(textAnim, forKey: "opacity")
            overlayLayer.addSublayer(textLayer)
        }

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.isGeometryFlipped = true

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        // VideoComposition 구성
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
        mainInstruction.layerInstructions = layerInstructions

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // 출력 경로
        let outputURL = diaryVideoURL(dayRouteID: dayRouteID)
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) else {
            throw DiaryVideoError.exportFailed
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = videoComposition

        await exporter.export()

        guard exporter.status == .completed else {
            throw exporter.error ?? DiaryVideoError.exportFailed
        }

        return outputURL.path
    }

    // MARK: - 파일 경로

    private func diaryVideoURL(dayRouteID: UUID) -> URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiaryVideos/\(dayRouteID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("diary.mp4")
    }
}

// MARK: - Error

enum DiaryVideoError: LocalizedError {
    case noClips
    case compositionFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noClips: return "촬영된 클립이 없습니다."
        case .compositionFailed: return "영상 합산에 실패했습니다."
        case .exportFailed: return "영상 내보내기에 실패했습니다."
        }
    }
}
