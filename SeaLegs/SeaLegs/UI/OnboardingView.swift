import SwiftUI

struct OnboardingView: View {
    let coordinator: AppCoordinator
    let onComplete: () -> Void
    @ObservedObject private var state: AppState
    @ObservedObject private var overlayState: OverlayState
    @State private var didTestOverlay = false
    @State private var attemptedAppRegistration = false
    @State private var attemptedAdaptiveAccess = false

    init(coordinator: AppCoordinator, onComplete: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onComplete = onComplete
        self.state = coordinator.state
        self.overlayState = coordinator.overlayState
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SeaLegs")
                    .font(.largeTitle.weight(.semibold))
                Text(state.t("Comfort overlay for macOS 3D games."))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    OnboardingStepRow(
                        icon: "rectangle.on.rectangle",
                        title: state.t("Test Overlay"),
                        detail: state.t("Feature demo temporarily shows every visible aid at high contrast, without changing the selected profile."),
                        status: state.t(overlayWasTested ? "Overlay tested" : "Ready to test"),
                        statusIcon: overlayWasTested ? "checkmark.circle.fill" : "circle",
                        statusColor: overlayWasTested ? .green : .secondary,
                        actionTitle: state.t("Test Overlay"),
                        actionIcon: "sparkles"
                    ) {
                        coordinator.showFeatureDemoOverlay()
                        didTestOverlay = true
                    }

                    Divider()

                    OnboardingStepRow(
                        icon: "plus.app",
                        title: state.t("Add Current App as Game"),
                        detail: state.t("Bring the game to the front once, return to SeaLegs, then add it."),
                        status: appRegistrationStatus,
                        statusIcon: registeredProfile == nil ? (attemptedAppRegistration ? "exclamationmark.circle" : "circle") : "checkmark.circle.fill",
                        statusColor: registeredProfile == nil ? (attemptedAppRegistration ? .orange : .secondary) : .green,
                        actionTitle: state.t("Add Current App as Game"),
                        actionIcon: "plus.app"
                    ) {
                        attemptedAppRegistration = true
                        coordinator.addCurrentAppAsGame()
                    }

                    Divider()

                    OnboardingStepRow(
                        icon: "waveform.path",
                        title: state.t("Adaptive Mode (Optional)"),
                        detail: state.t("Screen Recording is only needed for Adaptive mode. Basic overlay works without permissions."),
                        status: adaptiveAccessStatus,
                        statusIcon: state.permissionState.screenRecordingGranted ? "checkmark.circle.fill" : "circle.dashed",
                        statusColor: state.permissionState.screenRecordingGranted ? .green : .secondary,
                        actionTitle: state.t("Enable Adaptive Mode"),
                        actionIcon: "waveform.path"
                    ) {
                        attemptedAdaptiveAccess = true
                        coordinator.requestScreenRecording()
                        coordinator.setSelectedProfileMode(.adaptive)
                    }

                    Label {
                        Text(state.localizedStatusMessage)
                            .lineLimit(3)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    coordinator.openSettingsHandler?()
                } label: {
                    Label(state.t("Open Settings"), systemImage: "gearshape")
                }
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Label(state.t("Skip for Now"), systemImage: "forward.end")
                }
                Button {
                    onComplete()
                } label: {
                    Label(state.t("Done"), systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!overlayWasTested)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 430)
    }

    private var overlayWasTested: Bool {
        didTestOverlay || overlayState.enabled
    }

    private var registeredProfile: GameProfile? {
        if let activeProfile = state.activeProfile, !activeProfile.isTemplate {
            return activeProfile
        }
        if let selectedProfile = state.selectedProfile, !selectedProfile.isTemplate {
            return selectedProfile
        }
        return nil
    }

    private var appRegistrationStatus: String {
        if let registeredProfile {
            return "\(registeredProfile.displayName) · \(state.t("Registered"))"
        }
        return attemptedAppRegistration ? state.localizedStatusMessage : state.t("No app added")
    }

    private var adaptiveAccessStatus: String {
        if state.permissionState.screenRecordingGranted {
            return state.t("Granted")
        }
        if attemptedAdaptiveAccess || state.permissionState.screenRecordingRequested {
            return state.t("Access requested")
        }
        return state.t("Optional step")
    }

}

private struct OnboardingStepRow: View {
    let icon: String
    let title: String
    let detail: String
    let status: String
    let statusIcon: String
    let statusColor: Color
    let actionTitle: String
    let actionIcon: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(status, systemImage: statusIcon)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }
            }
            Button(action: action) {
                Label(actionTitle, systemImage: actionIcon)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.bordered)
            .padding(.leading, 36)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }
}
