import XCTest
@testable import SeaLegs

@MainActor
final class OverlayStateMappingTests: XCTestCase {
    func testStaticLowMediumHighMappingIncreasesOpacity() {
        let config = DefaultProfiles.profile(for: .desktopFPS).overlay

        let low = config.staticStrength(for: .low)
        let medium = config.staticStrength(for: .medium)
        let high = config.staticStrength(for: .high)

        XCTAssertLessThan(low.opacity, medium.opacity)
        XCTAssertLessThan(medium.opacity, high.opacity)
        XCTAssertGreaterThan(low.innerRadius, medium.innerRadius)
        XCTAssertGreaterThan(medium.innerRadius, high.innerRadius)
    }

    func testOverlayStateAppliesGuideConfig() {
        let state = OverlayState()
        let config = DefaultProfiles.profile(for: .flightOrSpace).overlay

        state.apply(config: config, mode: .high)

        XCTAssertTrue(state.centerDotEnabled)
        XCTAssertTrue(state.horizonEnabled)
        XCTAssertTrue(state.peripheralFrameEnabled)
        XCTAssertEqual(state.vignetteOuterRadius, config.outerRadius)
    }

    func testEmergencyAppliesStrongerVignette() {
        let state = OverlayState()
        let config = DefaultProfiles.profile(for: .racing).overlay

        state.emergencyActive = true
        state.apply(config: config, mode: .low)

        XCTAssertGreaterThanOrEqual(state.vignetteOpacity, config.emergencyOpacity)
        XCTAssertLessThanOrEqual(state.vignetteInnerRadius, config.emergencyInnerRadius)
        XCTAssertGreaterThanOrEqual(state.horizonOpacity, 0.32)
    }

    func testDefaultProfilesExposeVisibleAnchors() {
        for profile in DefaultProfiles.all {
            XCTAssertGreaterThanOrEqual(profile.overlay.visibleAnchorCount, 2, profile.displayName)
        }
    }

    func testHighVisibilityDemoEnablesEveryVisualAid() {
        let demo = DefaultProfiles.profile(for: .general3D).overlay.highVisibilityDemo()

        XCTAssertEqual(demo.mode, .high)
        XCTAssertEqual(demo.visibleAnchorCount, 6)
        XCTAssertGreaterThanOrEqual(demo.centerDot.opacity, 0.5)
        XCTAssertGreaterThanOrEqual(demo.maxOpacity, 0.62)
        XCTAssertLessThanOrEqual(demo.motionInnerRadius, 0.60)
    }

    func testGuideMotionOptionsAffectRenderedOpacity() {
        var config = DefaultProfiles.profile(for: .desktopFPS).overlay
        config.centerDot.hideWhenIdle = true
        config.centerDot.autoBoostInMotion = true
        let state = OverlayState()

        state.apply(config: config, strength: OverlayStrength(opacity: config.baseOpacity, innerRadius: config.restInnerRadius))
        let idleOpacity = state.centerDotOpacity
        state.apply(config: config, strength: OverlayStrength(opacity: config.maxOpacity, innerRadius: config.motionInnerRadius))

        XCTAssertEqual(idleOpacity, 0, accuracy: 0.001)
        XCTAssertGreaterThan(state.centerDotOpacity, config.centerDot.opacity)
    }
}
