import CoreMedia
import Foundation

struct ReducedFrame {
    let width: Int
    let height: Int
    let luma: [UInt8]
}

struct VisualMotionMetrics: Codable, Equatable {
    let timestamp: TimeInterval
    let meanPeripheralMotion: Float
    let medianPeripheralMotion: Float
    let radialExpansion: Float
    let rotationProxy: Float
    let verticalMotion: Float
    let horizontalMotion: Float
    let lowTextureRatio: Float
    let repeatedFrameProbability: Float

    static let zero = VisualMotionMetrics(
        timestamp: 0,
        meanPeripheralMotion: 0,
        medianPeripheralMotion: 0,
        radialExpansion: 0,
        rotationProxy: 0,
        verticalMotion: 0,
        horizontalMotion: 0,
        lowTextureRatio: 1,
        repeatedFrameProbability: 1
    )
}

struct VisualCadenceMetrics: Codable, Equatable {
    let meanFrameIntervalMs: Float
    let p95FrameIntervalMs: Float
    let jitterScore: Float
    let repeatedFrameRatio: Float
    let visualCadenceRisk: Float

    static let stable = VisualCadenceMetrics(
        meanFrameIntervalMs: 0,
        p95FrameIntervalMs: 0,
        jitterScore: 0,
        repeatedFrameRatio: 0,
        visualCadenceRisk: 0
    )
}

struct MotionMetrics: Codable, Equatable {
    let timestamp: TimeInterval
    let visual: VisualMotionMetrics
    let cadence: VisualCadenceMetrics
    let optionalInputTurnScore: Float
    let sessionMinutes: Float
    let recentUserDiscomfort: Float?
}

struct MotionScoreResult: Codable, Equatable {
    let timestamp: TimeInterval
    let rawScore: Float
    let smoothedScore: Float
    let overlayStrength: OverlayStrength
}
