import SwiftUI

private enum SettingsPage: String, Hashable, Identifiable {
    case general = "General"
    case profiles = "Profiles"
    case overlay = "Overlay"
    case adaptive = "Adaptive"
    case assistant = "Assistant"
    case calibration = "Calibration"
    case compatibility = "Compatibility"
    case hotkeys = "Hotkeys"
    case privacy = "Privacy"
    case reports = "Reports"
    case debug = "Debug"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .profiles: "gamecontroller"
        case .overlay: "circle.lefthalf.filled"
        case .adaptive: "waveform.path"
        case .assistant: "checklist"
        case .calibration: "slider.horizontal.3"
        case .compatibility: "checkmark.shield"
        case .hotkeys: "command"
        case .privacy: "hand.raised"
        case .reports: "chart.xyaxis.line"
        case .debug: "ladybug"
        }
    }

    static let primary: [SettingsPage] = [.general, .profiles]
    static let comfort: [SettingsPage] = [.overlay, .adaptive, .assistant, .calibration]
    static let system: [SettingsPage] = [.compatibility, .hotkeys, .privacy, .reports, .debug]
}

struct SettingsRootView: View {
    let coordinator: AppCoordinator
    @ObservedObject private var state: AppState
    @State private var selectedPage: SettingsPage? = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.state
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedPage) {
                settingsLinks(SettingsPage.primary)
                Section(state.t("Comfort")) {
                    settingsLinks(SettingsPage.comfort)
                }
                Section(state.t("System")) {
                    settingsLinks(SettingsPage.system)
                }
            }
            .accessibilityIdentifier("sealegs.settings.navigation")
            .navigationTitle("SeaLegs")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
        } detail: {
            VStack(spacing: 0) {
                SettingsStatusHeader(state: state)
                Divider()
                pageContent(selectedPage ?? .general)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .navigationTitle(state.t((selectedPage ?? .general).rawValue))
        }
        .frame(minWidth: 960, minHeight: 620)
        .accessibilityIdentifier("sealegs.settings.window")
    }

    @ViewBuilder
    private func settingsLinks(_ pages: [SettingsPage]) -> some View {
        ForEach(pages) { page in
            Label(state.t(page.rawValue), systemImage: page.systemImage)
                .tag(page)
                .accessibilityIdentifier("sealegs.settings.page.\(page.rawValue.lowercased())")
        }
    }

    @ViewBuilder
    private func pageContent(_ page: SettingsPage) -> some View {
        switch page {
        case .general:
            GeneralSettingsView(coordinator: coordinator, state: state)
        case .profiles:
            ProfileEditorView(coordinator: coordinator, state: state)
        case .overlay:
            OverlaySettingsView(coordinator: coordinator, state: state, overlayState: coordinator.overlayState)
        case .adaptive:
            AdaptiveSettingsView(coordinator: coordinator, state: state)
        case .assistant:
            GameSettingsAssistantView(coordinator: coordinator, state: state)
        case .calibration:
            CalibrationWizardView(coordinator: coordinator, state: state)
        case .compatibility:
            CompatibilityView(coordinator: coordinator, state: state, overlayState: coordinator.overlayState)
        case .hotkeys:
            HotkeysView(coordinator: coordinator, state: state)
        case .privacy:
            PrivacyView(coordinator: coordinator, state: state)
        case .reports:
            ReportsSettingsView(coordinator: coordinator, state: state)
        case .debug:
            DebugHUDView(state: state, overlayState: coordinator.overlayState)
        }
    }
}

private struct SettingsStatusHeader: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 18) {
                statusValue(
                    title: state.t(state.activeProfile == nil ? "Current App" : "Current Game"),
                    value: state.localizedCurrentGameName,
                    systemImage: "gamecontroller.fill"
                )
                statusValue(
                    title: state.t("Mode"),
                    value: state.localizer.mode(state.currentMode),
                    systemImage: "circle.lefthalf.filled"
                )
                statusValue(
                    title: state.t("Capture"),
                    value: state.localizedCaptureReadinessDescription,
                    systemImage: "record.circle"
                )
            }
            Label {
                Text(state.localizedStatusMessage)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityElement(children: .contain)
    }

    private func statusValue(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CommandGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 165, maximum: 260), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            content
        }
        .buttonStyle(.bordered)
    }
}

private struct CommandLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
    }
}

private struct EditedProfilePicker: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState

    private var profile: GameProfile? {
        state.selectedProfile
    }

    var body: some View {
        Picker(selection: Binding(
            get: { profile?.id },
            set: { profileID in
                guard let profileID,
                      let profile = state.profiles.first(where: { $0.id == profileID }) else {
                    return
                }
                coordinator.selectProfile(profile)
            }
        )) {
            ForEach(state.profiles) { profile in
                Text(profile.displayName)
                    .tag(Optional(profile.id))
            }
        } label: {
            Label(state.t("Editing Profile"), systemImage: "pencil")
        }
        .pickerStyle(.menu)
        .disabled(state.profiles.isEmpty)

        if let profile {
            LabeledContent(state.t("Profile Type")) {
                Label(
                    state.t(profile.isTemplate ? "Template profile" : "Registered profile"),
                    systemImage: profile.isTemplate ? "doc.on.doc" : "app.fill"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

}

private struct GeneralSettingsView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section(state.t("Interface")) {
                Picker(state.t("Interface Language"), selection: Binding(
                    get: { coordinator.interfaceSettings.language },
                    set: { coordinator.updateInterfaceLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(state.localizer.languagePickerTitle(for: language)).tag(language)
                    }
                }
                .pickerStyle(.menu)
                Picker(state.t("Overlay Display"), selection: Binding(
                    get: { coordinator.interfaceSettings.overlayDisplayScope },
                    set: { coordinator.updateOverlayDisplayScope($0) }
                )) {
                    ForEach(OverlayDisplayScope.allCases) { scope in
                        Text(state.t(scope.label)).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                LabeledContent(
                    state.t("Resolved Overlay Target"),
                    value: state.t(state.overlayTargetDescription)
                )
                .accessibilityIdentifier("sealegs.general.resolved-target")
                .accessibilityValue(Text(state.t(state.overlayTargetDescription)))
                if state.overlayTargetFallbackActive {
                    Label(
                        state.t("The game window was not available, so SeaLegs is using the active game display."),
                        systemImage: "arrow.trianglehead.branch"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            Section(state.t("Startup")) {
                Toggle(state.t("Launch SeaLegs at Login"), isOn: Binding(
                    get: { state.launchAtLoginStatus.isEnabled },
                    set: { coordinator.setLaunchAtLoginEnabled($0) }
                ))
                LabeledContent(
                    state.t("Launch at Login Status"),
                    value: state.t(state.launchAtLoginStatus.label)
                )
                if state.launchAtLoginStatus == .requiresApproval {
                    Text(state.t("Approve SeaLegs in System Settings > General > Login Items."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                CommandGrid {
                    Button {
                        coordinator.refreshLaunchAtLoginStatus()
                    } label: {
                        CommandLabel(title: state.t("Refresh"), systemImage: "arrow.clockwise")
                    }
                    Button {
                        coordinator.openLoginItemsSettings()
                    } label: {
                        CommandLabel(title: state.t("Open Login Items Settings"), systemImage: "gearshape")
                    }
                }
            }
            Section(state.t("Actions")) {
                CommandGrid {
                    Button {
                        coordinator.addCurrentAppAsGame()
                    } label: {
                        CommandLabel(title: state.t("Add Current App"), systemImage: "plus.app")
                    }
                    Button {
                        coordinator.toggleOverlay()
                    } label: {
                        CommandLabel(title: state.t("Toggle Overlay"), systemImage: "rectangle.on.rectangle")
                    }
                    Button {
                        coordinator.showFeatureDemoOverlay()
                    } label: {
                        CommandLabel(title: state.t("Show Feature Demo"), systemImage: "sparkles")
                    }
                    Button {
                        coordinator.refreshSessionReport()
                    } label: {
                        CommandLabel(title: state.t("Open Session Report"), systemImage: "chart.xyaxis.line")
                    }
                    Button {
                        coordinator.toggleEmergency()
                    } label: {
                        CommandLabel(title: state.t("Toggle Emergency"), systemImage: "exclamationmark.shield")
                    }
                }
            }
            Section(state.t("Support")) {
                Text(state.t("Supported: macOS 14+ on Apple Silicon, windowed/borderless games recommended."))
                Text(state.t("Limited: native fullscreen games depending on macOS Spaces behavior."))
            }
        }
    }
}

private struct SliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(String(format: "%.2f", value.wrappedValue)))
        }
    }
}

private struct OverlaySettingsView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    @ObservedObject var overlayState: OverlayState

    private var profile: GameProfile? {
        state.selectedProfile
    }

    var body: some View {
        Form {
            Section(state.t("Profile")) {
                EditedProfilePicker(coordinator: coordinator, state: state)
            }
            Section(state.t("Comfort")) {
                Picker(state.t("Mode"), selection: Binding(
                    get: { profile?.overlay.mode ?? .off },
                    set: { coordinator.setSelectedProfileMode($0) }
                )) {
                    ForEach(ComfortMode.allCases) { mode in
                        Text(state.localizer.mode(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(state.t("Feature demo temporarily shows every visible aid at high contrast, without changing the selected profile."))
                    .foregroundStyle(.secondary)
                CommandGrid {
                    Button {
                        coordinator.showFeatureDemoOverlay()
                    } label: {
                        CommandLabel(title: state.t("Show Feature Demo"), systemImage: "sparkles")
                    }
                    Button {
                        coordinator.applyRecommendedVisualAidsToSelectedProfile()
                    } label: {
                        CommandLabel(title: state.t("Apply Recommended Visual Aids"), systemImage: "wand.and.stars")
                    }
                }
            }
            .disabled(profile == nil)
            Section(state.t("Vignette")) {
                SliderRow(
                    title: state.t("Base Opacity"),
                    value: floatBinding(
                        get: { profile?.overlay.baseOpacity ?? 0 },
                        set: { value in updateOverlay { $0.baseOpacity = value } }
                    ),
                    range: 0...0.5
                )
                SliderRow(
                    title: state.t("Max Opacity"),
                    value: floatBinding(
                        get: { profile?.overlay.maxOpacity ?? 0 },
                        set: { value in updateOverlay { $0.maxOpacity = value } }
                    ),
                    range: 0.1...0.85
                )
                SliderRow(
                    title: state.t("Motion Inner Radius"),
                    value: floatBinding(
                        get: { profile?.overlay.motionInnerRadius ?? 0.7 },
                        set: { value in updateOverlay { $0.motionInnerRadius = value } }
                    ),
                    range: 0.45...0.95
                )
            }
            .disabled(profile == nil)
            Section(state.t("Visual Anchors")) {
                Toggle(state.t("Center Dot"), isOn: boolBinding(
                    get: { profile?.overlay.centerDot.enabled ?? false },
                    set: { value in updateOverlay { $0.centerDot.enabled = value } }
                ))
                SliderRow(
                    title: state.t("Center Dot Opacity"),
                    value: floatBinding(
                        get: { profile?.overlay.centerDot.opacity ?? 0 },
                        set: { value in updateOverlay { $0.centerDot.opacity = value } }
                    ),
                    range: 0...0.6
                )
                .disabled(profile?.overlay.centerDot.enabled != true)
                SliderRow(
                    title: state.t("Center Dot Horizontal Position"),
                    value: floatBinding(
                        get: { profile?.overlay.centerDot.positionX ?? 0.5 },
                        set: { value in updateOverlay { $0.centerDot.positionX = value } }
                    ),
                    range: 0.1...0.9
                )
                .disabled(profile?.overlay.centerDot.enabled != true)
                SliderRow(
                    title: state.t("Center Dot Vertical Position"),
                    value: floatBinding(
                        get: { profile?.overlay.centerDot.positionY ?? 0.5 },
                        set: { value in updateOverlay { $0.centerDot.positionY = value } }
                    ),
                    range: 0.1...0.9
                )
                .disabled(profile?.overlay.centerDot.enabled != true)
                Toggle(state.t("Minimal Crosshair"), isOn: boolBinding(
                    get: { profile?.overlay.crosshair.enabled ?? false },
                    set: { value in updateOverlay { $0.crosshair.enabled = value } }
                ))
                SliderRow(
                    title: state.t("Crosshair Opacity"),
                    value: floatBinding(
                        get: { profile?.overlay.crosshair.opacity ?? 0 },
                        set: { value in updateOverlay { $0.crosshair.opacity = value } }
                    ),
                    range: 0...0.6
                )
                .disabled(profile?.overlay.crosshair.enabled != true)
                SliderRow(
                    title: state.t("Crosshair Horizontal Position"),
                    value: floatBinding(
                        get: { profile?.overlay.crosshair.positionX ?? 0.5 },
                        set: { value in updateOverlay { $0.crosshair.positionX = value } }
                    ),
                    range: 0.1...0.9
                )
                .disabled(profile?.overlay.crosshair.enabled != true)
                SliderRow(
                    title: state.t("Crosshair Vertical Position"),
                    value: floatBinding(
                        get: { profile?.overlay.crosshair.positionY ?? 0.5 },
                        set: { value in updateOverlay { $0.crosshair.positionY = value } }
                    ),
                    range: 0.1...0.9
                )
                .disabled(profile?.overlay.crosshair.enabled != true)
                Button {
                    updateOverlay {
                        $0.centerDot.positionX = 0.5
                        $0.centerDot.positionY = 0.5
                        $0.crosshair.positionX = 0.5
                        $0.crosshair.positionY = 0.5
                    }
                } label: {
                    Label(state.t("Reset Anchor Positions"), systemImage: "scope")
                }
                .buttonStyle(.bordered)
                Toggle(state.t("Horizon Guide"), isOn: boolBinding(
                    get: { profile?.overlay.horizon.enabled ?? false },
                    set: { value in updateOverlay { $0.horizon.enabled = value } }
                ))
                SliderRow(
                    title: state.t("Horizon Position"),
                    value: floatBinding(
                        get: { profile?.overlay.horizon.y ?? 0.5 },
                        set: { value in updateOverlay { $0.horizon.y = value } }
                    ),
                    range: 0.35...0.75
                )
                .disabled(profile?.overlay.horizon.enabled != true)
                Toggle(state.t("Dashboard Frame"), isOn: boolBinding(
                    get: { profile?.overlay.dashboard.enabled ?? false },
                    set: { value in updateOverlay { $0.dashboard.enabled = value } }
                ))
                Toggle(state.t("Virtual Nose"), isOn: boolBinding(
                    get: { profile?.overlay.virtualNose.enabled ?? false },
                    set: { value in updateOverlay { $0.virtualNose.enabled = value } }
                ))
                Toggle(state.t("Peripheral Frame"), isOn: boolBinding(
                    get: { profile?.overlay.peripheralFrame.enabled ?? false },
                    set: { value in updateOverlay { $0.peripheralFrame.enabled = value } }
                ))
                SliderRow(
                    title: state.t("Peripheral Frame Opacity"),
                    value: floatBinding(
                        get: { profile?.overlay.peripheralFrame.opacity ?? 0 },
                        set: { value in updateOverlay { $0.peripheralFrame.opacity = value } }
                    ),
                    range: 0...0.4
                )
                .disabled(profile?.overlay.peripheralFrame.enabled != true)
            }
            .disabled(profile == nil)
            Section(state.t("Current Overlay")) {
                LabeledContent(state.t("Opacity"), value: String(format: "%.2f", overlayState.vignetteOpacity))
                LabeledContent(state.t("Inner Radius"), value: String(format: "%.2f", overlayState.vignetteInnerRadius))
                LabeledContent(state.t("Emergency"), value: overlayState.emergencyActive ? state.t("On") : state.t("Off"))
            }
        }
        .accessibilityIdentifier("sealegs.overlay.page")
    }

    private func updateOverlay(_ update: @escaping (inout OverlayConfig) -> Void) {
        coordinator.mutateSelectedProfile { profile in
            update(&profile.overlay)
        }
    }

    private func boolBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(
            get: { get() },
            set: { value in set(value) }
        )
    }

    private func floatBinding(get: @escaping () -> Float, set: @escaping (Float) -> Void) -> Binding<Double> {
        Binding(
            get: { Double(get()) },
            set: { set(Float($0)) }
        )
    }
}

private struct AdaptiveSettingsView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState

    private var profile: GameProfile? {
        state.selectedProfile
    }

    var body: some View {
        Form {
            Section(state.t("Profile")) {
                EditedProfilePicker(coordinator: coordinator, state: state)
            }
            Section(state.t("Adaptive Analysis")) {
                Toggle(state.t("Low Power Mode"), isOn: Binding(
                    get: { profile?.adaptive.lowPowerMode ?? false },
                    set: { value in
                        updateSelectedProfile { $0.adaptive.lowPowerMode = value }
                    }
                ))
                Stepper(
                    String(
                        format: state.t("Analysis FPS: %d"),
                        profile?.adaptive.analysisFramesPerSecond ?? AdaptiveConfig.standard.analysisFramesPerSecond
                    ),
                    value: Binding(
                        get: { profile?.adaptive.analysisFramesPerSecond ?? AdaptiveConfig.standard.analysisFramesPerSecond },
                        set: { value in
                            updateSelectedProfile { $0.adaptive.analysisFramesPerSecond = min(60, max(1, value)) }
                        }
                    ),
                    in: 1...60
                )
                LabeledContent(
                    state.t("Effective FPS"),
                    value: String(profile?.adaptive.effectiveFramesPerSecond ?? AdaptiveConfig.standard.effectiveFramesPerSecond)
                )
                Text(state.t("Low Power Mode caps analysis at 12 FPS and reduces analysis resolution."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(profile == nil)
            Section(state.t("Discomfort Prompts")) {
                Toggle(state.t("Periodic discomfort prompts"), isOn: Binding(
                    get: { profile?.feedback.periodicPromptEnabled ?? false },
                    set: { value in
                        updateSelectedProfile { $0.feedback.periodicPromptEnabled = value }
                    }
                ))
                Stepper(
                    String(
                        format: state.t("Prompt interval: %d min"),
                        profile?.feedback.promptIntervalMinutes ?? FeedbackConfig.standard.promptIntervalMinutes
                    ),
                    value: Binding(
                        get: { profile?.feedback.promptIntervalMinutes ?? FeedbackConfig.standard.promptIntervalMinutes },
                        set: { value in
                            updateSelectedProfile { $0.feedback.promptIntervalMinutes = min(120, max(1, value)) }
                        }
                    ),
                    in: 1...120
                )
                .disabled(profile?.feedback.periodicPromptEnabled != true)
            }
            .disabled(profile == nil)
            Section(state.t("Screen Recording")) {
                LabeledContent(state.t("Access"), value: state.permissionState.screenRecordingGranted ? state.t("Granted") : state.t("Not Granted"))
                CommandGrid {
                    Button {
                        coordinator.requestScreenRecording()
                    } label: {
                        CommandLabel(title: state.t("Request Access"), systemImage: "record.circle")
                    }
                    Button {
                        coordinator.openPrivacySettings()
                    } label: {
                        CommandLabel(title: state.t("Open Privacy Settings"), systemImage: "gearshape")
                    }
                    Button {
                        coordinator.refreshPermissionState()
                    } label: {
                        CommandLabel(title: state.t("Refresh"), systemImage: "arrow.clockwise")
                    }
                    Button {
                        coordinator.restartApp()
                    } label: {
                        CommandLabel(title: state.t("Restart SeaLegs"), systemImage: "power")
                    }
                }
                if state.permissionState.screenRecordingRequested, !state.permissionState.screenRecordingGranted {
                    Text(state.t("After allowing SeaLegs in System Settings, restart SeaLegs, then press Refresh."))
                        .foregroundStyle(.secondary)
                }
            }
            Section(state.t("Metrics")) {
                LabeledContent(state.t("Motion Score"), value: String(format: "%.2f", state.lastScoreResult?.smoothedScore ?? 0))
                LabeledContent(state.t("Peripheral Motion"), value: String(format: "%.2f", state.lastVisualMetrics.meanPeripheralMotion))
                LabeledContent(state.t("Rotation Proxy"), value: String(format: "%.2f", state.lastVisualMetrics.rotationProxy))
                LabeledContent(state.t("Radial Expansion"), value: String(format: "%.2f", state.lastVisualMetrics.radialExpansion))
                LabeledContent(state.t("Visual Cadence Risk"), value: String(format: "%.2f", state.lastCadenceMetrics.visualCadenceRisk))
            }
        }
    }

    private func updateSelectedProfile(_ update: (inout GameProfile) -> Void) {
        coordinator.mutateSelectedProfile(update, preview: false)
    }
}

private struct GameSettingsAssistantView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState

    private var profile: GameProfile? {
        state.selectedProfile
    }
    @State private var confirmChecklistReset = false

    var body: some View {
        Form {
            Section(state.t("Profile")) {
                EditedProfilePicker(coordinator: coordinator, state: state)
            }
            Section(state.t("Game Settings Assistant")) {
                Text(state.t("These recommendations are manual. SeaLegs will not change game files automatically."))
                    .foregroundStyle(.secondary)
                LabeledContent(state.t("Profile"), value: profile?.displayName ?? state.t("None"))
            }
            Section(state.t("Checklist")) {
                if let profile {
                    ForEach(profile.settingsChecklist) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(state.t(item.displayName)) -> \(state.t(item.recommendedValue))")
                                        .font(.headline)
                                    Text(state.t(item.explanation))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(state.localizer.severity(item.severity))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Picker(state.t("Status"), selection: statusBinding(for: item)) {
                                ForEach(RecommendationStatus.allCases) { status in
                                    Text(state.localizer.recommendationStatus(status)).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text(state.t("No profile is available."))
                }
            }
            Section(state.t("Actions")) {
                Button {
                    confirmChecklistReset = true
                } label: {
                    CommandLabel(title: state.t("Reset Checklist for Profile Category"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .disabled(profile == nil)
                .confirmationDialog(state.t("Reset this checklist?"), isPresented: $confirmChecklistReset) {
                    Button(state.t("Reset Checklist"), role: .destructive) {
                        coordinator.mutateSelectedProfile({ profile in
                            profile.settingsChecklist = DefaultGameSettingRecommendations.recommendations(for: profile.category)
                        }, preview: false)
                    }
                    Button(state.t("Cancel"), role: .cancel) {}
                }
            }
        }
    }

    private func statusBinding(for item: GameSettingRecommendation) -> Binding<RecommendationStatus> {
        Binding(
            get: {
                profile?.settingsChecklist.first(where: { $0.id == item.id })?.userStatus ?? item.userStatus
            },
            set: { status in
                coordinator.mutateSelectedProfile({ profile in
                    guard let index = profile.settingsChecklist.firstIndex(where: { $0.id == item.id }) else {
                        return
                    }
                    profile.settingsChecklist[index].userStatus = status
                }, preview: false)
            }
        )
    }
}

private enum CalibrationSensitivity: String, CaseIterable, Identifiable {
    case low
    case normal
    case high
    case veryHigh

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Almost never uncomfortable"
        case .normal: "Sometimes uncomfortable"
        case .high: "Often uncomfortable"
        case .veryHigh: "Very sensitive"
        }
    }
}

private enum CalibrationAnchorPreference: String, CaseIterable, Identifiable {
    case subtleDot
    case crosshair
    case horizon
    case dashboard
    case hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .subtleDot: "Subtle center dot"
        case .crosshair: "Minimal Crosshair"
        case .horizon: "Horizon Guide"
        case .dashboard: "Dashboard Frame"
        case .hidden: "No anchor"
        }
    }
}

extension AppLocalizer {
    static var calibrationAnchorKeysForTesting: [String] {
        CalibrationAnchorPreference.allCases.map(\.label)
    }
}

private struct CalibrationWizardView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    @State private var category: GameCategory = .desktopFPS
    @State private var sensitivity: CalibrationSensitivity = .normal
    @State private var anchorPreference: CalibrationAnchorPreference = .subtleDot
    @State private var confirmApply = false
    @State private var undoProfileSnapshot: GameProfile?

    var body: some View {
        Form {
            Section(state.t("Calibration Wizard")) {
                Text(state.t("Calibration works without Screen Recording permission and updates the selected profile after confirmation."))
                    .foregroundStyle(.secondary)
                EditedProfilePicker(coordinator: coordinator, state: state)
                if state.selectedProfile?.isTemplate == true {
                    Text(state.t("Add a game profile before applying calibration."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Section(state.t("Game Type")) {
                Picker(state.t("Category"), selection: $category) {
                    ForEach(GameCategory.allCases) { category in
                        Text(state.localizer.category(category)).tag(category)
                    }
                }
            }
            Section(state.t("Sensitivity")) {
                Picker(state.t("Sensitivity"), selection: $sensitivity) {
                    ForEach(CalibrationSensitivity.allCases) { sensitivity in
                        Text(state.t(sensitivity.label)).tag(sensitivity)
                    }
                }
            }
            Section(state.t("Visual Anchor")) {
                Picker(state.t("Preference"), selection: $anchorPreference) {
                    ForEach(CalibrationAnchorPreference.allCases) { preference in
                        Text(state.t(preference.label)).tag(preference)
                    }
                }
            }
            Section(state.t("Actions")) {
                CommandGrid {
                    Button {
                        confirmApply = true
                    } label: {
                        CommandLabel(title: state.t("Review / Apply Calibration"), systemImage: "checkmark.circle")
                    }
                    .disabled(state.selectedProfile == nil || state.selectedProfile?.isTemplate == true)
                    Button {
                        if let undoProfileSnapshot {
                            coordinator.restoreProfileSnapshot(undoProfileSnapshot)
                            self.undoProfileSnapshot = nil
                        }
                    } label: {
                        CommandLabel(title: state.t("Undo Last Calibration"), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(undoProfileSnapshot == nil)
                }
            }
        }
        .onAppear(perform: syncFromSelectedProfile)
        .onChange(of: state.selectedProfileID) { _, _ in
            syncFromSelectedProfile()
        }
        .confirmationDialog(state.t("Apply calibration to selected profile?"), isPresented: $confirmApply) {
            Button(state.t("Apply Calibration")) { applyCalibration() }
            Button(state.t("Cancel"), role: .cancel) {}
        } message: {
            Text(state.t("This will update overlay strength, category, and checklist for the selected profile."))
        }
    }

    private func applyCalibration() {
        guard let selectedProfile = state.selectedProfile, !selectedProfile.isTemplate else {
            return
        }
        undoProfileSnapshot = selectedProfile
        coordinator.mutateSelectedProfile { profile in
            profile.category = category
            profile.overlay = calibratedOverlay()
            profile.settingsChecklist = DefaultGameSettingRecommendations.recommendations(for: category)
        }
    }

    private func syncFromSelectedProfile() {
        guard let profile = state.selectedProfile else {
            return
        }
        category = profile.category
        anchorPreference = anchorPreference(for: profile.overlay)
    }

    private func calibratedOverlay() -> OverlayConfig {
        var overlay = DefaultProfiles.profile(for: category).overlay
        switch sensitivity {
        case .low:
            overlay.maxOpacity = max(0, overlay.maxOpacity - 0.10)
            overlay.motionInnerRadius = min(0.98, overlay.motionInnerRadius + 0.08)
        case .normal:
            break
        case .high:
            overlay.maxOpacity = min(0.85, overlay.maxOpacity + 0.08)
            overlay.motionInnerRadius = max(0.45, overlay.motionInnerRadius - 0.06)
            boostAnchors(in: &overlay, amount: 0.04)
        case .veryHigh:
            overlay.maxOpacity = min(0.85, overlay.maxOpacity + 0.14)
            overlay.motionInnerRadius = max(0.45, overlay.motionInnerRadius - 0.10)
            boostAnchors(in: &overlay, amount: 0.08)
        }
        applyAnchorPreference(to: &overlay)
        return overlay
    }

    private func boostAnchors(in overlay: inout OverlayConfig, amount: Float) {
        overlay.centerDot.opacity = min(1, overlay.centerDot.opacity + amount)
        overlay.crosshair.opacity = min(1, overlay.crosshair.opacity + amount)
        overlay.horizon.opacity = min(1, overlay.horizon.opacity + amount)
        overlay.dashboard.opacity = min(1, overlay.dashboard.opacity + amount)
        overlay.virtualNose.opacity = min(1, overlay.virtualNose.opacity + amount)
        overlay.peripheralFrame.opacity = min(1, overlay.peripheralFrame.opacity + amount)
    }

    private func applyAnchorPreference(to overlay: inout OverlayConfig) {
        overlay.centerDot.enabled = false
        overlay.crosshair.enabled = false
        overlay.horizon.enabled = false
        overlay.dashboard.enabled = false
        switch anchorPreference {
        case .subtleDot:
            overlay.centerDot.enabled = true
        case .crosshair:
            overlay.crosshair.enabled = true
        case .horizon:
            overlay.horizon.enabled = true
        case .dashboard:
            overlay.dashboard.enabled = true
        case .hidden:
            break
        }
    }

    private func anchorPreference(for overlay: OverlayConfig) -> CalibrationAnchorPreference {
        if overlay.crosshair.enabled {
            return .crosshair
        }
        if overlay.horizon.enabled {
            return .horizon
        }
        if overlay.dashboard.enabled {
            return .dashboard
        }
        if overlay.centerDot.enabled {
            return .subtleDot
        }
        return .hidden
    }
}

private struct CompatibilityView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    @ObservedObject var overlayState: OverlayState

    var body: some View {
        Form {
            Section(state.t("Compatibility Check")) {
                Text(state.t("Run this check with the game visible to confirm targeting and Adaptive readiness."))
                    .foregroundStyle(.secondary)
                compatibilityRow(
                    title: state.t("Registered Game"),
                    passed: state.activeProfile != nil,
                    value: state.activeProfile == nil ? state.t("Not Active") : state.t("Active")
                )
                compatibilityRow(
                    title: state.t("Overlay Target"),
                    passed: !state.overlayTargetFallbackActive,
                    value: state.t(state.overlayTargetDescription)
                )
                compatibilityRow(
                    title: state.t("Overlay"),
                    passed: overlayState.enabled,
                    value: overlayState.enabled ? state.t("On") : state.t("Off")
                )
                compatibilityRow(
                    title: state.t("Screen Recording"),
                    passed: state.permissionState.screenRecordingGranted,
                    value: state.permissionState.screenRecordingGranted ? state.t("Granted") : state.t("Optional")
                )
                compatibilityRow(
                    title: state.t("Adaptive Samples"),
                    passed: state.currentMode != .adaptive || (
                        state.permissionState.screenRecordingGranted
                            && state.lastSampleReceivedAt.map {
                                state.readinessReferenceDate.timeIntervalSince($0) <= 3
                            } == true
                    ),
                    value: state.localizedCaptureReadinessDescription
                )
                compatibilityRow(
                    title: state.t("Launch at Login"),
                    passed: state.launchAtLoginStatus != .unavailable,
                    value: state.t(state.launchAtLoginStatus.label)
                )
            }
            Section(state.t("Actions")) {
                CommandGrid {
                    Button {
                        coordinator.runCompatibilityCheck()
                    } label: {
                        CommandLabel(title: state.t("Run Overlay Test"), systemImage: "play.circle")
                    }
                    Button {
                        coordinator.copyCompatibilityReport()
                    } label: {
                        CommandLabel(title: state.t("Copy Compatibility Report"), systemImage: "doc.on.clipboard")
                    }
                    Button {
                        coordinator.exportDiagnostics()
                    } label: {
                        CommandLabel(title: state.t("Export Diagnostics..."), systemImage: "square.and.arrow.up")
                    }
                    Button {
                        coordinator.refreshPermissionState()
                        coordinator.refreshLaunchAtLoginStatus()
                    } label: {
                        CommandLabel(title: state.t("Refresh"), systemImage: "arrow.clockwise")
                    }
                }
                Text(state.t(state.compatibilityStatusMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(state.t("Privacy")) {
                Text(state.t("The compatibility report contains operational status only and excludes screenshots, frames, paths, window titles, and raw application identifiers."))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("sealegs.compatibility.page")
        .onAppear {
            coordinator.refreshLaunchAtLoginStatus()
        }
    }

    private func compatibilityRow(title: String, passed: Bool, value: String) -> some View {
        LabeledContent(title) {
            Label(value, systemImage: passed ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(passed ? Color.green : Color.orange)
        }
    }
}

private struct HotkeysView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    private var registrations: [HotkeyRegistrationStatus] {
        state.hotkeyRegistrations
    }

    private var registeredCount: Int {
        registrations.filter(\.registered).count
    }

    var body: some View {
        Form {
            Section(state.t("Registration")) {
                LabeledContent(state.t("Status"), value: "\(registeredCount) / \(registrations.count)")
                Button {
                    coordinator.retryHotkeyRegistration()
                } label: {
                    Label(state.t("Retry Hotkey Registration"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            Section(state.t("Defaults")) {
                ForEach(Array(registrations.enumerated()), id: \.offset) { _, registration in
                    hotkeyRow(registration)
                }
            }
            Section(state.t("Fallback")) {
                Text(state.t("All core actions are also available from the SeaLegs menu bar item."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func hotkeyRow(_ registration: HotkeyRegistrationStatus) -> some View {
        LabeledContent(state.localizer.hotkeyAction(registration.action)) {
            HStack {
                Text(registration.shortcut)
                    .monospaced()
                Text(registration.registered ? state.t("Registered") : String(format: state.t("Unavailable (%d)"), Int(registration.statusCode)))
                    .foregroundStyle(registration.registered ? Color.secondary : Color.red)
            }
        }
    }
}

private struct PrivacyView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    @State private var confirmDeleteLogs = false

    var body: some View {
        Form {
            Section(state.t("Local Analysis")) {
                Text(state.t("Adaptive mode uses Screen Recording to process low-resolution frames locally."))
                Text(state.t("No screenshots, video, audio, OCR, typed text, or raw mouse paths are stored."))
                Text(state.t("Session logs may contain numeric motion metrics, profile identifiers, permission state, optional discomfort ratings, and emergency events."))
            }
            Section(state.t("Permissions")) {
                LabeledContent(state.t("Screen Recording"), value: state.permissionState.screenRecordingGranted ? state.t("Granted") : state.t("Not Granted"))
                LabeledContent(state.t("Screen Recording Requested"), value: state.permissionState.screenRecordingRequested ? state.t("Yes") : state.t("No"))
                CommandGrid {
                    Button {
                        coordinator.requestScreenRecording()
                    } label: {
                        CommandLabel(title: state.t("Request Screen Recording"), systemImage: "record.circle")
                    }
                    Button {
                        coordinator.openPrivacySettings()
                    } label: {
                        CommandLabel(title: state.t("Open Screen Recording Settings"), systemImage: "gearshape")
                    }
                    Button {
                        coordinator.refreshPermissionState()
                    } label: {
                        CommandLabel(title: state.t("Refresh"), systemImage: "arrow.clockwise")
                    }
                    Button {
                        coordinator.restartApp()
                    } label: {
                        CommandLabel(title: state.t("Restart SeaLegs"), systemImage: "power")
                    }
                }
            }
            Section(state.t("Input Signal")) {
                Toggle(state.t("Enable Input Signal"), isOn: Binding(
                    get: { coordinator.privacySettings.inputSignalEnabled },
                    set: { coordinator.setInputSignalEnabled($0) }
                ))
                LabeledContent(
                    state.t("Input Monitoring Access"),
                    value: coordinator.inputMonitoringAccessGranted ? state.t("Granted") : state.t("Not Granted")
                )
                Text(state.t("The input signal preference is saved. macOS permission is requested only when enabled."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CommandGrid {
                    Button {
                        coordinator.openInputMonitoringSettings()
                    } label: {
                        CommandLabel(title: state.t("Open Input Monitoring Settings"), systemImage: "gearshape")
                    }
                    Button {
                        coordinator.refreshPermissionState()
                    } label: {
                        CommandLabel(title: state.t("Refresh"), systemImage: "arrow.clockwise")
                    }
                }
            }
            Section(state.t("Session Logs")) {
                Toggle(state.t("Store numeric session logs"), isOn: Binding(
                    get: { coordinator.telemetrySettings.sessionLoggingEnabled },
                    set: { value in
                        coordinator.updateTelemetrySettings { $0.sessionLoggingEnabled = value }
                    }
                ))
                Stepper(
                    String(format: state.t("Sample interval: %.1fs"), coordinator.telemetrySettings.sessionSampleIntervalSeconds),
                    value: Binding(
                        get: { coordinator.telemetrySettings.sessionSampleIntervalSeconds },
                        set: { value in
                            coordinator.updateTelemetrySettings { $0.sessionSampleIntervalSeconds = max(0.5, value) }
                        }
                    ),
                    in: 0.5...10,
                    step: 0.5
                )
                .disabled(!coordinator.telemetrySettings.sessionLoggingEnabled)
                Stepper(
                    String(format: state.t("Retention: %d days"), coordinator.telemetrySettings.sessionLogRetentionDays),
                    value: Binding(
                        get: { coordinator.telemetrySettings.sessionLogRetentionDays },
                        set: { value in
                            coordinator.updateTelemetrySettings { $0.sessionLogRetentionDays = max(1, value) }
                        }
                    ),
                    in: 1...90
                )
                .disabled(!coordinator.telemetrySettings.sessionLoggingEnabled)
                Button(role: .destructive) {
                    confirmDeleteLogs = true
                } label: {
                    Label(state.t("Delete Stored Session Logs..."), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .confirmationDialog(state.t("Delete all stored session logs?"), isPresented: $confirmDeleteLogs) {
                    Button(state.t("Delete Logs"), role: .destructive) {
                        coordinator.deleteStoredSessionLogs()
                    }
                    Button(state.t("Cancel"), role: .cancel) {}
                }
            }
            Section(state.t("Diagnostics")) {
                Text(state.t("Diagnostics export includes numeric state and salted hashes, not screenshots, videos, OCR, typed text, raw app identifiers, or full paths."))
                    .foregroundStyle(.secondary)
                Button {
                    coordinator.exportDiagnostics()
                } label: {
                    Label(state.t("Export Diagnostics..."), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Text(state.localizedDiagnosticsStatusMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReportsSettingsView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                coordinator.updateSessionReport()
            } label: {
                Label(state.t("Refresh Report"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            SessionReportView(report: state.lastSessionReport, language: state.language)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
