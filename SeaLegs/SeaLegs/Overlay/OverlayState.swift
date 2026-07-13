import Foundation

@MainActor
final class OverlayState: ObservableObject {
    @Published var enabled = false
    @Published var emergencyActive = false
    @Published var vignetteOpacity: Float = 0
    @Published var vignetteInnerRadius: Float = 0.92
    @Published var vignetteOuterRadius: Float = 1.12
    @Published var vignetteSoftness: Float = 0.12
    @Published var centerDotEnabled = true
    @Published var centerDotOpacity: Float = 0.18
    @Published var centerDotRadius: Float = 3
    @Published var centerDotPositionX: Float = 0.5
    @Published var centerDotPositionY: Float = 0.5
    @Published var crosshairEnabled = false
    @Published var crosshairOpacity: Float = 0.16
    @Published var crosshairLength: Float = 22
    @Published var crosshairThickness: Float = 1
    @Published var crosshairPositionX: Float = 0.5
    @Published var crosshairPositionY: Float = 0.5
    @Published var horizonEnabled = false
    @Published var horizonOpacity: Float = 0.12
    @Published var horizonY: Float = 0.50
    @Published var dashboardEnabled = false
    @Published var dashboardOpacity: Float = 0.12
    @Published var virtualNoseEnabled = false
    @Published var virtualNoseOpacity: Float = 0.10
    @Published var peripheralFrameEnabled = false
    @Published var peripheralFrameOpacity: Float = 0.08
    @Published var peripheralFrameThickness: Float = 1.0

    func apply(config: OverlayConfig, mode: ComfortMode) {
        let strength = config.staticStrength(for: mode)
        apply(config: config, strength: strength)
        enabled = mode != .off
    }

    func apply(config: OverlayConfig, strength: OverlayStrength) {
        vignetteOpacity = emergencyActive ? max(strength.opacity, config.emergencyOpacity) : strength.opacity
        vignetteInnerRadius = emergencyActive ? min(strength.innerRadius, config.emergencyInnerRadius) : strength.innerRadius
        vignetteOuterRadius = config.outerRadius
        centerDotEnabled = config.centerDot.enabled
        centerDotOpacity = anchorOpacity(config.centerDot, strength: strength, overlay: config)
        centerDotRadius = config.centerDot.size
        centerDotPositionX = normalizedPosition(config.centerDot.positionX)
        centerDotPositionY = normalizedPosition(config.centerDot.positionY)
        crosshairEnabled = config.crosshair.enabled
        crosshairOpacity = anchorOpacity(config.crosshair, strength: strength, overlay: config)
        crosshairLength = config.crosshair.size
        crosshairPositionX = normalizedPosition(config.crosshair.positionX)
        crosshairPositionY = normalizedPosition(config.crosshair.positionY)
        horizonEnabled = config.horizon.enabled
        horizonOpacity = anchorOpacity(config.horizon.opacity)
        horizonY = config.horizon.y
        dashboardEnabled = config.dashboard.enabled
        dashboardOpacity = anchorOpacity(config.dashboard, strength: strength, overlay: config)
        virtualNoseEnabled = config.virtualNose.enabled
        virtualNoseOpacity = anchorOpacity(config.virtualNose, strength: strength, overlay: config)
        peripheralFrameEnabled = config.peripheralFrame.enabled
        peripheralFrameOpacity = anchorOpacity(config.peripheralFrame, strength: strength, overlay: config)
        peripheralFrameThickness = max(1, config.peripheralFrame.size)
    }

    func deactivate() {
        enabled = false
        emergencyActive = false
        vignetteOpacity = 0
    }

    private func anchorOpacity(_ guide: GuideConfig, strength: OverlayStrength, overlay: OverlayConfig) -> Float {
        if emergencyActive {
            return min(1, max(guide.opacity, 0.32))
        }
        let opacityRange = max(overlay.maxOpacity - overlay.baseOpacity, 0.001)
        let motionProgress = clamp((strength.opacity - overlay.baseOpacity) / opacityRange)
        let visibility = guide.hideWhenIdle ? smoothstep(0.05, 0.25, motionProgress) : 1
        let boost = guide.autoBoostInMotion ? mix(1, 1.45, motionProgress) : 1
        return clamp(guide.opacity * visibility * boost)
    }

    private func anchorOpacity(_ opacity: Float) -> Float {
        emergencyActive ? min(1, max(opacity, 0.32)) : opacity
    }

    private func normalizedPosition(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
