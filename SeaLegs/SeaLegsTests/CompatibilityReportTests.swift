import XCTest

@testable import SeaLegs

@MainActor
final class CompatibilityReportTests: XCTestCase {
    func testReportIncludesOperationalStateWithoutRawApplicationData() {
        let state = AppState()
        state.activeProfile = DefaultProfiles.customProfile(
            displayName: "Private Game Name",
            bundleIdentifier: "com.private.game",
            executableName: "PrivateExecutable",
            executablePath: "/Users/private/Game",
            category: .desktopFPS
        )
        state.currentMode = .adaptive
        state.permissionState = PermissionState(
            screenRecordingGranted: true,
            screenRecordingRequested: true,
            inputMonitoringRequested: false,
            inputMonitoringEnabled: false,
            lastRefreshedAt: Date()
        )
        state.lastSampleReceivedAt = Date()
        state.overlayTargetDescription = "Game Window"
        let overlayState = OverlayState()
        overlayState.enabled = true

        let report = CompatibilityReportBuilder.make(
            state: state,
            overlayState: overlayState,
            selectedScope: .gameWindow,
            launchAtLoginStatus: .enabled,
            appVersion: "0.2.0",
            macOSVersion: "macOS test",
            now: Date()
        ).text

        XCTAssertTrue(report.contains("App Version: 0.2.0"))
        XCTAssertTrue(report.contains("Registered Game Active: yes"))
        XCTAssertTrue(report.contains("Adaptive Samples Fresh: yes"))
        XCTAssertFalse(report.contains("Private Game Name"))
        XCTAssertFalse(report.contains("com.private.game"))
        XCTAssertFalse(report.contains("PrivateExecutable"))
        XCTAssertFalse(report.contains("/Users/private/Game"))
    }
}
