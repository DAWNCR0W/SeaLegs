import Foundation

final class MotionScoreEngine {
    private var smoothedScore: Float = 0
    private var lastTimestamp: TimeInterval?
    private let nominalFrameInterval: TimeInterval = 1.0 / 24.0

    func reset() {
        smoothedScore = 0
        lastTimestamp = nil
    }

    func update(metrics: MotionMetrics, config: OverlayConfig, emergencyActive: Bool) -> MotionScoreResult {
        let rawScore = computeRawScore(metrics)
        let previousTimestamp = lastTimestamp ?? metrics.timestamp - nominalFrameInterval
        let dt = Float(max(0.001, metrics.timestamp - previousTimestamp))
        let tau = rawScore > smoothedScore
            ? max(0.01, config.rampInSeconds)
            : max(0.01, config.rampOutSeconds)
        smoothedScore = ema(previous: smoothedScore, current: rawScore, dt: dt, tau: tau)
        lastTimestamp = metrics.timestamp

        var strength = map(score: smoothedScore, config: config)
        if emergencyActive {
            strength.opacity = max(strength.opacity, config.emergencyOpacity)
            strength.innerRadius = min(strength.innerRadius, config.emergencyInnerRadius)
        }

        return MotionScoreResult(
            timestamp: metrics.timestamp,
            rawScore: rawScore,
            smoothedScore: smoothedScore,
            overlayStrength: strength
        )
    }

    func computeRawScore(_ metrics: MotionMetrics) -> Float {
        let visual = metrics.visual
        let visualMotion = 0.45 * visual.meanPeripheralMotion
            + 0.20 * visual.rotationProxy
            + 0.15 * visual.radialExpansion
            + 0.10 * visual.verticalMotion
            + 0.10 * visual.horizontalMotion
        let visualConfidence = max(0.25, 1 - visual.lowTextureRatio)
        let cadenceRisk = metrics.cadence.visualCadenceRisk * visualConfidence
        let fatigue = clamp(metrics.sessionMinutes / 60) * 0.15
        let userRisk = clamp((metrics.recentUserDiscomfort ?? 0) / 20) * 0.20
        return clamp(
            0.62 * visualMotion
                + 0.18 * cadenceRisk
                + 0.10 * metrics.optionalInputTurnScore
                + fatigue
                + userRisk
        )
    }

    func map(score: Float, config: OverlayConfig) -> OverlayStrength {
        let t = smoothstep(0.18, 0.78, score)
        return OverlayStrength(
            opacity: mix(config.baseOpacity, config.maxOpacity, t),
            innerRadius: mix(config.restInnerRadius, config.motionInnerRadius, t)
        )
    }

    func ema(previous: Float, current: Float, dt: Float, tau: Float) -> Float {
        let alpha = 1 - exp(-dt / max(tau, 0.001))
        return previous + alpha * (current - previous)
    }
}
