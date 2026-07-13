import Foundation

struct CompatibilityReportSnapshot: Equatable {
    let appVersion: String
    let macOSVersion: String
    let registeredGameActive: Bool
    let selectedScope: OverlayDisplayScope
    let resolvedTarget: String
    let fallbackActive: Bool
    let overlayEnabled: Bool
    let currentMode: ComfortMode
    let screenRecordingGranted: Bool
    let adaptiveSamplesFresh: Bool
    let captureReadiness: String
    let launchAtLoginStatus: LaunchAtLoginStatus

    var text: String {
        [
            "SeaLegs Compatibility Report",
            "App Version: \(appVersion)",
            "macOS: \(macOSVersion)",
            "Registered Game Active: \(yesNo(registeredGameActive))",
            "Selected Overlay Scope: \(selectedScope.rawValue)",
            "Resolved Overlay Target: \(resolvedTarget)",
            "Fallback Active: \(yesNo(fallbackActive))",
            "Overlay Enabled: \(yesNo(overlayEnabled))",
            "Comfort Mode: \(currentMode.rawValue)",
            "Screen Recording Granted: \(yesNo(screenRecordingGranted))",
            "Adaptive Samples Fresh: \(yesNo(adaptiveSamplesFresh))",
            "Capture Readiness: \(captureReadiness)",
            "Launch at Login: \(launchAtLoginStatus.rawValue)",
            "Privacy: no screenshots, frames, raw paths, window titles, or raw application identifiers included.",
        ].joined(separator: "\n")
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

enum CompatibilityReportBuilder {
    @MainActor
    static func make(
        state: AppState,
        overlayState: OverlayState,
        selectedScope: OverlayDisplayScope,
        launchAtLoginStatus: LaunchAtLoginStatus,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        macOSVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        now: Date = Date()
    ) -> CompatibilityReportSnapshot {
        let samplesFresh = state.lastSampleReceivedAt.map { now.timeIntervalSince($0) <= 3 } == true
        return CompatibilityReportSnapshot(
            appVersion: appVersion,
            macOSVersion: macOSVersion,
            registeredGameActive: state.activeProfile != nil,
            selectedScope: selectedScope,
            resolvedTarget: state.overlayTargetDescription,
            fallbackActive: state.overlayTargetFallbackActive,
            overlayEnabled: overlayState.enabled,
            currentMode: state.currentMode,
            screenRecordingGranted: state.permissionState.screenRecordingGranted,
            adaptiveSamplesFresh: samplesFresh,
            captureReadiness: state.captureReadinessDescription,
            launchAtLoginStatus: launchAtLoginStatus
        )
    }
}
