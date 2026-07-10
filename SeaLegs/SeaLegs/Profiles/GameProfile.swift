import Foundation

enum GameCategory: String, Codable, CaseIterable, Identifiable {
    case desktopFPS
    case competitiveFPS
    case thirdPersonAction
    case racing
    case flightOrSpace
    case walkingSimulator
    case general3D

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desktopFPS: "Desktop FPS"
        case .competitiveFPS: "Competitive FPS"
        case .thirdPersonAction: "Third-person Action"
        case .racing: "Racing"
        case .flightOrSpace: "Flight / Space"
        case .walkingSimulator: "Walking Simulator"
        case .general3D: "General 3D"
        }
    }
}

struct GameProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var bundleIdentifier: String?
    var executableName: String?
    var executablePathHash: String?
    var category: GameCategory
    var overlay: OverlayConfig
    var adaptive: AdaptiveConfig
    var feedback: FeedbackConfig
    var settingsChecklist: [GameSettingRecommendation]
    var createdAt: Date
    var updatedAt: Date

    var isTemplate: Bool {
        bundleIdentifier == nil && executableName == nil && executablePathHash == nil
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        bundleIdentifier: String? = nil,
        executableName: String? = nil,
        executablePath: String? = nil,
        category: GameCategory,
        overlay: OverlayConfig,
        adaptive: AdaptiveConfig = .standard,
        feedback: FeedbackConfig = .standard,
        settingsChecklist: [GameSettingRecommendation]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.executablePathHash = executablePath.map(Self.stableHash(_:))
        self.category = category
        self.overlay = overlay
        self.adaptive = adaptive
        self.feedback = feedback
        self.settingsChecklist = settingsChecklist ?? DefaultGameSettingRecommendations.recommendations(for: category)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case bundleIdentifier
        case executableName
        case executablePathHash
        case category
        case overlay
        case adaptive
        case feedback
        case settingsChecklist
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        executableName = try container.decodeIfPresent(String.self, forKey: .executableName)
        executablePathHash = try container.decodeIfPresent(String.self, forKey: .executablePathHash)
        category = try container.decode(GameCategory.self, forKey: .category)
        overlay = try container.decode(OverlayConfig.self, forKey: .overlay)
        adaptive = try container.decode(AdaptiveConfig.self, forKey: .adaptive)
        feedback = try container.decode(FeedbackConfig.self, forKey: .feedback)
        settingsChecklist = try container.decodeIfPresent([GameSettingRecommendation].self, forKey: .settingsChecklist)
            ?? DefaultGameSettingRecommendations.recommendations(for: category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func matches(bundleIdentifier: String?, executableName: String?, executablePath: String? = nil) -> Bool {
        if let expectedBundle = self.bundleIdentifier {
            return expectedBundle == bundleIdentifier
        }
        if let expectedPathHash = executablePathHash {
            guard let executablePath else {
                return false
            }
            return expectedPathHash == Self.stableHash(executablePath)
        }
        if let expectedExecutable = self.executableName {
            return expectedExecutable == executableName
        }
        return false
    }

    static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
