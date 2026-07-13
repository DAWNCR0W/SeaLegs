import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [GameProfile] = []
    @Published var language: AppLanguage = .system
    @Published var activeProfile: GameProfile?
    @Published var manualProfileID: UUID?
    @Published var selectedProfileID: UUID?
    @Published var currentApp: RunningAppInfo?
    @Published var currentMode: ComfortMode = .off
    @Published var permissionState: PermissionState = .unknown
    @Published var hotkeyRegistrations: [HotkeyRegistrationStatus] = HotkeyManager.defaultRegistrationStatuses
    @Published var debugHUDVisible = false
    @Published var overlayHUDMessage = "Ready"
    @Published var overlayHUDDetail = "Basic overlay available"
    @Published var overlayHUDVisible = false
    @Published var lastVisualMetrics: VisualMotionMetrics = .zero
    @Published var lastCadenceMetrics: VisualCadenceMetrics = .stable
    @Published var lastScoreResult: MotionScoreResult?
    @Published var lastSampleReceivedAt: Date?
    @Published private(set) var readinessReferenceDate = Date()
    @Published var lastSessionReport: SessionReport?
    @Published var captureModeDescription = "stopped"
    @Published var overlayTargetDescription = "Active Game Display"
    @Published var overlayTargetFallbackActive = false
    @Published var launchAtLoginStatus: LaunchAtLoginStatus = .notRegistered
    @Published var pendingProfileImport: ProfileImportPreview?
    @Published var compatibilityStatusMessage = "Compatibility check not run yet."
    @Published var statusMessage = "Ready"
    @Published var diagnosticsStatusMessage = "No diagnostics export yet."

    var currentGameName: String {
        activeProfile?.displayName ?? currentApp?.localizedName ?? "None"
    }

    var selectedProfile: GameProfile? {
        if let selectedProfileID,
           let selected = profiles.first(where: { $0.id == selectedProfileID }) {
            return selected
        }
        return activeProfile ?? profiles.first
    }

    var manualProfile: GameProfile? {
        guard let manualProfileID else {
            return nil
        }
        return profiles.first(where: { $0.id == manualProfileID })
    }

    var displayedProfile: GameProfile? {
        manualProfile ?? activeProfile ?? selectedProfile
    }

    var captureReadinessDescription: String {
        if !permissionState.screenRecordingGranted, currentMode == .adaptive {
            return "Screen Recording required"
        }
        if currentMode == .adaptive,
           lastSampleReceivedAt.map({ readinessReferenceDate.timeIntervalSince($0) <= 3 }) != true {
            return "Waiting for samples"
        }
        return captureModeDescription
    }

    func refreshTimeBasedStatus(now: Date = Date()) {
        readinessReferenceDate = now
    }
}
