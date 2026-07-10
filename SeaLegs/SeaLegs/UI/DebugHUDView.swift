import SwiftUI

struct DebugHUDView: View {
    @ObservedObject var state: AppState
    @ObservedObject var overlayState: OverlayState

    var body: some View {
        Form {
            Section(state.t("Game")) {
                LabeledContent(state.t("Game"), value: state.localizedCurrentGameName)
                LabeledContent(state.t("Profile"), value: state.activeProfile.map { state.localizer.category($0.category) } ?? "-")
                LabeledContent(state.t("Mode"), value: state.localizer.mode(state.currentMode))
            }
            Section(state.t("Motion")) {
                LabeledContent(state.t("Motion Score"), value: String(format: "%.2f", state.lastScoreResult?.smoothedScore ?? 0))
                LabeledContent(state.t("Readiness"), value: state.localizedCaptureReadinessDescription)
                LabeledContent(state.t("Last Sample"), value: lastSampleDescription)
                LabeledContent(state.t("Peripheral Motion"), value: String(format: "%.2f", state.lastVisualMetrics.meanPeripheralMotion))
                LabeledContent(state.t("Rotation Proxy"), value: String(format: "%.2f", state.lastVisualMetrics.rotationProxy))
                LabeledContent(state.t("Radial Expansion"), value: String(format: "%.2f", state.lastVisualMetrics.radialExpansion))
                LabeledContent(state.t("Visual Cadence Risk"), value: String(format: "%.2f", state.lastCadenceMetrics.visualCadenceRisk))
            }
            Section(state.t("Overlay")) {
                LabeledContent(state.t("Vignette"), value: "\(state.t("Opacity")) \(String(format: "%.2f", overlayState.vignetteOpacity)) / \(state.t("Inner Radius")) \(String(format: "%.2f", overlayState.vignetteInnerRadius))")
                LabeledContent(state.t("Capture"), value: state.localizedCaptureModeDescription)
            }
        }
    }

    private var lastSampleDescription: String {
        guard let lastSampleReceivedAt = state.lastSampleReceivedAt else {
            return state.t("No samples yet")
        }
        return String(format: state.t("%.1fs ago"), Date().timeIntervalSince(lastSampleReceivedAt))
    }
}
