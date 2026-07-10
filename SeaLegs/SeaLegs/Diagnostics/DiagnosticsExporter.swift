import Foundation
import CryptoKit

struct DiagnosticsTargetInput: Equatable {
    let processIdentifier: Int?
    let bundleIdentifier: String?
    let executablePath: String?
    let windowTitle: String?
    let captureModeDescription: String?

    init(
        processIdentifier: Int? = nil,
        bundleIdentifier: String? = nil,
        executablePath: String? = nil,
        windowTitle: String? = nil,
        captureModeDescription: String? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.windowTitle = windowTitle
        self.captureModeDescription = captureModeDescription
    }

    init(appInfo: RunningAppInfo, windowTitle: String? = nil, captureModeDescription: String? = nil) {
        self.init(
            processIdentifier: Int(appInfo.processIdentifier),
            bundleIdentifier: appInfo.bundleIdentifier,
            executablePath: appInfo.executableURL?.path,
            windowTitle: windowTitle,
            captureModeDescription: captureModeDescription
        )
    }
}

struct DiagnosticsExportSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: Date
    let app: DiagnosticsAppSnapshot
    let state: DiagnosticsStateSnapshot
    let overlay: DiagnosticsOverlaySnapshot
    let motion: DiagnosticsMotionSnapshot
    let session: DiagnosticsSessionSnapshot?
    let target: DiagnosticsTargetSnapshot?
}

struct DiagnosticsAppSnapshot: Codable, Equatable {
    let name: String
    let bundleIdentifier: String
    let supportedMacOS: String
}

struct DiagnosticsStateSnapshot: Codable, Equatable {
    let profileCount: Int
    let activeProfileIDHash: String?
    let activeProfileNameHash: String?
    let activeProfileCategory: GameCategory?
    let currentMode: ComfortMode
    let permissionState: PermissionState
    let debugHUDVisible: Bool
    let captureModeDescription: String
    let statusMessageHash: String
    let statusMessageCharacterCount: Int

    init(
        profileCount: Int,
        activeProfileIDHash: String?,
        activeProfileNameHash: String?,
        activeProfileCategory: GameCategory?,
        currentMode: ComfortMode,
        permissionState: PermissionState,
        debugHUDVisible: Bool,
        captureModeDescription: String,
        statusMessage: String,
        redactionSalt: String = UUID().uuidString
    ) {
        self.profileCount = profileCount
        self.activeProfileIDHash = activeProfileIDHash
        self.activeProfileNameHash = activeProfileNameHash
        self.activeProfileCategory = activeProfileCategory
        self.currentMode = currentMode
        self.permissionState = permissionState
        self.debugHUDVisible = debugHUDVisible
        self.captureModeDescription = captureModeDescription
        self.statusMessageHash = DiagnosticsRedactor.hash(statusMessage, salt: redactionSalt)
        self.statusMessageCharacterCount = statusMessage.count
    }
}

struct DiagnosticsOverlaySnapshot: Codable, Equatable {
    let enabled: Bool
    let emergencyActive: Bool
    let vignetteOpacity: Float
    let vignetteInnerRadius: Float
    let vignetteOuterRadius: Float
    let vignetteSoftness: Float
    let centerDotEnabled: Bool
    let centerDotOpacity: Float
    let centerDotRadius: Float
    let crosshairEnabled: Bool
    let crosshairOpacity: Float
    let crosshairLength: Float
    let crosshairThickness: Float
    let horizonEnabled: Bool
    let horizonOpacity: Float
    let horizonY: Float
    let dashboardEnabled: Bool
    let dashboardOpacity: Float
    let virtualNoseEnabled: Bool
    let virtualNoseOpacity: Float
    let peripheralFrameEnabled: Bool
    let peripheralFrameOpacity: Float
    let peripheralFrameThickness: Float
}

struct DiagnosticsMotionSnapshot: Codable, Equatable {
    let visual: VisualMotionMetrics
    let cadence: VisualCadenceMetrics
    let scoreResult: MotionScoreResult?

    static let zero = DiagnosticsMotionSnapshot(
        visual: .zero,
        cadence: .stable,
        scoreResult: nil
    )
}

struct DiagnosticsSessionSnapshot: Codable, Equatable {
    let durationSeconds: TimeInterval
    let averageMotionScore: Float
    let peakMotionScore: Float
    let averageDiscomfortScore: Float?
    let peakDiscomfortScore: Int?
    let emergencyCount: Int
    let highRiskMomentCount: Int
    let recommendationCount: Int

    init(report: SessionReport) {
        durationSeconds = report.durationSeconds
        averageMotionScore = report.averageMotionScore
        peakMotionScore = report.peakMotionScore
        averageDiscomfortScore = report.averageDiscomfortScore
        peakDiscomfortScore = report.peakDiscomfortScore
        emergencyCount = report.emergencyCount
        highRiskMomentCount = report.highRiskMoments.count
        recommendationCount = report.recommendations.count
    }
}

struct DiagnosticsTargetSnapshot: Codable, Equatable {
    let processIdentifierHash: String?
    let bundleIdentifierHash: String?
    let bundleIdentifierCharacterCount: Int?
    let executableNameHash: String?
    let executableNameCharacterCount: Int?
    let executablePathHash: String?
    let executablePathComponentCount: Int?
    let windowTitleHash: String?
    let windowTitleCharacterCount: Int?
    let captureModeDescription: String?

    init(input: DiagnosticsTargetInput, salt: String) {
        let executableName = input.executablePath.map { URL(fileURLWithPath: $0).lastPathComponent }.nilIfEmpty
        processIdentifierHash = input.processIdentifier.map { DiagnosticsRedactor.hash(String($0), salt: salt) }
        bundleIdentifierHash = input.bundleIdentifier.nilIfEmpty.map { DiagnosticsRedactor.hash($0, salt: salt) }
        bundleIdentifierCharacterCount = input.bundleIdentifier?.count
        executableNameHash = executableName.map { DiagnosticsRedactor.hash($0, salt: salt) }
        executableNameCharacterCount = executableName?.count
        executablePathHash = input.executablePath.map { DiagnosticsRedactor.hash($0, salt: salt) }
        executablePathComponentCount = input.executablePath.map(DiagnosticsRedactor.pathComponentCount(_:))
        windowTitleHash = input.windowTitle.map { DiagnosticsRedactor.hash($0, salt: salt) }
        windowTitleCharacterCount = input.windowTitle?.count
        captureModeDescription = input.captureModeDescription
    }
}

enum DiagnosticsExporter {
    static func makeSnapshot(
        state: DiagnosticsStateSnapshot,
        overlay: DiagnosticsOverlaySnapshot,
        motion: DiagnosticsMotionSnapshot = .zero,
        session: DiagnosticsSessionSnapshot? = nil,
        target: DiagnosticsTargetInput? = nil,
        generatedAt: Date = Date(),
        redactionSalt: String = UUID().uuidString
    ) -> DiagnosticsExportSnapshot {
        DiagnosticsExportSnapshot(
            schemaVersion: AppConstants.schemaVersion,
            generatedAt: generatedAt,
            app: DiagnosticsAppSnapshot(
                name: AppConstants.appName,
                bundleIdentifier: AppConstants.bundleIdentifier,
                supportedMacOS: AppConstants.supportedMacOS
            ),
            state: state,
            overlay: overlay,
            motion: motion,
            session: session,
            target: target.map { DiagnosticsTargetSnapshot(input: $0, salt: redactionSalt) }
        )
    }

    @MainActor
    static func makeSnapshot(
        appState: AppState,
        overlayState: OverlayState,
        target: DiagnosticsTargetInput? = nil,
        generatedAt: Date = Date(),
        redactionSalt: String = UUID().uuidString
    ) -> DiagnosticsExportSnapshot {
        let resolvedTarget = target ?? appState.currentApp.map {
            DiagnosticsTargetInput(appInfo: $0, captureModeDescription: appState.captureModeDescription)
        }
        return makeSnapshot(
            state: DiagnosticsStateSnapshot(appState: appState, salt: redactionSalt),
            overlay: DiagnosticsOverlaySnapshot(overlayState: overlayState),
            motion: DiagnosticsMotionSnapshot(appState: appState),
            session: appState.lastSessionReport.map(DiagnosticsSessionSnapshot.init(report:)),
            target: resolvedTarget,
            generatedAt: generatedAt,
            redactionSalt: redactionSalt
        )
    }

    static func jsonData(from snapshot: DiagnosticsExportSnapshot) throws -> Data {
        try JSONEncoder.pretty.encode(snapshot)
    }

    static func jsonString(from snapshot: DiagnosticsExportSnapshot) throws -> String {
        let data = try jsonData(from: snapshot)
        return String(decoding: data, as: UTF8.self)
    }
}

extension DiagnosticsStateSnapshot {
    @MainActor
    init(appState: AppState, salt: String) {
        let activeProfileName = appState.activeProfile?.displayName
        self.init(
            profileCount: appState.profiles.count,
            activeProfileIDHash: appState.activeProfile.map { DiagnosticsRedactor.hash($0.id.uuidString, salt: salt) },
            activeProfileNameHash: activeProfileName.nilIfEmpty.map { DiagnosticsRedactor.hash($0, salt: salt) },
            activeProfileCategory: appState.activeProfile?.category,
            currentMode: appState.currentMode,
            permissionState: appState.permissionState,
            debugHUDVisible: appState.debugHUDVisible,
            captureModeDescription: appState.captureModeDescription,
            statusMessage: appState.statusMessage,
            redactionSalt: salt
        )
    }
}

extension DiagnosticsOverlaySnapshot {
    @MainActor
    init(overlayState: OverlayState) {
        enabled = overlayState.enabled
        emergencyActive = overlayState.emergencyActive
        vignetteOpacity = overlayState.vignetteOpacity
        vignetteInnerRadius = overlayState.vignetteInnerRadius
        vignetteOuterRadius = overlayState.vignetteOuterRadius
        vignetteSoftness = overlayState.vignetteSoftness
        centerDotEnabled = overlayState.centerDotEnabled
        centerDotOpacity = overlayState.centerDotOpacity
        centerDotRadius = overlayState.centerDotRadius
        crosshairEnabled = overlayState.crosshairEnabled
        crosshairOpacity = overlayState.crosshairOpacity
        crosshairLength = overlayState.crosshairLength
        crosshairThickness = overlayState.crosshairThickness
        horizonEnabled = overlayState.horizonEnabled
        horizonOpacity = overlayState.horizonOpacity
        horizonY = overlayState.horizonY
        dashboardEnabled = overlayState.dashboardEnabled
        dashboardOpacity = overlayState.dashboardOpacity
        virtualNoseEnabled = overlayState.virtualNoseEnabled
        virtualNoseOpacity = overlayState.virtualNoseOpacity
        peripheralFrameEnabled = overlayState.peripheralFrameEnabled
        peripheralFrameOpacity = overlayState.peripheralFrameOpacity
        peripheralFrameThickness = overlayState.peripheralFrameThickness
    }
}

extension DiagnosticsMotionSnapshot {
    @MainActor
    init(appState: AppState) {
        visual = appState.lastVisualMetrics
        cadence = appState.lastCadenceMetrics
        scoreResult = appState.lastScoreResult
    }
}

enum DiagnosticsRedactor {
    static func hash(_ value: String, salt: String = UUID().uuidString) -> String {
        let payload = Data((salt + ":" + value).utf8)
        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func pathComponentCount(_ path: String) -> Int {
        URL(fileURLWithPath: path).pathComponents.count
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self, !value.isEmpty else {
            return nil
        }
        return value
    }
}
