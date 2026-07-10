import AppKit
import CoreGraphics
import Foundation

final class PermissionManager {
    private let defaults: UserDefaults
    private let screenRecordingRequestedKey = "SeaLegs.screenRecordingRequested"
    private let inputMonitoringRequestedKey = "SeaLegs.inputMonitoringRequested"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentState(inputMonitoringEnabled: Bool = false) -> PermissionState {
        PermissionState(
            screenRecordingGranted: hasScreenRecordingAccess,
            screenRecordingRequested: hasScreenRecordingAccess || defaults.bool(forKey: screenRecordingRequestedKey),
            inputMonitoringRequested: hasInputMonitoringAccess || inputMonitoringEnabled || defaults.bool(forKey: inputMonitoringRequestedKey),
            inputMonitoringEnabled: hasInputMonitoringAccess && inputMonitoringEnabled,
            lastRefreshedAt: Date()
        )
    }

    var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    var hasInputMonitoringAccess: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    func requestScreenRecordingAccess() -> Bool {
        defaults.set(true, forKey: screenRecordingRequestedKey)
        return CGRequestScreenCaptureAccess()
    }

    @discardableResult
    func requestInputMonitoringAccess() -> Bool {
        defaults.set(true, forKey: inputMonitoringRequestedKey)
        return CGRequestListenEventAccess()
    }

    @discardableResult
    func openPrivacySettings() -> Bool {
        openScreenRecordingSettings()
    }

    @discardableResult
    func openScreenRecordingSettings() -> Bool {
        defaults.set(true, forKey: screenRecordingRequestedKey)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return openPrivacySecurityRoot()
        }
        if NSWorkspace.shared.open(url) {
            return true
        }
        return openPrivacySecurityRoot()
    }

    @discardableResult
    func openInputMonitoringSettings() -> Bool {
        defaults.set(true, forKey: inputMonitoringRequestedKey)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return openPrivacySecurityRoot()
        }
        if NSWorkspace.shared.open(url) {
            return true
        }
        return openPrivacySecurityRoot()
    }

    private func openPrivacySecurityRoot() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
