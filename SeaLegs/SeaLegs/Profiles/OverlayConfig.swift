import Foundation

enum ComfortMode: String, Codable, CaseIterable, Identifiable {
    case off
    case low
    case medium
    case high
    case adaptive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .adaptive: "Adaptive"
        }
    }
}

enum VisualAnchorType: String, Codable, CaseIterable, Identifiable {
    case centerDot
    case minimalCrosshair
    case horizonLine
    case lowerDashboard
    case virtualNose
    case peripheralFrame

    var id: String { rawValue }

    var label: String {
        switch self {
        case .centerDot: "Center Dot"
        case .minimalCrosshair: "Minimal Crosshair"
        case .horizonLine: "Horizon Guide"
        case .lowerDashboard: "Dashboard Frame"
        case .virtualNose: "Virtual Nose"
        case .peripheralFrame: "Peripheral Frame"
        }
    }
}

enum AnchorColorMode: String, Codable, CaseIterable, Identifiable {
    case neutralLight
    case neutralDark
    case adaptiveContrast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neutralLight: "Neutral Light"
        case .neutralDark: "Neutral Dark"
        case .adaptiveContrast: "Adaptive Contrast"
        }
    }
}

struct GuideConfig: Codable, Equatable {
    var enabled: Bool
    var opacity: Float
    var size: Float

    /// Normalized anchor position for controls that can be moved in screen space.
    var positionX: Float
    var positionY: Float
    var autoBoostInMotion: Bool
    var hideWhenIdle: Bool
    var colorMode: AnchorColorMode

    init(
        enabled: Bool,
        opacity: Float,
        size: Float,
        positionX: Float = 0.5,
        positionY: Float = 0.5,
        autoBoostInMotion: Bool = true,
        hideWhenIdle: Bool = false,
        colorMode: AnchorColorMode = .neutralDark
    ) {
        self.enabled = enabled
        self.opacity = opacity
        self.size = size
        self.positionX = positionX
        self.positionY = positionY
        self.autoBoostInMotion = autoBoostInMotion
        self.hideWhenIdle = hideWhenIdle
        self.colorMode = colorMode
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case opacity
        case size
        case positionX
        case positionY
        case autoBoostInMotion
        case hideWhenIdle
        case colorMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        opacity = try container.decode(Float.self, forKey: .opacity)
        size = try container.decode(Float.self, forKey: .size)
        positionX = try container.decodeIfPresent(Float.self, forKey: .positionX) ?? 0.5
        positionY = try container.decodeIfPresent(Float.self, forKey: .positionY) ?? 0.5
        autoBoostInMotion = try container.decodeIfPresent(Bool.self, forKey: .autoBoostInMotion) ?? true
        hideWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .hideWhenIdle) ?? false
        colorMode = try container.decodeIfPresent(AnchorColorMode.self, forKey: .colorMode) ?? .neutralDark
    }
}

struct HorizonConfig: Codable, Equatable {
    var enabled: Bool
    var opacity: Float
    var y: Float

    init(enabled: Bool, opacity: Float, y: Float) {
        self.enabled = enabled
        self.opacity = opacity
        self.y = y
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case opacity
        case y
    }
}

struct OverlayConfig: Codable, Equatable {
    var mode: ComfortMode
    var baseOpacity: Float
    var maxOpacity: Float
    var emergencyOpacity: Float
    var restInnerRadius: Float
    var motionInnerRadius: Float
    var emergencyInnerRadius: Float
    var outerRadius: Float
    var rampInSeconds: Float
    var rampOutSeconds: Float
    var centerDot: GuideConfig
    var crosshair: GuideConfig
    var horizon: HorizonConfig
    var dashboard: GuideConfig
    var virtualNose: GuideConfig
    var peripheralFrame: GuideConfig

    init(
        mode: ComfortMode,
        baseOpacity: Float,
        maxOpacity: Float,
        emergencyOpacity: Float,
        restInnerRadius: Float,
        motionInnerRadius: Float,
        emergencyInnerRadius: Float,
        outerRadius: Float,
        rampInSeconds: Float,
        rampOutSeconds: Float,
        centerDot: GuideConfig,
        crosshair: GuideConfig,
        horizon: HorizonConfig,
        dashboard: GuideConfig,
        virtualNose: GuideConfig,
        peripheralFrame: GuideConfig = GuideConfig(enabled: false, opacity: 0.08, size: 1.0)
    ) {
        self.mode = mode
        self.baseOpacity = baseOpacity
        self.maxOpacity = maxOpacity
        self.emergencyOpacity = emergencyOpacity
        self.restInnerRadius = restInnerRadius
        self.motionInnerRadius = motionInnerRadius
        self.emergencyInnerRadius = emergencyInnerRadius
        self.outerRadius = outerRadius
        self.rampInSeconds = rampInSeconds
        self.rampOutSeconds = rampOutSeconds
        self.centerDot = centerDot
        self.crosshair = crosshair
        self.horizon = horizon
        self.dashboard = dashboard
        self.virtualNose = virtualNose
        self.peripheralFrame = peripheralFrame
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case baseOpacity
        case maxOpacity
        case emergencyOpacity
        case restInnerRadius
        case motionInnerRadius
        case emergencyInnerRadius
        case outerRadius
        case rampInSeconds
        case rampOutSeconds
        case centerDot
        case crosshair
        case horizon
        case dashboard
        case virtualNose
        case peripheralFrame
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(ComfortMode.self, forKey: .mode)
        baseOpacity = try container.decode(Float.self, forKey: .baseOpacity)
        maxOpacity = try container.decode(Float.self, forKey: .maxOpacity)
        emergencyOpacity = try container.decode(Float.self, forKey: .emergencyOpacity)
        restInnerRadius = try container.decode(Float.self, forKey: .restInnerRadius)
        motionInnerRadius = try container.decode(Float.self, forKey: .motionInnerRadius)
        emergencyInnerRadius = try container.decode(Float.self, forKey: .emergencyInnerRadius)
        outerRadius = try container.decode(Float.self, forKey: .outerRadius)
        rampInSeconds = try container.decode(Float.self, forKey: .rampInSeconds)
        rampOutSeconds = try container.decode(Float.self, forKey: .rampOutSeconds)
        centerDot = try container.decode(GuideConfig.self, forKey: .centerDot)
        crosshair = try container.decode(GuideConfig.self, forKey: .crosshair)
        horizon = try container.decode(HorizonConfig.self, forKey: .horizon)
        dashboard = try container.decode(GuideConfig.self, forKey: .dashboard)
        virtualNose = try container.decode(GuideConfig.self, forKey: .virtualNose)
        peripheralFrame = try container.decodeIfPresent(GuideConfig.self, forKey: .peripheralFrame)
            ?? GuideConfig(enabled: false, opacity: 0.08, size: 1.0)
    }

    func staticStrength(for mode: ComfortMode) -> OverlayStrength {
        switch mode {
        case .off:
            OverlayStrength(opacity: 0, innerRadius: restInnerRadius)
        case .low:
            OverlayStrength(opacity: max(baseOpacity, maxOpacity * 0.35), innerRadius: mix(restInnerRadius, motionInnerRadius, 0.35))
        case .medium:
            OverlayStrength(opacity: max(baseOpacity, maxOpacity * 0.65), innerRadius: mix(restInnerRadius, motionInnerRadius, 0.65))
        case .high:
            OverlayStrength(opacity: maxOpacity, innerRadius: motionInnerRadius)
        case .adaptive:
            OverlayStrength(opacity: baseOpacity, innerRadius: restInnerRadius)
        }
    }

    func highVisibilityDemo() -> OverlayConfig {
        var demo = self
        demo.mode = .high
        demo.baseOpacity = max(baseOpacity, 0.18)
        demo.maxOpacity = max(maxOpacity, 0.62)
        demo.motionInnerRadius = min(motionInnerRadius, 0.60)
        demo.centerDot = GuideConfig(enabled: true, opacity: 0.58, size: 4.0)
        demo.crosshair = GuideConfig(enabled: true, opacity: 0.34, size: 34.0)
        demo.horizon = HorizonConfig(enabled: true, opacity: 0.36, y: horizon.y)
        demo.dashboard = GuideConfig(enabled: true, opacity: 0.20, size: 1.0)
        demo.virtualNose = GuideConfig(enabled: true, opacity: 0.24, size: 1.0)
        demo.peripheralFrame = GuideConfig(enabled: true, opacity: 0.24, size: 2.0)
        return demo
    }

    var visibleAnchorCount: Int {
        [
            centerDot.enabled,
            crosshair.enabled,
            horizon.enabled,
            dashboard.enabled,
            virtualNose.enabled,
            peripheralFrame.enabled
        ].filter(\.self).count
    }
}

struct OverlayStrength: Codable, Equatable {
    var opacity: Float
    var innerRadius: Float
}

struct AdaptiveConfig: Codable, Equatable {
    var enabled: Bool
    var analysisFramesPerSecond: Int
    var captureWidth: Int
    var captureHeight: Int
    var analysisWidth: Int
    var analysisHeight: Int
    var lowPowerMode: Bool

    static let standard = AdaptiveConfig(
        enabled: true,
        analysisFramesPerSecond: 24,
        captureWidth: 320,
        captureHeight: 180,
        analysisWidth: 160,
        analysisHeight: 90,
        lowPowerMode: false
    )

    var effectiveFramesPerSecond: Int {
        lowPowerMode ? min(max(1, analysisFramesPerSecond), 12) : max(1, analysisFramesPerSecond)
    }

    var effectiveAnalysisWidth: Int {
        lowPowerMode ? max(80, analysisWidth / 2) : max(40, analysisWidth)
    }

    var effectiveAnalysisHeight: Int {
        lowPowerMode ? max(45, analysisHeight / 2) : max(30, analysisHeight)
    }

    var effectiveQueueDepth: Int {
        lowPowerMode ? 2 : 3
    }
}

struct FeedbackConfig: Codable, Equatable {
    var periodicPromptEnabled: Bool
    var promptIntervalMinutes: Int

    static let standard = FeedbackConfig(periodicPromptEnabled: false, promptIntervalMinutes: 10)
}

func clamp(_ value: Float, _ lower: Float = 0, _ upper: Float = 1) -> Float {
    min(upper, max(lower, value))
}

func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * clamp(t)
}

func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = clamp((x - edge0) / max(edge1 - edge0, 0.0001))
    return t * t * (3 - 2 * t)
}
