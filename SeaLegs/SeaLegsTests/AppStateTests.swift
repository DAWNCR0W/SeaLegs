import XCTest
@testable import SeaLegs

@MainActor
final class AppStateTests: XCTestCase {
    func testDisplayedProfileKeepsManualPreviewSeparateFromDetectedGame() {
        let active = DefaultProfiles.customProfile(
            displayName: "Active",
            bundleIdentifier: "com.example.active",
            executableName: "Active",
            category: .racing
        )
        let preview = DefaultProfiles.customProfile(
            displayName: "Preview",
            bundleIdentifier: "com.example.preview",
            executableName: "Preview",
            category: .flightOrSpace
        )
        let state = AppState()
        state.profiles = [active, preview]
        state.activeProfile = active
        state.manualProfileID = preview.id

        XCTAssertEqual(state.activeProfile?.id, active.id)
        XCTAssertEqual(state.displayedProfile?.id, preview.id)
    }

    func testAdaptiveReadinessRejectsStaleSamples() {
        let state = AppState()
        let sampleTime = Date(timeIntervalSince1970: 1_000)
        state.currentMode = .adaptive
        state.permissionState.screenRecordingGranted = true
        state.captureModeDescription = "window filter"
        state.lastSampleReceivedAt = sampleTime
        state.refreshTimeBasedStatus(now: sampleTime.addingTimeInterval(2))

        XCTAssertEqual(state.captureReadinessDescription, "window filter")

        state.refreshTimeBasedStatus(now: sampleTime.addingTimeInterval(4))
        XCTAssertEqual(state.captureReadinessDescription, "Waiting for samples")
    }
}
