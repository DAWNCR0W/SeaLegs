import Foundation

final class MotionAnalyzer {
    private let queue = DispatchQueue(label: "SeaLegs.motion.analyzer", qos: .userInitiated)
    private let estimator: BlockMotionEstimator
    private let cadenceEstimator: VisualCadenceEstimator
    private let scoreEngine: MotionScoreEngine
    private var previousFrame: ReducedFrame?
    private var sessionStartedAt = Date()
    private var recentUserDiscomfort: Float?
    var onResult: ((VisualMotionMetrics, VisualCadenceMetrics, MotionScoreResult, UUID) -> Void)?

    init(
        estimator: BlockMotionEstimator = BlockMotionEstimator(),
        cadenceEstimator: VisualCadenceEstimator = VisualCadenceEstimator(),
        scoreEngine: MotionScoreEngine = MotionScoreEngine()
    ) {
        self.estimator = estimator
        self.cadenceEstimator = cadenceEstimator
        self.scoreEngine = scoreEngine
    }

    func reset() {
        queue.sync {
            resetLocked(now: Date())
        }
    }

    func resetSession(now: Date = Date(), keepRecentDiscomfort: Bool = true) {
        queue.sync {
            resetLocked(now: now)
            if !keepRecentDiscomfort {
                recentUserDiscomfort = nil
            }
        }
    }

    func updateRecentDiscomfort(_ score: Int?) {
        queue.async { [weak self] in
            self?.recentUserDiscomfort = score.map(Float.init)
        }
    }

    func consume(
        frame: ReducedFrame,
        timestamp: TimeInterval,
        config: OverlayConfig,
        emergencyActive: Bool,
        optionalInputTurnScore: Float,
        generation: UUID
    ) {
        queue.async { [weak self] in
            self?.consumeLocked(
                frame: frame,
                timestamp: timestamp,
                config: config,
                emergencyActive: emergencyActive,
                optionalInputTurnScore: optionalInputTurnScore,
                generation: generation
            )
        }
    }

    private func resetLocked(now: Date) {
        previousFrame = nil
        sessionStartedAt = now
        cadenceEstimator.reset()
        scoreEngine.reset()
    }

    private func consumeLocked(
        frame: ReducedFrame,
        timestamp: TimeInterval,
        config: OverlayConfig,
        emergencyActive: Bool,
        optionalInputTurnScore: Float,
        generation: UUID
    ) {
        guard let previousFrame else {
            self.previousFrame = frame
            return
        }

        let visual = estimator.estimate(previous: previousFrame, current: frame, timestamp: timestamp)
        let cadence = cadenceEstimator.consume(timestamp: timestamp, repeatedFrameProbability: visual.repeatedFrameProbability)
        let metrics = MotionMetrics(
            timestamp: timestamp,
            visual: visual,
            cadence: cadence,
            optionalInputTurnScore: optionalInputTurnScore,
            sessionMinutes: Float(Date().timeIntervalSince(sessionStartedAt) / 60),
            recentUserDiscomfort: recentUserDiscomfort
        )
        let result = scoreEngine.update(metrics: metrics, config: config, emergencyActive: emergencyActive)
        self.previousFrame = frame
        onResult?(visual, cadence, result, generation)
    }
}

extension MotionAnalyzer: @unchecked Sendable {}
