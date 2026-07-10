import XCTest
@testable import SeaLegs

final class MotionScoreEngineTests: XCTestCase {
    func testMotionScoreIsClampedToUnitRange() {
        let engine = MotionScoreEngine()
        let score = engine.computeRawScore(metrics(visual: .init(
            timestamp: 1,
            meanPeripheralMotion: 4,
            medianPeripheralMotion: 4,
            radialExpansion: 4,
            rotationProxy: 4,
            verticalMotion: 4,
            horizontalMotion: 4,
            lowTextureRatio: 0,
            repeatedFrameProbability: 0
        )))

        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func testAttackIsFasterThanRelease() {
        let engine = MotionScoreEngine()
        let config = DefaultProfiles.profile(for: .desktopFPS).overlay
        let high = metrics(timestamp: 1, visual: highVisual)
        let highResult = engine.update(metrics: high, config: config, emergencyActive: false)
        let lowResult = engine.update(metrics: metrics(timestamp: 1.12, visual: .zero), config: config, emergencyActive: false)

        XCTAssertGreaterThan(highResult.smoothedScore, lowResult.smoothedScore)
        XCTAssertGreaterThan(lowResult.smoothedScore, 0.05)
    }

    func testEmergencyOverridesOpacityAndRadius() {
        let engine = MotionScoreEngine()
        let config = DefaultProfiles.profile(for: .desktopFPS).overlay
        let result = engine.update(metrics: metrics(timestamp: 1, visual: .zero), config: config, emergencyActive: true)

        XCTAssertGreaterThanOrEqual(result.overlayStrength.opacity, config.emergencyOpacity)
        XCTAssertLessThanOrEqual(result.overlayStrength.innerRadius, config.emergencyInnerRadius)
    }

    func testProfileRampInControlsAdaptiveResponseSpeed() {
        var fastConfig = DefaultProfiles.profile(for: .desktopFPS).overlay
        fastConfig.rampInSeconds = 0.05
        var slowConfig = fastConfig
        slowConfig.rampInSeconds = 2

        let fast = MotionScoreEngine().update(
            metrics: metrics(timestamp: 1, visual: highVisual),
            config: fastConfig,
            emergencyActive: false
        )
        let slow = MotionScoreEngine().update(
            metrics: metrics(timestamp: 1, visual: highVisual),
            config: slowConfig,
            emergencyActive: false
        )

        XCTAssertGreaterThan(fast.smoothedScore, slow.smoothedScore)
    }

    func testProfileRampOutControlsAdaptiveReleaseSpeed() {
        var fastConfig = DefaultProfiles.profile(for: .desktopFPS).overlay
        fastConfig.rampInSeconds = 0.01
        fastConfig.rampOutSeconds = 0.05
        var slowConfig = fastConfig
        slowConfig.rampOutSeconds = 2

        let fastEngine = MotionScoreEngine()
        let slowEngine = MotionScoreEngine()
        _ = fastEngine.update(metrics: metrics(timestamp: 1, visual: highVisual), config: fastConfig, emergencyActive: false)
        _ = slowEngine.update(metrics: metrics(timestamp: 1, visual: highVisual), config: slowConfig, emergencyActive: false)

        let fast = fastEngine.update(metrics: metrics(timestamp: 1.2, visual: .zero), config: fastConfig, emergencyActive: false)
        let slow = slowEngine.update(metrics: metrics(timestamp: 1.2, visual: .zero), config: slowConfig, emergencyActive: false)

        XCTAssertLessThan(fast.smoothedScore, slow.smoothedScore)
    }

    func testUserDiscomfortRaisesBaseline() {
        let engine = MotionScoreEngine()
        let low = engine.computeRawScore(metrics(timestamp: 1, visual: .zero, discomfort: nil))
        let high = engine.computeRawScore(metrics(timestamp: 1, visual: .zero, discomfort: 20))

        XCTAssertGreaterThan(high, low)
    }

    private var highVisual: VisualMotionMetrics {
        VisualMotionMetrics(
            timestamp: 1,
            meanPeripheralMotion: 1,
            medianPeripheralMotion: 1,
            radialExpansion: 1,
            rotationProxy: 1,
            verticalMotion: 1,
            horizontalMotion: 1,
            lowTextureRatio: 0,
            repeatedFrameProbability: 0
        )
    }

    private func metrics(timestamp: TimeInterval = 1, visual: VisualMotionMetrics, discomfort: Float? = nil) -> MotionMetrics {
        MotionMetrics(
            timestamp: timestamp,
            visual: visual,
            cadence: VisualCadenceMetrics(meanFrameIntervalMs: 16, p95FrameIntervalMs: 20, jitterScore: 0.1, repeatedFrameRatio: 0, visualCadenceRisk: 0.1),
            optionalInputTurnScore: 0,
            sessionMinutes: 0,
            recentUserDiscomfort: discomfort
        )
    }
}
