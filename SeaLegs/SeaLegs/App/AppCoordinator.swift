import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: ObservableObject {
    let state = AppState()
    let overlayState = OverlayState()
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AppCoordinator")
    private let profileStore: ProfileStore
    private let permissionManager: PermissionManager
    private let gameDetector: GameDetector
    private let windowInfoProvider: WindowInfoProvider
    private let overlayManager: OverlayManager
    private let launchAtLoginService: LaunchAtLoginControlling
    private let hotkeyManager: HotkeyManager
    private let optionalInputMonitor: OptionalInputMonitor
    private let controllerMonitor: GameControllerMonitor
    private let motionAnalyzer: MotionAnalyzer
    private let runtimeServicesEnabled: Bool
    private let captureSignals = CaptureRuntimeSignals()
    private var appSettings: AppSettings = .standard
    private lazy var sessionLogger = SessionLogger(sessionsURL: profileStore.sessionsURL)
    private lazy var captureManager = ScreenCaptureManager(analyzer: motionAnalyzer)
    private var inputMonitoringEnabled = false
    private var sessionGameProfileID: UUID?
    private var lastPeriodicPromptTimestamp: TimeInterval?
    private var featureDemoToken: UUID?
    private var featureDemoRestoreState: FeatureDemoRestoreState?
    private var adaptiveRetryCount = 0
    private var adaptiveRetryToken = UUID()
    private var adaptiveConfigurationToken = UUID()
    private var captureTransitionTask: Task<Void, Never>?
    private var captureGeneration = UUID()
    private var overlayHUDDismissToken = UUID()
    private var maintenanceTimer: Timer?
    var openSettingsHandler: (() -> Void)?
    var showReportHandler: (() -> Void)?
    var showDebugHUDHandler: ((Bool) -> Void)?
    var menuRefreshHandler: (() -> Void)?

    init(
        profileStore: ProfileStore = ProfileStore(),
        permissionManager: PermissionManager = PermissionManager(),
        gameDetector: GameDetector = GameDetector(),
        windowInfoProvider: WindowInfoProvider = WindowInfoProvider(),
        launchAtLoginService: LaunchAtLoginControlling = LaunchAtLoginService(),
        hotkeyManager: HotkeyManager = HotkeyManager(),
        optionalInputMonitor: OptionalInputMonitor = OptionalInputMonitor(),
        controllerMonitor: GameControllerMonitor = GameControllerMonitor(),
        motionAnalyzer: MotionAnalyzer = MotionAnalyzer(),
        runtimeServicesEnabled: Bool = true
    ) {
        self.profileStore = profileStore
        self.permissionManager = permissionManager
        self.gameDetector = gameDetector
        self.windowInfoProvider = windowInfoProvider
        self.launchAtLoginService = launchAtLoginService
        self.overlayManager = OverlayManager(overlayState: overlayState, appState: state)
        self.hotkeyManager = hotkeyManager
        self.optionalInputMonitor = optionalInputMonitor
        self.controllerMonitor = controllerMonitor
        self.motionAnalyzer = motionAnalyzer
        self.runtimeServicesEnabled = runtimeServicesEnabled
    }

    func start() {
        state.profiles = profileStore.loadProfiles()
        state.selectedProfileID = state.profiles.first?.id
        appSettings = profileStore.loadSettings()
        state.language = appSettings.interface.language
        refreshLaunchAtLoginStatus()
        _ = targetOverlayRegions()
        sessionLogger.configure(settings: appSettings.telemetry)
        guard runtimeServicesEnabled else {
            state.permissionState = .unknown
            state.statusMessage = "UI testing mode"
            return
        }
        if appSettings.privacy.inputSignalEnabled, permissionManager.hasInputMonitoringAccess {
            inputMonitoringEnabled = optionalInputMonitor.start()
        }
        state.permissionState = permissionManager.currentState()
        refreshPermissions()
        sessionLogger.start(gameName: "None")
        configureCallbacks()
        state.hotkeyRegistrations = hotkeyManager.registerDefaults { [weak self] action in
            Task { @MainActor in
                self?.handleHotkey(action)
            }
        }
        if state.hotkeyRegistrations.contains(where: { !$0.registered }) {
            state.statusMessage = "Some hotkeys could not be registered. Use the menu bar actions as fallback."
        }
        controllerMonitor.start()
        gameDetector.start()
        startMaintenanceTimer()
    }

    func stop() {
        guard runtimeServicesEnabled else {
            return
        }
        maintenanceTimer?.invalidate()
        maintenanceTimer = nil
        captureGeneration = UUID()
        hideOverlay()
        finalizeActiveSession()
        captureTransitionTask?.cancel()
        captureTransitionTask = Task { await captureManager.stop() }
        hotkeyManager.unregister()
        optionalInputMonitor.stop()
        controllerMonitor.stop()
        gameDetector.stop()
        sessionLogger.flush()
    }

    func setComfortMode(_ mode: ComfortMode) {
        guard let profile = state.manualProfile ?? state.activeProfile ?? state.selectedProfile else {
            state.statusMessage = "No profile is available."
            return
        }
        applyComfortMode(mode, to: profile, manualPreview: state.activeProfile?.id != profile.id)
    }

    func setSelectedProfileMode(_ mode: ComfortMode) {
        guard let profile = state.selectedProfile else {
            state.statusMessage = "No profile is available."
            return
        }
        applyComfortMode(mode, to: profile, manualPreview: state.activeProfile?.id != profile.id)
    }

    private func applyComfortMode(_ mode: ComfortMode, to targetProfile: GameProfile, manualPreview: Bool) {
        var profile = targetProfile
        profile.overlay.mode = mode
        profile.updatedAt = Date()
        let nextProfiles = profileStore.upsert(profile, into: state.profiles)
        guard saveProfiles(nextProfiles) else {
            return
        }

        cancelFeatureDemo(restoreOverlay: false)
        adaptiveRetryToken = UUID()
        adaptiveRetryCount = 0
        state.currentMode = mode
        defer { menuRefreshHandler?() }

        state.profiles = nextProfiles
        state.selectedProfileID = profile.id
        if state.activeProfile?.id == profile.id {
            state.activeProfile = profile
        }
        if manualPreview {
            state.manualProfileID = profile.id
        } else {
            state.manualProfileID = nil
        }
        captureSignals.update(config: profile.overlay)

        guard mode != .off else {
            stopAdaptiveCapture(resetMetrics: true)
            hideOverlay()
            state.statusMessage = String(format: state.t("%@ overlay is off."), profile.displayName)
            return
        }

        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        let activeTarget = state.activeProfile?.id == profile.id
        if mode == .adaptive, activeTarget {
            startAdaptiveCaptureIfAllowed()
        } else if mode == .adaptive {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = "Add the current app as a game to enable adaptive capture."
            state.statusMessage = "Adaptive preview is visible. Add a game profile to analyze motion."
        } else {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = activeTarget ? "manual overlay" : "preview"
            state.statusMessage = String(format: state.t("%@ overlay preview is visible."), state.localizer.mode(mode))
        }
        updateOverlayHUD(message: "\(profile.displayName) · \(state.localizer.mode(mode))", detail: state.localizedCaptureModeDescription)
    }

    func toggleOverlay() {
        cancelFeatureDemo(restoreOverlay: true)
        if overlayState.enabled {
            hideOverlay()
            if state.currentMode == .adaptive {
                stopAdaptiveCapture(resetMetrics: false)
            }
            state.statusMessage = "Overlay hidden."
        } else {
            showOverlayForActiveProfileOrSelection()
            if state.currentMode == .adaptive, state.activeProfile != nil {
                startAdaptiveCaptureIfAllowed()
            }
            state.statusMessage = "Overlay visible."
        }
    }

    func showFeatureDemoOverlay(duration: TimeInterval = 12) {
        cancelFeatureDemo(restoreOverlay: true)
        let token = UUID()
        let wasEnabled = overlayState.enabled
        let previousMode = state.currentMode
        let previousCaptureDescription = state.captureModeDescription
        let baseConfig = state.displayedProfile?.overlay
            ?? DefaultProfiles.profile(for: .general3D).overlay

        featureDemoToken = token
        featureDemoRestoreState = FeatureDemoRestoreState(
            mode: previousMode,
            captureDescription: previousCaptureDescription,
            overlayWasEnabled: wasEnabled
        )
        state.currentMode = .high
        state.captureModeDescription = "feature demo"
        setEmergencyActive(false)
        overlayState.apply(config: baseConfig.highVisibilityDemo(), mode: .high)
        showOverlayForResolvedTarget()
        updateOverlayHUD(
            message: state.t("Feature demo overlay is visible."),
            detail: state.t("Shows center dot, crosshair, horizon, dashboard, nose, and peripheral frame.")
        )
        menuRefreshHandler?()

        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, duration)) { [weak self] in
            Task { @MainActor in
                self?.finishFeatureDemo(token: token)
            }
        }
    }

    func toggleEmergency() {
        cancelFeatureDemo(restoreOverlay: true)
        setEmergencyActive(!overlayState.emergencyActive)
        let profile = state.displayedProfile
        if let profile {
            let effectiveMode = state.currentMode == .off ? ComfortMode.medium : state.currentMode
            overlayState.apply(config: profile.overlay, mode: effectiveMode)
            if overlayState.emergencyActive {
                showOverlayForResolvedTarget()
            } else if state.currentMode == .off {
                hideOverlay()
            }
        }
        menuRefreshHandler?()
        if overlayState.emergencyActive {
            updateOverlayHUD(message: state.t("Emergency comfort"), detail: state.t("Temporary stronger overlay"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                Task { @MainActor in
                    guard self?.overlayState.emergencyActive == true else {
                        return
                    }
                    self?.setEmergencyActive(false)
                    if let profile = self?.state.displayedProfile {
                        self?.overlayState.apply(config: profile.overlay, mode: self?.state.currentMode ?? .adaptive)
                    }
                    if self?.state.currentMode == .off {
                        self?.hideOverlay()
                    }
                    self?.menuRefreshHandler?()
                    self?.updateOverlayHUDFromCurrentState()
                    self?.state.statusMessage = "Emergency overlay ended. Record discomfort when it is safe to do so."
                }
            }
        } else {
            updateOverlayHUDFromCurrentState()
        }
    }

    func addCurrentAppAsGame() {
        let frontmostApp = gameDetector.currentFrontmostAppInfo()
        let candidate = isSeaLegs(frontmostApp) ? state.currentApp : frontmostApp
        guard let app = candidate,
              !isSeaLegs(app),
              app.activationPolicyRaw == NSApplication.ActivationPolicy.regular.rawValue else {
            state.statusMessage = "No frontmost app detected."
            return
        }
        if let existingProfile = state.profiles.first(where: {
            $0.matches(
                bundleIdentifier: app.bundleIdentifier,
                executableName: app.executableName,
                executablePath: app.executableURL?.path
            )
        }) {
            state.selectedProfileID = existingProfile.id
            state.manualProfileID = nil
            state.statusMessage = String(format: state.t("%@ is already registered."), existingProfile.displayName)
            handleActiveAppChanged(app)
            return
        }
        let displayName = app.localizedName ?? app.executableName ?? state.t("Game")
        let profile = DefaultProfiles.customProfile(
            displayName: displayName,
            bundleIdentifier: app.bundleIdentifier,
            executableName: app.executableName,
            executablePath: app.executableURL?.path,
            category: .general3D
        )
        let nextProfiles = profileStore.upsert(profile, into: state.profiles)
        guard saveProfiles(nextProfiles) else {
            return
        }
        state.profiles = nextProfiles
        state.selectedProfileID = profile.id
        handleActiveAppChanged(app)
    }

    func linkSelectedProfileToCurrentApp() {
        guard let selectedProfile = state.selectedProfile, !selectedProfile.isTemplate else {
            state.statusMessage = "Select a custom profile before linking an app."
            return
        }
        let frontmostApp = gameDetector.currentFrontmostAppInfo()
        guard let app = isSeaLegs(frontmostApp) ? state.currentApp : frontmostApp else {
            state.statusMessage = "No application is available to link."
            return
        }
        if let conflict = state.profiles.first(where: { profile in
            profile.id != selectedProfile.id && profile.matches(
                bundleIdentifier: app.bundleIdentifier,
                executableName: app.executableName,
                executablePath: app.executableURL?.path
            )
        }) {
            state.statusMessage = String(
                format: state.t("This app is already linked to %@."),
                conflict.displayName
            )
            return
        }

        guard mutateSelectedProfile({ profile in
            profile.bundleIdentifier = app.bundleIdentifier
            profile.executableName = app.executableName
            profile.executablePathHash = app.executableURL.map { GameProfile.stableHash($0.path) }
        }, preview: false) else {
            return
        }
        state.statusMessage = String(
            format: state.t("Linked %@ to the selected profile."),
            app.localizedName ?? app.executableName ?? state.t("App")
        )
    }

    func previewProfile(_ profile: GameProfile) {
        cancelFeatureDemo(restoreOverlay: false)
        if state.currentMode == .adaptive, state.activeProfile?.id != profile.id {
            stopAdaptiveCapture(resetMetrics: true)
        }
        state.selectedProfileID = profile.id
        state.manualProfileID = profile.id
        let mode = profile.overlay.mode == .off ? ComfortMode.medium : profile.overlay.mode
        state.currentMode = mode
        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        state.captureModeDescription = "preview"
        state.statusMessage = "Previewing \(profile.displayName)."
        updateOverlayHUD(message: "\(profile.displayName) · \(state.localizer.mode(mode))", detail: state.t("Preview"))
        menuRefreshHandler?()
    }

    func selectProfile(_ profile: GameProfile) {
        state.selectedProfileID = profile.id
        state.statusMessage = "Selected \(profile.displayName) for editing."
    }

    func deleteProfile(_ profile: GameProfile) {
        guard !profile.isTemplate else {
            state.statusMessage = "Built-in template profiles cannot be deleted."
            return
        }
        let nextProfiles = profileStore.delete(profile, from: state.profiles)
        guard saveProfiles(nextProfiles) else {
            return
        }
        state.profiles = nextProfiles
        let deletingActiveProfile = state.activeProfile?.id == profile.id
        let deletingManualPreview = state.manualProfileID == profile.id
        if deletingActiveProfile {
            hideOverlay()
            finalizeActiveSession()
            state.activeProfile = nil
            state.currentMode = .off
            stopAdaptiveCapture(resetMetrics: true)
        }
        if deletingManualPreview {
            state.manualProfileID = nil
            if !deletingActiveProfile {
                restoreActiveProfileAfterManualPreview()
            }
        }
        if state.selectedProfileID == profile.id {
            state.selectedProfileID = state.profiles.first?.id
        }
    }

    func mutateActiveProfile(_ update: (inout GameProfile) -> Void) {
        mutateSelectedProfile(update)
    }

    func applyRecommendedVisualAidsToSelectedProfile() {
        if mutateSelectedProfile({ profile in
            let recommended = DefaultProfiles.profile(for: profile.category).overlay
            profile.overlay.centerDot = recommended.centerDot
            profile.overlay.crosshair = recommended.crosshair
            profile.overlay.horizon = recommended.horizon
            profile.overlay.dashboard = recommended.dashboard
            profile.overlay.virtualNose = recommended.virtualNose
            profile.overlay.peripheralFrame = recommended.peripheralFrame
        }) {
            state.statusMessage = "Recommended visual aids applied."
        }
    }

    @discardableResult
    func mutateSelectedProfile(_ update: (inout GameProfile) -> Void, preview: Bool = true) -> Bool {
        cancelFeatureDemo(restoreOverlay: true)
        guard var profile = state.selectedProfile else {
            state.statusMessage = "No profile is available."
            return false
        }

        update(&profile)
        profile.updatedAt = Date()
        guard updateProfile(profile) else {
            return false
        }
        state.selectedProfileID = profile.id
        if preview {
            if state.currentMode == .adaptive, state.activeProfile?.id != profile.id {
                stopAdaptiveCapture(resetMetrics: true)
            }
            state.manualProfileID = profile.id
            let previewMode = profile.overlay.mode == .off ? ComfortMode.medium : profile.overlay.mode
            state.currentMode = previewMode
            overlayState.apply(config: profile.overlay, mode: previewMode)
            showOverlayForResolvedTarget()
            updateOverlayHUD(message: "\(profile.displayName) · \(state.localizer.mode(previewMode))", detail: state.t("Preview"))
        }
        menuRefreshHandler?()
        return true
    }

    func restoreProfileSnapshot(_ profile: GameProfile) {
        cancelFeatureDemo(restoreOverlay: false)
        guard updateProfile(profile) else {
            return
        }
        state.selectedProfileID = profile.id
        state.manualProfileID = profile.id
        let mode = profile.overlay.mode
        state.currentMode = mode
        captureSignals.update(config: profile.overlay)

        guard mode != .off else {
            stopAdaptiveCapture(resetMetrics: true)
            hideOverlay()
            state.statusMessage = String(format: state.t("%@ overlay is off."), profile.displayName)
            menuRefreshHandler?()
            return
        }

        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        if mode == .adaptive, state.activeProfile?.id == profile.id {
            startAdaptiveCaptureIfAllowed()
        } else {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = state.activeProfile?.id == profile.id ? "manual overlay" : "preview"
        }
        updateOverlayHUD(message: "\(profile.displayName) · \(state.localizer.mode(mode))", detail: state.t("Preview"))
        state.statusMessage = "Last calibration undone."
        menuRefreshHandler?()
    }

    @discardableResult
    func updateProfile(_ profile: GameProfile) -> Bool {
        let previousProfile = state.profiles.first(where: { $0.id == profile.id })
        let overlayWasVisible = overlayState.enabled
        let nextProfiles = profileStore.upsert(profile, into: state.profiles)
        guard saveProfiles(nextProfiles) else {
            return false
        }
        state.profiles = nextProfiles
        if state.selectedProfileID == nil {
            state.selectedProfileID = profile.id
        }
        if state.activeProfile?.id == profile.id {
            state.activeProfile = profile
            if overlayWasVisible {
                overlayState.apply(config: profile.overlay, mode: state.currentMode)
            }
            if previousProfile?.adaptive != profile.adaptive,
               state.currentMode == .adaptive,
               overlayWasVisible {
                scheduleAdaptiveConfigurationRestart(profileID: profile.id)
            }
        }
        if state.manualProfileID == profile.id, overlayWasVisible {
            overlayState.apply(config: profile.overlay, mode: state.currentMode)
        }
        if state.displayedProfile?.id == profile.id {
            captureSignals.update(config: profile.overlay)
        }
        return true
    }

    func retryHotkeyRegistration() {
        state.hotkeyRegistrations = hotkeyManager.registerDefaults { [weak self] action in
            Task { @MainActor in
                self?.handleHotkey(action)
            }
        }
        state.statusMessage = state.hotkeyRegistrations.allSatisfy(\.registered)
            ? "Hotkeys registered."
            : "Some hotkeys are unavailable. Use the menu bar actions as fallback."
    }

    func setMenuInteractionSuspended(_ suspended: Bool) {
        overlayManager.setMenuInteractionSuspended(suspended)
    }

    func setAppInteractionSuspended(_ suspended: Bool) {
        overlayManager.setAppInteractionSuspended(suspended)
    }

    func recordDiscomfort(score: Int, context: RatingContext = .manual) {
        guard sessionGameProfileID != nil else {
            state.statusMessage = "Start a registered game before recording a discomfort score."
            return
        }
        let rating = DiscomfortRating(
            timestamp: sessionLogger.elapsedTimestamp(),
            score: min(20, max(0, score)),
            context: context
        )
        motionAnalyzer.updateRecentDiscomfort(rating.score)
        sessionLogger.record(rating: rating)
        state.lastSessionReport = sessionLogger.makeReport()
    }

    func promptForDiscomfortScore(context: RatingContext = .manual) {
        guard sessionGameProfileID != nil else {
            state.statusMessage = "Start a registered game before recording a discomfort score."
            return
        }
        let alert = NSAlert()
        alert.messageText = state.t("Record discomfort score")
        alert.informativeText = state.t("0 = none, 20 = clear motion sickness.")
        let accessory = DiscomfortSliderAccessory(accessibilityLabel: state.t("Discomfort Score"))
        alert.accessoryView = accessory
        alert.addButton(withTitle: state.t("Record"))
        alert.addButton(withTitle: state.t("Cancel"))
        overlayManager.setModalInteractionSuspended(true)
        defer { overlayManager.setModalInteractionSuspended(false) }
        if alert.runModal() == .alertFirstButtonReturn {
            recordDiscomfort(score: accessory.score, context: context)
        }
    }

    func requestScreenRecording() {
        overlayManager.setModalInteractionSuspended(true)
        let granted = permissionManager.requestScreenRecordingAccess()
        overlayManager.setModalInteractionSuspended(false)
        refreshPermissions()
        if granted || state.permissionState.screenRecordingGranted {
            state.statusMessage = "Screen Recording permission granted."
            if state.currentMode == .adaptive {
                startAdaptiveCaptureIfAllowed()
            }
            return
        }
        let opened = permissionManager.openScreenRecordingSettings()
        state.statusMessage = opened
            ? "Allow Screen Recording in System Settings, restart SeaLegs, then press Refresh."
            : "Open Privacy & Security > Screen Recording manually, allow SeaLegs, restart the app, then press Refresh."
        schedulePermissionRefresh()
    }

    func requestInputMonitoring() {
        setInputSignalEnabled(true)
    }

    func setInputSignalEnabled(_ enabled: Bool) {
        let previousSettings = appSettings
        appSettings.privacy.inputSignalEnabled = enabled
        guard saveAppSettings(successMessage: enabled ? "Input signal preference saved." : "Input signal monitoring disabled.") else {
            appSettings = previousSettings
            return
        }
        if enabled {
            overlayManager.setModalInteractionSuspended(true)
            let granted = permissionManager.hasInputMonitoringAccess || permissionManager.requestInputMonitoringAccess()
            overlayManager.setModalInteractionSuspended(false)
            inputMonitoringEnabled = granted && optionalInputMonitor.start()
        } else {
            optionalInputMonitor.stop()
            inputMonitoringEnabled = false
        }
        refreshPermissions()
        if enabled, !inputMonitoringEnabled {
            state.statusMessage = "Input Monitoring permission is needed. The input signal will start automatically after permission is granted and SeaLegs is reopened."
            schedulePermissionRefresh()
        }
    }

    func openPrivacySettings() {
        let opened = permissionManager.openPrivacySettings()
        refreshPermissions()
        state.statusMessage = opened
            ? "Allow Screen Recording in System Settings, restart SeaLegs, then press Refresh."
            : "Open Privacy & Security > Screen Recording manually, allow SeaLegs, restart the app, then press Refresh."
        schedulePermissionRefresh()
    }

    func restartApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        let pid = ProcessInfo.processInfo.processIdentifier
        task.arguments = [
            "-c",
            "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open -n \(shellQuoted(Bundle.main.bundlePath))"
        ]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            state.statusMessage = String(format: state.t("Failed to restart SeaLegs: %@"), error.localizedDescription)
        }
    }

    func openInputMonitoringSettings() {
        let opened = permissionManager.openInputMonitoringSettings()
        refreshPermissions()
        state.statusMessage = opened
            ? "Allow Input Monitoring in System Settings, restart SeaLegs, then press Refresh."
            : "Open Privacy & Security > Input Monitoring manually, allow SeaLegs, restart the app, then press Refresh."
        schedulePermissionRefresh()
    }

    func toggleDebugHUD() {
        state.debugHUDVisible.toggle()
        showDebugHUDHandler?(state.debugHUDVisible)
        menuRefreshHandler?()
    }

    func setDebugHUDVisible(_ visible: Bool) {
        state.debugHUDVisible = visible
        showDebugHUDHandler?(visible)
        menuRefreshHandler?()
    }

    func refreshPermissionState() {
        let wasScreenRecordingGranted = state.permissionState.screenRecordingGranted
        refreshPermissions()
        if appSettings.privacy.inputSignalEnabled,
           !inputMonitoringEnabled,
           permissionManager.hasInputMonitoringAccess {
            inputMonitoringEnabled = optionalInputMonitor.start()
            refreshPermissions()
        }
        let captureNeedsRestart = state.captureModeDescription == "fallback: basic overlay"
            || state.captureModeDescription == "stopped"
        if state.currentMode == .adaptive,
           state.permissionState.screenRecordingGranted,
           (!wasScreenRecordingGranted || captureNeedsRestart) {
            startAdaptiveCaptureIfAllowed()
            return
        }
        if state.permissionState.screenRecordingRequested, !state.permissionState.screenRecordingGranted {
            state.statusMessage = "If SeaLegs is enabled in Screen Recording, restart the app and press Refresh."
        }
    }

    func applicationDidBecomeActive() {
        refreshPermissionState()
        overlayManager.refreshScreens()
    }

    func systemWillSleep() {
        adaptiveRetryToken = UUID()
        finalizeActiveSession()
        stopAdaptiveCapture(resetMetrics: true)
        state.captureModeDescription = "paused while Mac sleeps"
    }

    func systemDidWake() {
        refreshPermissions()
        let frontmostApp = gameDetector.currentFrontmostAppInfo()
        if isSeaLegs(frontmostApp), let profile = state.activeProfile {
            if sessionGameProfileID == nil {
                sessionLogger.start(gameName: profile.displayName)
                sessionGameProfileID = profile.id
                lastPeriodicPromptTimestamp = nil
            }
            guard overlayState.enabled else {
                state.captureModeDescription = "stopped"
                return
            }
            showOverlayForActiveProfile()
            if state.currentMode == .adaptive {
                startAdaptiveCaptureIfAllowed()
            }
            return
        }
        handleActiveAppChanged(frontmostApp)
    }

    func updateSessionReport() {
        if sessionGameProfileID != nil || state.lastSessionReport == nil {
            state.lastSessionReport = sessionLogger.makeReport()
        }
    }

    func exportDiagnostics() {
        updateSessionReport()
        let panel = NSSavePanel()
        panel.title = state.t("Export SeaLegs Diagnostics")
        panel.nameFieldStringValue = "SeaLegs-Diagnostics.json"
        panel.allowedContentTypes = [.json]
        overlayManager.setModalInteractionSuspended(true)
        defer { overlayManager.setModalInteractionSuspended(false) }
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try DiagnosticsExporter.jsonData(
                from: DiagnosticsExporter.makeSnapshot(
                    appState: state,
                    overlayState: overlayState,
                    target: state.currentApp.map {
                        DiagnosticsTargetInput(appInfo: $0, captureModeDescription: state.captureModeDescription)
                    },
                    redactionSalt: appSettings.privacy.diagnosticsHashSalt
                )
            )
            try data.write(to: url, options: [.atomic])
            state.statusMessage = "Diagnostics exported."
            state.diagnosticsStatusMessage = String(format: state.t("Exported to %@."), url.lastPathComponent)
        } catch {
            state.statusMessage = "Failed to export diagnostics: \(error.localizedDescription)"
            state.diagnosticsStatusMessage = String(format: state.t("Export failed: %@"), error.localizedDescription)
        }
    }

    func exportSelectedProfile() {
        guard let profile = state.selectedProfile else {
            state.statusMessage = "Select a profile before exporting."
            return
        }
        exportProfiles([profile], suggestedName: sanitizedFilename(profile.displayName))
    }

    func exportCustomProfiles() {
        let profiles = state.profiles.filter { !$0.isTemplate }
        guard !profiles.isEmpty else {
            state.statusMessage = "No custom profiles are available to export."
            return
        }
        exportProfiles(profiles, suggestedName: "SeaLegs-Profiles")
    }

    func importProfiles() {
        let panel = NSOpenPanel()
        panel.title = state.t("Import SeaLegs Profiles")
        panel.allowedContentTypes = [.seaLegsProfile, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        overlayManager.setModalInteractionSuspended(true)
        defer { overlayManager.setModalInteractionSuspended(false) }
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        importProfiles(from: url)
    }

    func importProfiles(from url: URL) {
        do {
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                ?? (SeaLegsProfileArchive.maximumArchiveBytes + 1)
            guard fileSize <= SeaLegsProfileArchive.maximumArchiveBytes else {
                throw ProfileTransferError.archiveTooLarge
            }
            let archive = try SeaLegsProfileArchive.decode(Data(contentsOf: url, options: .mappedIfSafe))
            state.pendingProfileImport = ProfileImportResolver.preview(
                archive: archive,
                existing: state.profiles
            )
            state.statusMessage = "Review the imported profiles before applying changes."
        } catch {
            state.pendingProfileImport = nil
            state.statusMessage = String(format: state.t("Profile import failed: %@"), error.localizedDescription)
        }
    }

    func resolvePendingProfileImport(_ strategy: ProfileImportStrategy) {
        guard let preview = state.pendingProfileImport else {
            return
        }
        defer { state.pendingProfileImport = nil }
        guard strategy != .cancel else {
            state.statusMessage = "Profile import cancelled."
            return
        }

        cancelFeatureDemo(restoreOverlay: true)
        let previousDisplayedProfile = state.displayedProfile
        let overlayWasVisible = overlayState.enabled
        let nextProfiles = ProfileImportResolver.resolve(
            preview: preview,
            existing: state.profiles,
            strategy: strategy
        )
        guard saveProfiles(nextProfiles) else {
            return
        }
        state.profiles = nextProfiles
        if let activeID = state.activeProfile?.id {
            state.activeProfile = nextProfiles.first(where: { $0.id == activeID })
        }
        if let manualID = state.manualProfileID,
           !nextProfiles.contains(where: { $0.id == manualID }) {
            state.manualProfileID = nil
        }
        if let selectedID = state.selectedProfileID,
           !nextProfiles.contains(where: { $0.id == selectedID }) {
            state.selectedProfileID = nextProfiles.first(where: { !$0.isTemplate })?.id
                ?? nextProfiles.first?.id
        }
        if state.displayedProfile != previousDisplayedProfile {
            synchronizeRuntimeAfterProfileImport(overlayWasVisible: overlayWasVisible)
        }
        state.statusMessage = String(format: state.t("Imported %d profile(s)."), preview.archive.profiles.count)
        menuRefreshHandler?()
    }

    func refreshLaunchAtLoginStatus() {
        state.launchAtLoginStatus = launchAtLoginService.status
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
            state.statusMessage = state.launchAtLoginStatus == .requiresApproval
                ? "Launch at Login requires approval in System Settings."
                : "Launch at Login updated."
        } catch {
            refreshLaunchAtLoginStatus()
            state.statusMessage = String(format: state.t("Failed to update Launch at Login: %@"), error.localizedDescription)
        }
    }

    func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
    }

    var compatibilityReport: CompatibilityReportSnapshot {
        CompatibilityReportBuilder.make(
            state: state,
            overlayState: overlayState,
            selectedScope: appSettings.interface.overlayDisplayScope,
            launchAtLoginStatus: state.launchAtLoginStatus
        )
    }

    func runCompatibilityCheck() {
        refreshPermissionState()
        refreshLaunchAtLoginStatus()
        if overlayState.enabled {
            _ = targetOverlayRegions()
        }
        showFeatureDemoOverlay()
        state.compatibilityStatusMessage = "Overlay test started. Confirm that the visual guides fit the game area."
    }

    func copyCompatibilityReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(compatibilityReport.text, forType: .string)
        state.compatibilityStatusMessage = "Compatibility report copied."
        state.statusMessage = "Compatibility report copied."
    }

    private func exportProfiles(_ profiles: [GameProfile], suggestedName: String) {
        let panel = NSSavePanel()
        panel.title = state.t("Export SeaLegs Profiles")
        panel.nameFieldStringValue = "\(suggestedName).sealegsprofile"
        panel.allowedContentTypes = [.seaLegsProfile]
        overlayManager.setModalInteractionSuspended(true)
        defer { overlayManager.setModalInteractionSuspended(false) }
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let archive = try SeaLegsProfileArchive.make(profiles: profiles, appVersion: version)
            try archive.encoded().write(to: url, options: [.atomic])
            state.statusMessage = String(
                format: state.t("Exported %d profile(s) to %@."),
                profiles.count,
                url.lastPathComponent
            )
        } catch {
            state.statusMessage = String(format: state.t("Profile export failed: %@"), error.localizedDescription)
        }
    }

    private func sanitizedFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let components = value.components(separatedBy: invalid)
        let sanitized = components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "SeaLegs-Profile" : sanitized
    }

    private func synchronizeRuntimeAfterProfileImport(overlayWasVisible: Bool) {
        guard let profile = state.displayedProfile else {
            if overlayWasVisible {
                hideOverlay()
                stopAdaptiveCapture(resetMetrics: true)
            }
            return
        }

        let previewingDisabledProfile = overlayWasVisible
            && state.manualProfileID == profile.id
            && profile.overlay.mode == .off
        let mode = previewingDisabledProfile ? ComfortMode.medium : profile.overlay.mode
        state.currentMode = mode
        captureSignals.update(config: profile.overlay)
        guard overlayWasVisible else {
            return
        }
        guard mode != .off else {
            hideOverlay()
            stopAdaptiveCapture(resetMetrics: true)
            return
        }

        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        if mode == .adaptive, state.activeProfile?.id == profile.id {
            scheduleAdaptiveConfigurationRestart(profileID: profile.id)
        } else if mode == .adaptive {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = "preview"
        } else {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = state.activeProfile?.id == profile.id ? "manual overlay" : "preview"
        }
        updateOverlayHUDFromCurrentState()
    }

    func updateTelemetrySettings(_ update: (inout TelemetrySettings) -> Void) {
        let previousSettings = appSettings
        update(&appSettings.telemetry)
        guard saveAppSettings(successMessage: "Privacy settings saved.") else {
            appSettings = previousSettings
            return
        }
        sessionLogger.configure(settings: appSettings.telemetry)
    }

    func updateInterfaceLanguage(_ language: AppLanguage) {
        let previousLanguage = appSettings.interface.language
        appSettings.interface.language = language
        do {
            try profileStore.saveSettings(appSettings)
            state.language = language
            state.statusMessage = "Language preference saved."
            menuRefreshHandler?()
        } catch {
            appSettings.interface.language = previousLanguage
            state.language = previousLanguage
            state.statusMessage = String(format: state.t("Failed to save language preference: %@"), error.localizedDescription)
        }
    }

    func updateOverlayDisplayScope(_ scope: OverlayDisplayScope) {
        let previousScope = appSettings.interface.overlayDisplayScope
        appSettings.interface.overlayDisplayScope = scope
        guard saveAppSettings(successMessage: "Overlay display preference saved.") else {
            appSettings.interface.overlayDisplayScope = previousScope
            return
        }
        if overlayState.enabled {
            showOverlayForResolvedTarget()
        } else {
            _ = targetOverlayRegions()
        }
    }

    func deleteStoredSessionLogs() {
        do {
            try sessionLogger.deleteStoredSessions()
            state.statusMessage = "Stored session logs deleted."
            state.diagnosticsStatusMessage = "Stored session logs deleted."
        } catch {
            state.statusMessage = "Failed to delete session logs: \(error.localizedDescription)"
        }
    }

    var telemetrySettings: TelemetrySettings {
        appSettings.telemetry
    }

    var interfaceSettings: InterfaceSettings {
        appSettings.interface
    }

    var privacySettings: PrivacySettings {
        appSettings.privacy
    }

    var inputMonitoringAccessGranted: Bool {
        permissionManager.hasInputMonitoringAccess
    }

    func refreshSessionReport() {
        updateSessionReport()
        showReportHandler?()
    }

    private func configureCallbacks() {
        gameDetector.onActiveAppChanged = { [weak self] app in
            self?.handleActiveAppChanged(app)
        }
        motionAnalyzer.onResult = { [weak self] visual, cadence, scoreResult, generation in
            Task { @MainActor in
                self?.handleMotionResult(
                    visual: visual,
                    cadence: cadence,
                    scoreResult: scoreResult,
                    generation: generation
                )
            }
        }
        captureManager.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleCaptureError(error)
            }
        }
    }

    private func handleActiveAppChanged(_ app: RunningAppInfo?) {
        guard !isSeaLegs(app) else {
            return
        }

        state.currentApp = app
        guard featureDemoToken == nil else {
            menuRefreshHandler?()
            return
        }
        guard let profile = gameDetector.isRegisteredGameActive(app: app, profiles: state.profiles) else {
            hideOverlay()
            finalizeActiveSession()
            state.activeProfile = nil
            state.manualProfileID = nil
            state.currentMode = .off
            stopAdaptiveCapture(resetMetrics: true)
            motionAnalyzer.resetSession(keepRecentDiscomfort: false)
            menuRefreshHandler?()
            return
        }

        let startsNewSession = sessionGameProfileID != profile.id
        if startsNewSession {
            finalizeActiveSession()
            sessionLogger.start(gameName: profile.displayName)
            sessionGameProfileID = profile.id
            lastPeriodicPromptTimestamp = nil
            resetCaptureMetrics()
        }
        adaptiveRetryToken = UUID()
        adaptiveRetryCount = 0
        state.manualProfileID = nil
        state.activeProfile = profile
        state.currentMode = profile.overlay.mode
        motionAnalyzer.resetSession(keepRecentDiscomfort: !startsNewSession)
        showOverlayForActiveProfile()
        if profile.overlay.mode == .adaptive {
            startAdaptiveCaptureIfAllowed()
        }
        menuRefreshHandler?()
    }

    private func showOverlayForActiveProfile() {
        guard let profile = state.activeProfile else {
            return
        }
        let mode = state.currentMode == .off ? profile.overlay.mode : state.currentMode
        guard mode != .off else {
            hideOverlay()
            return
        }
        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        updateOverlayHUDFromCurrentState()
    }

    private func showOverlayForActiveProfileOrSelection() {
        guard let profile = state.displayedProfile else {
            hideOverlay()
            return
        }
        let storedMode = state.currentMode == .off ? profile.overlay.mode : state.currentMode
        let mode = storedMode == .off ? ComfortMode.medium : storedMode
        if state.currentMode == .off {
            state.currentMode = mode
        }
        if state.activeProfile?.id != profile.id {
            state.manualProfileID = profile.id
        }
        overlayState.apply(config: profile.overlay, mode: mode)
        showOverlayForResolvedTarget()
        updateOverlayHUDFromCurrentState()
    }

    private func startAdaptiveCaptureIfAllowed() {
        refreshPermissions()
        guard overlayState.enabled else {
            state.captureModeDescription = "stopped"
            return
        }
        guard let profile = state.activeProfile else {
            state.captureModeDescription = "Select a registered game to enable adaptive capture."
            state.statusMessage = "Adaptive requires an active registered game."
            return
        }
        guard state.permissionState.screenRecordingGranted else {
            state.captureModeDescription = "Screen Recording permission needed"
            state.statusMessage = "Use Request Access to open Screen Recording settings, allow SeaLegs, restart the app, then press Refresh."
            updateOverlayHUD(message: state.t("Adaptive waiting"), detail: state.t("Screen Recording required"))
            return
        }
        captureTransitionTask?.cancel()
        let generation = UUID()
        captureGeneration = generation
        captureTransitionTask = Task {
            let requestToken = adaptiveRetryToken
            let profileID = profile.id
            captureSignals.update(config: profile.overlay, emergencyActive: overlayState.emergencyActive)
            let captureSignals = captureSignals
            await captureManager.start(
                appInfo: state.currentApp,
                adaptiveConfig: profile.adaptive,
                overlayConfigProvider: { captureSignals.config },
                emergencyProvider: { captureSignals.emergencyActive },
                inputTurnScoreProvider: { [weak self] in
                    guard let self else {
                        return 0
                    }
                    return max(self.optionalInputMonitor.turnScore, self.controllerMonitor.rightStickMagnitude)
                },
                generation: generation
            )
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard self.adaptiveRetryToken == requestToken,
                      self.state.currentMode == .adaptive,
                      self.state.activeProfile?.id == profileID else {
                    return
                }
                self.state.captureModeDescription = self.captureManager.modeDescription
                self.updateOverlayHUDFromCurrentState()
            }
        }
    }

    private func handleMotionResult(
        visual: VisualMotionMetrics,
        cadence: VisualCadenceMetrics,
        scoreResult: MotionScoreResult,
        generation: UUID
    ) {
        guard let activeProfile = state.activeProfile,
              CaptureResultGate.shouldAccept(
                  resultGeneration: generation,
                  activeGeneration: captureGeneration,
                  mode: state.currentMode,
                  overlayEnabled: overlayState.enabled,
                  activeProfileID: activeProfile.id,
                  sessionProfileID: sessionGameProfileID
              ) else {
            return
        }
        state.lastVisualMetrics = visual
        state.lastCadenceMetrics = cadence
        state.lastScoreResult = scoreResult
        state.lastSampleReceivedAt = Date()
        adaptiveRetryCount = 0
        if state.currentMode == .adaptive {
            overlayState.apply(config: activeProfile.overlay, strength: scoreResult.overlayStrength)
            updateOverlayHUDContent(
                message: "\(activeProfile.displayName) · \(state.localizer.mode(.adaptive))",
                detail: String(format: state.t("Stability %.0f%% · %@"), (1 - scoreResult.smoothedScore) * 100, state.localizedCaptureModeDescription)
            )
            maybePromptForPeriodicDiscomfort(profile: activeProfile)
        }
        let sample = SessionSample(
            timestamp: sessionLogger.elapsedTimestamp(),
            gameProfileID: activeProfile.id,
            motionScore: scoreResult.smoothedScore,
            vignetteOpacity: overlayState.vignetteOpacity,
            innerRadius: overlayState.vignetteInnerRadius,
            visual: visual,
            cadence: cadence,
            permissionState: state.permissionState
        )
        sessionLogger.record(sample: sample)
    }

    private func handleHotkey(_ action: HotkeyAction) {
        switch action {
        case .toggleOverlay:
            toggleOverlay()
        case .increaseStrength:
            stepComfort(delta: 1)
        case .decreaseStrength:
            stepComfort(delta: -1)
        case .emergencyMode:
            toggleEmergency()
        case .discomfortRating:
            promptForDiscomfortScore()
        case .debugHUD:
            toggleDebugHUD()
        }
    }

    private func stepComfort(delta: Int) {
        let modes: [ComfortMode] = [.off, .low, .medium, .high, .adaptive]
        let currentIndex = modes.firstIndex(of: state.currentMode) ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), modes.count - 1)
        setComfortMode(modes[nextIndex])
    }

    private func saveProfiles(_ profiles: [GameProfile]) -> Bool {
        do {
            try profileStore.saveProfiles(profiles)
            return true
        } catch {
            logger.error("Failed to save profiles: \(error.localizedDescription)")
            state.statusMessage = String(
                format: state.t("Failed to save profiles: %@"),
                error.localizedDescription
            )
            return false
        }
    }

    private func refreshPermissions() {
        state.permissionState = permissionManager.currentState(inputMonitoringEnabled: inputMonitoringEnabled)
    }

    private func schedulePermissionRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            Task { @MainActor in
                self?.refreshPermissionState()
            }
        }
    }

    private func startMaintenanceTimer() {
        maintenanceTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performMaintenance()
            }
        }
        maintenanceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func performMaintenance() {
        state.refreshTimeBasedStatus()
        guard overlayState.enabled else {
            return
        }
        overlayManager.updateRegions(targetOverlayRegions())
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func updateOverlayHUDFromCurrentState() {
        guard let profile = state.displayedProfile else {
            updateOverlayHUD(message: "SeaLegs", detail: state.localizedCaptureReadinessDescription)
            return
        }
        let mode = state.currentMode == .off ? profile.overlay.mode : state.currentMode
        updateOverlayHUD(message: "\(profile.displayName) · \(state.localizer.mode(mode))", detail: state.localizedCaptureReadinessDescription)
    }

    private func updateOverlayHUD(message: String, detail: String) {
        updateOverlayHUDContent(message: message, detail: detail)
        state.overlayHUDVisible = true
        let token = UUID()
        overlayHUDDismissToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            Task { @MainActor in
                guard self?.overlayHUDDismissToken == token else {
                    return
                }
                self?.state.overlayHUDVisible = false
            }
        }
    }

    private func updateOverlayHUDContent(message: String, detail: String) {
        state.overlayHUDMessage = message
        state.overlayHUDDetail = detail
    }

    private func maybePromptForPeriodicDiscomfort(profile: GameProfile) {
        guard profile.feedback.periodicPromptEnabled else {
            return
        }
        let elapsed = sessionLogger.elapsedTimestamp()
        let interval = TimeInterval(max(1, profile.feedback.promptIntervalMinutes) * 60)
        guard elapsed - (lastPeriodicPromptTimestamp ?? 0) >= interval else {
            return
        }
        lastPeriodicPromptTimestamp = elapsed
        promptForDiscomfortScore(context: .periodicPrompt)
    }

    private func showOverlayForResolvedTarget() {
        overlayManager.show(regions: targetOverlayRegions())
    }

    private func hideOverlay() {
        setEmergencyActive(false)
        overlayManager.hide()
    }

    private func setEmergencyActive(_ active: Bool) {
        guard overlayState.emergencyActive != active else {
            return
        }
        overlayState.emergencyActive = active
        captureSignals.update(emergencyActive: active)
        if sessionGameProfileID != nil {
            sessionLogger.recordEmergency(active: active)
        }
    }

    private func restoreActiveProfileAfterManualPreview() {
        guard let profile = state.activeProfile else {
            hideOverlay()
            stopAdaptiveCapture(resetMetrics: true)
            return
        }
        state.currentMode = profile.overlay.mode
        captureSignals.update(config: profile.overlay)
        guard profile.overlay.mode != .off else {
            hideOverlay()
            stopAdaptiveCapture(resetMetrics: true)
            return
        }
        overlayState.apply(config: profile.overlay, mode: profile.overlay.mode)
        showOverlayForResolvedTarget()
        if profile.overlay.mode == .adaptive {
            startAdaptiveCaptureIfAllowed()
        } else {
            stopAdaptiveCapture(resetMetrics: true)
            state.captureModeDescription = "manual overlay"
        }
        updateOverlayHUDFromCurrentState()
    }

    private func finishFeatureDemo(token: UUID) {
        guard featureDemoToken == token else {
            return
        }
        cancelFeatureDemo(restoreOverlay: true)
        handleActiveAppChanged(gameDetector.currentFrontmostAppInfo())
        menuRefreshHandler?()
    }

    private func cancelFeatureDemo(restoreOverlay: Bool) {
        guard let restoreState = featureDemoRestoreState else {
            featureDemoToken = nil
            return
        }
        featureDemoToken = nil
        featureDemoRestoreState = nil
        state.currentMode = restoreState.mode
        state.captureModeDescription = restoreState.captureDescription
        guard restoreOverlay else {
            return
        }
        if restoreState.overlayWasEnabled {
            showOverlayForActiveProfileOrSelection()
        } else {
            hideOverlay()
        }
    }

    private func targetOverlayRegions() -> [OverlayPanelRegion] {
        switch appSettings.interface.overlayDisplayScope {
        case .gameWindow:
            guard let processIdentifier = state.currentApp?.processIdentifier else {
                state.overlayTargetDescription = "Game Window (Waiting for Game)"
                state.overlayTargetFallbackActive = false
                return displayRegions(for: activeGameScreens())
            }
            if let region = windowInfoProvider.primaryWindowPanelRegion(for: processIdentifier) {
                state.overlayTargetDescription = "Game Window"
                state.overlayTargetFallbackActive = false
                return [region]
            }
            state.overlayTargetDescription = "Active Game Display (Window Fallback)"
            state.overlayTargetFallbackActive = true
            return displayRegions(for: activeGameScreens())
        case .activeGameDisplay:
            state.overlayTargetDescription = "Active Game Display"
            state.overlayTargetFallbackActive = false
            return displayRegions(for: activeGameScreens())
        case .allDisplays:
            state.overlayTargetDescription = "All Displays"
            state.overlayTargetFallbackActive = false
            return displayRegions(for: NSScreen.screens)
        }
    }

    private func displayRegions(for screens: [NSScreen]) -> [OverlayPanelRegion] {
        screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return OverlayPanelRegion(identifier: .display(displayID), frame: screen.frame)
        }
    }

    private func activeGameScreens() -> [NSScreen] {
        let activeDisplayIDs = gameDetector.activeDisplayIDs(for: state.currentApp)
        let matchingScreens = NSScreen.screens.filter { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return activeDisplayIDs.contains(displayID)
        }
        if !matchingScreens.isEmpty {
            return matchingScreens
        }
        return [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
    }

    private func stopAdaptiveCapture(resetMetrics: Bool) {
        adaptiveRetryToken = UUID()
        adaptiveRetryCount = 0
        captureGeneration = UUID()
        captureTransitionTask?.cancel()
        captureTransitionTask = Task { await captureManager.stop() }
        state.captureModeDescription = "stopped"
        if resetMetrics {
            resetCaptureMetrics()
        }
    }

    private func resetCaptureMetrics() {
        state.lastVisualMetrics = .zero
        state.lastCadenceMetrics = .stable
        state.lastScoreResult = nil
        state.lastSampleReceivedAt = nil
    }

    private func finalizeActiveSession() {
        guard sessionGameProfileID != nil else {
            return
        }
        state.lastSessionReport = sessionLogger.makeReport()
        sessionGameProfileID = nil
        sessionLogger.start(gameName: "None")
    }

    private func handleCaptureError(_ error: Error) {
        captureGeneration = UUID()
        resetCaptureMetrics()
        state.statusMessage = String(
            format: state.t("Adaptive capture fallback: %@"),
            error.localizedDescription
        )
        state.captureModeDescription = "fallback: basic overlay"
        updateOverlayHUD(message: state.t("Adaptive paused"), detail: error.localizedDescription)

        guard state.currentMode == .adaptive,
              let profileID = state.activeProfile?.id,
              overlayState.enabled,
              state.permissionState.screenRecordingGranted,
              adaptiveRetryCount < 3 else {
            return
        }

        adaptiveRetryCount += 1
        let retryToken = adaptiveRetryToken
        let delay = min(6.0, Double(adaptiveRetryCount) * 1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.adaptiveRetryToken == retryToken,
                      self.state.currentMode == .adaptive,
                      self.state.activeProfile?.id == profileID else {
                    return
                }
                self.startAdaptiveCaptureIfAllowed()
            }
        }
    }

    private func scheduleAdaptiveConfigurationRestart(profileID: UUID) {
        let token = UUID()
        adaptiveConfigurationToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.adaptiveConfigurationToken == token,
                      self.state.currentMode == .adaptive,
                      self.state.activeProfile?.id == profileID,
                      self.overlayState.enabled else {
                    return
                }
                self.startAdaptiveCaptureIfAllowed()
            }
        }
    }

    @discardableResult
    private func saveAppSettings(successMessage: String) -> Bool {
        do {
            try profileStore.saveSettings(appSettings)
            state.statusMessage = successMessage
            return true
        } catch {
            state.statusMessage = String(format: state.t("Failed to save settings: %@"), error.localizedDescription)
            return false
        }
    }

    private func isSeaLegs(_ app: RunningAppInfo?) -> Bool {
        app?.bundleIdentifier == AppConstants.bundleIdentifier
    }
}

private final class CaptureRuntimeSignals: @unchecked Sendable {
    private let lock = NSLock()
    private var storedConfig: OverlayConfig?
    private var storedEmergencyActive = false

    var config: OverlayConfig? {
        lock.lock()
        defer { lock.unlock() }
        return storedConfig
    }

    var emergencyActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedEmergencyActive
    }

    func update(config: OverlayConfig? = nil, emergencyActive: Bool? = nil) {
        lock.lock()
        if let config {
            storedConfig = config
        }
        if let emergencyActive {
            storedEmergencyActive = emergencyActive
        }
        lock.unlock()
    }
}

private struct FeatureDemoRestoreState {
    let mode: ComfortMode
    let captureDescription: String
    let overlayWasEnabled: Bool
}

@MainActor
private final class DiscomfortSliderAccessory: NSView {
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 20, target: nil, action: nil)
    private let valueLabel = NSTextField(labelWithString: "0 / 20")

    var score: Int {
        slider.integerValue
    }

    init(accessibilityLabel: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 48))
        slider.numberOfTickMarks = 21
        slider.allowsTickMarkValuesOnly = true
        slider.target = self
        slider.action = #selector(valueChanged)
        slider.setAccessibilityLabel(accessibilityLabel)
        slider.setAccessibilityValueDescription("0 / 20")
        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        valueLabel.setAccessibilityHidden(true)

        slider.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)
        addSubview(valueLabel)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 54)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func valueChanged() {
        valueLabel.stringValue = "\(score) / 20"
        slider.setAccessibilityValueDescription(valueLabel.stringValue)
    }
}
