import Foundation

enum DefaultProfiles {
    static var all: [GameProfile] {
        [
            make(category: .desktopFPS, name: "Default - Desktop FPS", overlay: desktopFPSOverlay),
            make(category: .competitiveFPS, name: "Default - Competitive FPS", overlay: competitiveFPSOverlay),
            make(category: .racing, name: "Default - Racing", overlay: racingOverlay),
            make(category: .flightOrSpace, name: "Default - Flight / Space", overlay: flightOverlay),
            make(category: .thirdPersonAction, name: "Default - Third Person", overlay: thirdPersonOverlay),
            make(category: .walkingSimulator, name: "Default - Walking Simulator", overlay: walkingOverlay),
            make(category: .general3D, name: "Default - Gentle", overlay: gentleOverlay),
            make(category: .general3D, name: "Default - Strong Comfort", overlay: strongComfortOverlay)
        ]
    }

    static func profile(for category: GameCategory) -> GameProfile {
        all.first { $0.category == category } ?? make(category: .general3D, name: category.label, overlay: generalOverlay)
    }

    static func customProfile(
        displayName: String,
        bundleIdentifier: String?,
        executableName: String?,
        executablePath: String? = nil,
        category: GameCategory
    ) -> GameProfile {
        var profile = Self.profile(for: category)
        profile.id = UUID()
        profile.displayName = displayName
        profile.bundleIdentifier = bundleIdentifier
        profile.executableName = executableName
        profile.executablePathHash = executablePath.map(GameProfile.stableHash(_:))
        profile.createdAt = Date()
        profile.updatedAt = Date()
        return profile
    }

    private static func make(category: GameCategory, name: String, overlay: OverlayConfig) -> GameProfile {
        GameProfile(
            displayName: name,
            category: category,
            overlay: overlay,
            adaptive: .standard,
            feedback: .standard
        )
    }

    private static let desktopFPSOverlay = OverlayConfig(
        mode: .adaptive,
        baseOpacity: 0.10,
        maxOpacity: 0.55,
        emergencyOpacity: 0.72,
        restInnerRadius: 0.92,
        motionInnerRadius: 0.66,
        emergencyInnerRadius: 0.54,
        outerRadius: 1.12,
        rampInSeconds: 0.12,
        rampOutSeconds: 0.80,
        centerDot: GuideConfig(enabled: true, opacity: 0.30, size: 3.4),
        crosshair: GuideConfig(enabled: false, opacity: 0.16, size: 22.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.12, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.14, size: 1.4)
    )

    private static let competitiveFPSOverlay = OverlayConfig(
        mode: .medium,
        baseOpacity: 0.02,
        maxOpacity: 0.36,
        emergencyOpacity: 0.62,
        restInnerRadius: 0.97,
        motionInnerRadius: 0.78,
        emergencyInnerRadius: 0.62,
        outerRadius: 1.12,
        rampInSeconds: 0.12,
        rampOutSeconds: 0.75,
        centerDot: GuideConfig(enabled: true, opacity: 0.24, size: 2.8),
        crosshair: GuideConfig(enabled: false, opacity: 0.12, size: 18.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.10, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.08, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.08, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.10, size: 1.2)
    )

    private static let racingOverlay = OverlayConfig(
        mode: .adaptive,
        baseOpacity: 0.12,
        maxOpacity: 0.62,
        emergencyOpacity: 0.78,
        restInnerRadius: 0.90,
        motionInnerRadius: 0.60,
        emergencyInnerRadius: 0.50,
        outerRadius: 1.12,
        rampInSeconds: 0.10,
        rampOutSeconds: 1.00,
        centerDot: GuideConfig(enabled: false, opacity: 0.12, size: 3.0),
        crosshair: GuideConfig(enabled: false, opacity: 0.12, size: 22.0),
        horizon: HorizonConfig(enabled: true, opacity: 0.24, y: 0.52),
        dashboard: GuideConfig(enabled: true, opacity: 0.18, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.12, size: 1.4)
    )

    private static let flightOverlay = OverlayConfig(
        mode: .adaptive,
        baseOpacity: 0.10,
        maxOpacity: 0.68,
        emergencyOpacity: 0.80,
        restInnerRadius: 0.92,
        motionInnerRadius: 0.58,
        emergencyInnerRadius: 0.48,
        outerRadius: 1.12,
        rampInSeconds: 0.10,
        rampOutSeconds: 1.10,
        centerDot: GuideConfig(enabled: true, opacity: 0.22, size: 3.2),
        crosshair: GuideConfig(enabled: false, opacity: 0.12, size: 22.0),
        horizon: HorizonConfig(enabled: true, opacity: 0.28, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.14, size: 1.4)
    )

    private static let thirdPersonOverlay = OverlayConfig(
        mode: .adaptive,
        baseOpacity: 0.06,
        maxOpacity: 0.42,
        emergencyOpacity: 0.66,
        restInnerRadius: 0.94,
        motionInnerRadius: 0.72,
        emergencyInnerRadius: 0.58,
        outerRadius: 1.12,
        rampInSeconds: 0.14,
        rampOutSeconds: 0.90,
        centerDot: GuideConfig(enabled: true, opacity: 0.18, size: 3.0),
        crosshair: GuideConfig(enabled: false, opacity: 0.10, size: 22.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.10, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        virtualNose: GuideConfig(enabled: true, opacity: 0.14, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.10, size: 1.2)
    )

    private static let walkingOverlay = OverlayConfig(
        mode: .adaptive,
        baseOpacity: 0.08,
        maxOpacity: 0.48,
        emergencyOpacity: 0.68,
        restInnerRadius: 0.93,
        motionInnerRadius: 0.68,
        emergencyInnerRadius: 0.56,
        outerRadius: 1.12,
        rampInSeconds: 0.14,
        rampOutSeconds: 0.95,
        centerDot: GuideConfig(enabled: true, opacity: 0.24, size: 3.2),
        crosshair: GuideConfig(enabled: false, opacity: 0.12, size: 22.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.12, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        virtualNose: GuideConfig(enabled: true, opacity: 0.16, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.10, size: 1.2)
    )

    private static let generalOverlay = OverlayConfig(
        mode: .medium,
        baseOpacity: 0.08,
        maxOpacity: 0.48,
        emergencyOpacity: 0.70,
        restInnerRadius: 0.93,
        motionInnerRadius: 0.70,
        emergencyInnerRadius: 0.56,
        outerRadius: 1.12,
        rampInSeconds: 0.14,
        rampOutSeconds: 0.90,
        centerDot: GuideConfig(enabled: true, opacity: 0.24, size: 3.2),
        crosshair: GuideConfig(enabled: false, opacity: 0.12, size: 22.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.12, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.10, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.12, size: 1.2)
    )

    private static let gentleOverlay = OverlayConfig(
        mode: .low,
        baseOpacity: 0.04,
        maxOpacity: 0.30,
        emergencyOpacity: 0.58,
        restInnerRadius: 0.96,
        motionInnerRadius: 0.78,
        emergencyInnerRadius: 0.62,
        outerRadius: 1.12,
        rampInSeconds: 0.16,
        rampOutSeconds: 1.00,
        centerDot: GuideConfig(enabled: true, opacity: 0.18, size: 2.8),
        crosshair: GuideConfig(enabled: false, opacity: 0.10, size: 18.0),
        horizon: HorizonConfig(enabled: false, opacity: 0.10, y: 0.50),
        dashboard: GuideConfig(enabled: false, opacity: 0.08, size: 1.0),
        virtualNose: GuideConfig(enabled: false, opacity: 0.08, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.08, size: 1.0)
    )

    private static let strongComfortOverlay = OverlayConfig(
        mode: .high,
        baseOpacity: 0.18,
        maxOpacity: 0.72,
        emergencyOpacity: 0.82,
        restInnerRadius: 0.88,
        motionInnerRadius: 0.56,
        emergencyInnerRadius: 0.46,
        outerRadius: 1.12,
        rampInSeconds: 0.10,
        rampOutSeconds: 1.15,
        centerDot: GuideConfig(enabled: true, opacity: 0.34, size: 3.6),
        crosshair: GuideConfig(enabled: false, opacity: 0.18, size: 22.0),
        horizon: HorizonConfig(enabled: true, opacity: 0.26, y: 0.52),
        dashboard: GuideConfig(enabled: false, opacity: 0.12, size: 1.0),
        virtualNose: GuideConfig(enabled: true, opacity: 0.20, size: 1.0),
        peripheralFrame: GuideConfig(enabled: true, opacity: 0.16, size: 1.6)
    )
}
