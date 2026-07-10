import Foundation

enum RecommendationSeverity: String, Codable, CaseIterable, Identifiable {
    case critical
    case recommended
    case optional

    var id: String { rawValue }

    var label: String {
        switch self {
        case .critical: "Critical"
        case .recommended: "Recommended"
        case .optional: "Optional"
        }
    }
}

enum RecommendationStatus: String, Codable, CaseIterable, Identifiable {
    case notChecked
    case appliedByUser
    case ignoredByUser
    case notAvailableInGame

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notChecked: "Not Checked"
        case .appliedByUser: "Applied"
        case .ignoredByUser: "Ignored"
        case .notAvailableInGame: "Not Available"
        }
    }
}

struct GameSettingRecommendation: Codable, Identifiable, Equatable {
    var id: UUID
    var key: String
    var displayName: String
    var recommendedValue: String
    var severity: RecommendationSeverity
    var explanation: String
    var userStatus: RecommendationStatus

    init(
        id: UUID = UUID(),
        key: String,
        displayName: String,
        recommendedValue: String,
        severity: RecommendationSeverity,
        explanation: String,
        userStatus: RecommendationStatus = .notChecked
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.recommendedValue = recommendedValue
        self.severity = severity
        self.explanation = explanation
        self.userStatus = userStatus
    }
}

enum DefaultGameSettingRecommendations {
    static func recommendations(for category: GameCategory) -> [GameSettingRecommendation] {
        switch category {
        case .desktopFPS:
            base(
                includeWeaponSway: true,
                includeMouseAcceleration: true,
                includeAutoCamera: false,
                includeFOV: true
            )
        case .thirdPersonAction:
            base(
                includeWeaponSway: false,
                includeMouseAcceleration: false,
                includeAutoCamera: true,
                includeFOV: true
            )
        case .racing:
            [
                motionBlur(),
                cameraShake(),
                chromaticAberration(),
                filmGrain(),
                depthOfField(),
                fieldOfView(),
                GameSettingRecommendation(
                    key: "cockpit-view",
                    displayName: "Cockpit or Dashboard View",
                    recommendedValue: "Prefer stable cockpit/dashboard view when available",
                    severity: .optional,
                    explanation: "A fixed vehicle reference can make rapid lateral motion easier to tolerate."
                )
            ]
        case .flightOrSpace:
            [
                motionBlur(),
                cameraShake(),
                chromaticAberration(),
                filmGrain(),
                depthOfField(),
                fieldOfView(),
                GameSettingRecommendation(
                    key: "horizon-reference",
                    displayName: "Horizon / Cockpit Reference",
                    recommendedValue: "On",
                    severity: .recommended,
                    explanation: "A fixed horizon or cockpit frame gives your eyes a stable reference."
                )
            ]
        case .walkingSimulator:
            base(
                includeWeaponSway: false,
                includeMouseAcceleration: true,
                includeAutoCamera: false,
                includeFOV: true
            )
        case .competitiveFPS:
            [
                motionBlur(severity: .critical),
                cameraShake(severity: .critical),
                headBob(severity: .critical),
                weaponSway(),
                sprintFOV(),
                mouseAcceleration()
            ]
        case .general3D:
            base(
                includeWeaponSway: true,
                includeMouseAcceleration: true,
                includeAutoCamera: true,
                includeFOV: true
            )
        }
    }

    private static func base(
        includeWeaponSway: Bool,
        includeMouseAcceleration: Bool,
        includeAutoCamera: Bool,
        includeFOV: Bool
    ) -> [GameSettingRecommendation] {
        var output = [
            motionBlur(),
            cameraShake(),
            headBob(),
            chromaticAberration(),
            filmGrain(),
            depthOfField(),
            sprintFOV()
        ]
        if includeWeaponSway {
            output.append(weaponSway())
        }
        if includeMouseAcceleration {
            output.append(mouseAcceleration())
        }
        if includeAutoCamera {
            output.append(autoCamera())
        }
        if includeFOV {
            output.append(fieldOfView())
        }
        return output
    }

    private static func motionBlur(severity: RecommendationSeverity = .critical) -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "motion-blur",
            displayName: "Motion Blur",
            recommendedValue: "Off",
            severity: severity,
            explanation: "Reduces visual smear during camera movement and sprinting."
        )
    }

    private static func cameraShake(severity: RecommendationSeverity = .critical) -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "camera-shake",
            displayName: "Camera Shake",
            recommendedValue: "Off or Low",
            severity: severity,
            explanation: "Keeps the whole image from shaking during impacts, sprinting, and scripted events."
        )
    }

    private static func headBob(severity: RecommendationSeverity = .critical) -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "head-bob",
            displayName: "Head Bob / View Bob",
            recommendedValue: "Off",
            severity: severity,
            explanation: "Reduces repeated vertical camera motion while walking or running."
        )
    }

    private static func weaponSway() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "weapon-sway",
            displayName: "Weapon Sway",
            recommendedValue: "Low or Off",
            severity: .recommended,
            explanation: "Keeps the center view steadier during movement."
        )
    }

    private static func chromaticAberration() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "chromatic-aberration",
            displayName: "Chromatic Aberration",
            recommendedValue: "Off",
            severity: .recommended,
            explanation: "Removes color fringing near the edge of the image."
        )
    }

    private static func filmGrain() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "film-grain",
            displayName: "Film Grain",
            recommendedValue: "Off",
            severity: .optional,
            explanation: "Removes unnecessary visual noise."
        )
    }

    private static func depthOfField() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "depth-of-field",
            displayName: "Depth of Field",
            recommendedValue: "Off or Low",
            severity: .optional,
            explanation: "Reduces sudden focus shifts and blur changes."
        )
    }

    private static func sprintFOV() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "sprint-fov",
            displayName: "Sprint FOV Effect",
            recommendedValue: "Off or Low",
            severity: .recommended,
            explanation: "Avoids abrupt field-of-view changes while sprinting."
        )
    }

    private static func mouseAcceleration() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "mouse-acceleration",
            displayName: "Mouse Acceleration",
            recommendedValue: "Off",
            severity: .recommended,
            explanation: "Makes camera movement more predictable."
        )
    }

    private static func autoCamera() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "auto-camera-recenter",
            displayName: "Auto Camera Recenter",
            recommendedValue: "Off or Low",
            severity: .recommended,
            explanation: "Reduces camera motion that was not directly initiated by the player."
        )
    }

    private static func fieldOfView() -> GameSettingRecommendation {
        GameSettingRecommendation(
            key: "field-of-view",
            displayName: "Field of View",
            recommendedValue: "Tune after calibration",
            severity: .optional,
            explanation: "Very low and very high FOV values can both feel uncomfortable depending on the game."
        )
    }
}
