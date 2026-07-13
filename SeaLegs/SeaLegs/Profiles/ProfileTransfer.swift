import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let seaLegsProfile = UTType(
        exportedAs: "com.dawncrow.sealegs.profile",
        conformingTo: .json
    )
}

struct SeaLegsProfileArchive: Codable, Equatable {
    static let currentFormatVersion = 1
    static let maximumArchiveBytes = 5 * 1_024 * 1_024

    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
    let profiles: [PortableGameProfile]

    init(
        formatVersion: Int = Self.currentFormatVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        profiles: [PortableGameProfile]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = Date(timeIntervalSince1970: floor(exportedAt.timeIntervalSince1970))
        self.appVersion = appVersion
        self.profiles = profiles
    }

    static func make(profiles: [GameProfile], appVersion: String) throws -> SeaLegsProfileArchive {
        let archive = SeaLegsProfileArchive(
            appVersion: appVersion,
            profiles: profiles.map(PortableGameProfile.init(profile:))
        )
        try ProfileTransferValidator.validate(archive)
        return archive
    }

    static func decode(_ data: Data) throws -> SeaLegsProfileArchive {
        guard data.count <= maximumArchiveBytes else {
            throw ProfileTransferError.archiveTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: SeaLegsProfileArchive
        do {
            archive = try decoder.decode(SeaLegsProfileArchive.self, from: data)
        } catch {
            throw ProfileTransferError.malformedDocument
        }
        try ProfileTransferValidator.validate(archive)
        return archive
    }

    func encoded() throws -> Data {
        try ProfileTransferValidator.validate(self)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct PortableGameProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var bundleIdentifier: String?
    var executableName: String?
    var category: GameCategory
    var overlay: OverlayConfig
    var adaptive: AdaptiveConfig
    var feedback: FeedbackConfig
    var settingsChecklist: [GameSettingRecommendation]

    init(profile: GameProfile) {
        id = profile.id
        displayName = profile.displayName
        bundleIdentifier = normalizedTransferIdentifier(profile.bundleIdentifier)
        executableName = normalizedTransferIdentifier(profile.executableName)
        category = profile.category
        overlay = profile.overlay
        adaptive = profile.adaptive
        feedback = profile.feedback
        settingsChecklist = profile.settingsChecklist
    }

    func gameProfile(id targetID: UUID, createdAt: Date, updatedAt: Date) -> GameProfile {
        GameProfile(
            id: targetID,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bundleIdentifier: normalizedTransferIdentifier(bundleIdentifier),
            executableName: normalizedTransferIdentifier(executableName),
            category: category,
            overlay: overlay,
            adaptive: adaptive,
            feedback: feedback,
            settingsChecklist: settingsChecklist,
            isBuiltInTemplate: false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum ProfileTransferError: LocalizedError, Equatable {
    case malformedDocument
    case archiveTooLarge
    case unsupportedFormatVersion(Int)
    case emptyArchive
    case tooManyProfiles
    case duplicateProfileID
    case duplicateMatchHint
    case invalidProfile(String)

    var errorDescription: String? {
        switch self {
        case .malformedDocument:
            "The selected file is not a valid SeaLegs profile archive."
        case .archiveTooLarge:
            "The selected profile archive is larger than 5 MB."
        case let .unsupportedFormatVersion(version):
            "Profile archive format version \(version) is not supported."
        case .emptyArchive:
            "The profile archive does not contain any profiles."
        case .tooManyProfiles:
            "The profile archive contains too many profiles."
        case .duplicateProfileID:
            "The profile archive contains duplicate profile identifiers."
        case .duplicateMatchHint:
            "The profile archive contains duplicate application matching hints."
        case let .invalidProfile(reason):
            "The profile archive contains invalid settings: \(reason)"
        }
    }
}

enum ProfileImportConflictKind: String, Equatable {
    case identifier
    case bundleIdentifier
    case executableName
}

struct ProfileImportConflict: Identifiable, Equatable {
    let incomingID: UUID
    let existingID: UUID
    let existingName: String
    let kind: ProfileImportConflictKind
    let existingIsBuiltInTemplate: Bool

    var id: String { "\(incomingID.uuidString):\(existingID.uuidString):\(kind.rawValue)" }
}

struct ProfileImportPreview: Equatable {
    let archive: SeaLegsProfileArchive
    let conflicts: [ProfileImportConflict]
    let warnings: [String]

    var canReplaceAll: Bool {
        !conflicts.isEmpty && conflicts.allSatisfy { !$0.existingIsBuiltInTemplate }
    }
}

enum ProfileImportStrategy: Equatable {
    case replace
    case keepBoth
    case cancel
}

enum ProfileImportResolver {
    static func preview(archive: SeaLegsProfileArchive, existing: [GameProfile]) -> ProfileImportPreview {
        var conflicts: [ProfileImportConflict] = []
        var warnings: [String] = []

        for incoming in archive.profiles {
            if let conflict = conflict(for: incoming, existing: existing) {
                conflicts.append(conflict)
                let templateWarning = "Built-in templates are protected and will be kept as separate profiles."
                if conflict.existingIsBuiltInTemplate, !warnings.contains(templateWarning) {
                    warnings.append(templateWarning)
                }
                let keepBothWarning = "Keep Both imports conflicting profiles without an app match to avoid ambiguous automatic activation."
                if !conflict.existingIsBuiltInTemplate, !warnings.contains(keepBothWarning) {
                    warnings.append(keepBothWarning)
                }
            }
            let automaticActivationWarning = "A linked imported profile can activate automatically when its matching app becomes active."
            if normalizedTransferIdentifier(incoming.bundleIdentifier) != nil
                || normalizedTransferIdentifier(incoming.executableName) != nil,
               !warnings.contains(automaticActivationWarning) {
                warnings.append(automaticActivationWarning)
            }
            if normalizedTransferIdentifier(incoming.bundleIdentifier) == nil,
               normalizedTransferIdentifier(incoming.executableName) == nil {
                warnings.append("This profile has no app match and must be reconnected before automatic matching can work.")
            }
        }

        return ProfileImportPreview(archive: archive, conflicts: conflicts, warnings: warnings)
    }

    static func resolve(
        preview: ProfileImportPreview,
        existing: [GameProfile],
        strategy: ProfileImportStrategy,
        now: Date = Date()
    ) -> [GameProfile] {
        guard strategy != .cancel else {
            return existing
        }

        var resolved = existing
        for incoming in preview.archive.profiles {
            let match = conflict(for: incoming, existing: resolved)
            if let match, strategy == .replace,
               let index = resolved.firstIndex(where: { $0.id == match.existingID }),
               !resolved[index].isTemplate {
                let current = resolved[index]
                resolved[index] = incoming.gameProfile(
                    id: current.id,
                    createdAt: current.createdAt,
                    updatedAt: now
                )
                continue
            }

            let targetID: UUID
            let targetName: String
            if match != nil || resolved.contains(where: { $0.id == incoming.id }) {
                targetID = UUID()
                targetName = uniqueImportedName(incoming.displayName, existing: resolved)
            } else {
                targetID = incoming.id
                targetName = incoming.displayName
            }
            var profile = incoming.gameProfile(id: targetID, createdAt: now, updatedAt: now)
            profile.displayName = targetName
            if match != nil, strategy == .keepBoth {
                profile.bundleIdentifier = nil
                profile.executableName = nil
                profile.executablePathHash = nil
            }
            resolved.append(profile)
        }
        return resolved
    }

    private static func conflict(for incoming: PortableGameProfile, existing: [GameProfile]) -> ProfileImportConflict? {
        if let match = existing.first(where: { $0.id == incoming.id }) {
            return ProfileImportConflict(
                incomingID: incoming.id,
                existingID: match.id,
                existingName: match.displayName,
                kind: .identifier,
                existingIsBuiltInTemplate: match.isTemplate
            )
        }
        if let bundleIdentifier = normalizedTransferIdentifier(incoming.bundleIdentifier),
           let match = existing.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return ProfileImportConflict(
                incomingID: incoming.id,
                existingID: match.id,
                existingName: match.displayName,
                kind: .bundleIdentifier,
                existingIsBuiltInTemplate: match.isTemplate
            )
        }
        let incomingBundleIdentifier = normalizedTransferIdentifier(incoming.bundleIdentifier)
        let incomingExecutableName = normalizedTransferIdentifier(incoming.executableName)
        if incomingBundleIdentifier == nil,
           let executableName = incomingExecutableName {
            let match = existing.first {
                $0.bundleIdentifier == nil && $0.executableName == executableName
            }
            guard let match else {
                return nil
            }
            return ProfileImportConflict(
                incomingID: incoming.id,
                existingID: match.id,
                existingName: match.displayName,
                kind: .executableName,
                existingIsBuiltInTemplate: match.isTemplate
            )
        }
        return nil
    }

    private static func uniqueImportedName(_ baseName: String, existing: [GameProfile]) -> String {
        let names = Set(existing.map { $0.displayName.lowercased() })
        let first = "\(baseName) (Imported)"
        guard names.contains(first.lowercased()) else {
            return first
        }
        var suffix = 2
        while names.contains("\(first) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(first) \(suffix)"
    }
}

private func normalizedTransferIdentifier(_ value: String?) -> String? {
    guard let value else {
        return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

enum ProfileTransferValidator {
    static func validate(_ archive: SeaLegsProfileArchive) throws {
        guard archive.formatVersion == SeaLegsProfileArchive.currentFormatVersion else {
            throw ProfileTransferError.unsupportedFormatVersion(archive.formatVersion)
        }
        guard !archive.profiles.isEmpty else {
            throw ProfileTransferError.emptyArchive
        }
        guard archive.profiles.count <= 100 else {
            throw ProfileTransferError.tooManyProfiles
        }
        guard Set(archive.profiles.map(\.id)).count == archive.profiles.count else {
            throw ProfileTransferError.duplicateProfileID
        }
        let matchHints = archive.profiles.compactMap { profile -> String? in
            if let bundleIdentifier = normalizedTransferIdentifier(profile.bundleIdentifier) {
                return "bundle:\(bundleIdentifier)"
            }
            if let executableName = normalizedTransferIdentifier(profile.executableName) {
                return "executable:\(executableName)"
            }
            return nil
        }
        guard Set(matchHints).count == matchHints.count else {
            throw ProfileTransferError.duplicateMatchHint
        }
        for profile in archive.profiles {
            try validate(profile)
        }
    }

    private static func validate(_ profile: PortableGameProfile) throws {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120 else {
            throw ProfileTransferError.invalidProfile("profile name")
        }
        try validateOptionalIdentifier(profile.bundleIdentifier, label: "bundle identifier")
        try validateOptionalIdentifier(profile.executableName, label: "executable name")

        let overlay = profile.overlay
        try validateFinite([
            overlay.baseOpacity, overlay.maxOpacity, overlay.emergencyOpacity,
            overlay.restInnerRadius, overlay.motionInnerRadius, overlay.emergencyInnerRadius,
            overlay.outerRadius, overlay.rampInSeconds, overlay.rampOutSeconds,
            overlay.centerDot.opacity, overlay.centerDot.size,
            overlay.centerDot.positionX, overlay.centerDot.positionY,
            overlay.crosshair.opacity, overlay.crosshair.size,
            overlay.crosshair.positionX, overlay.crosshair.positionY,
            overlay.horizon.opacity, overlay.horizon.y,
            overlay.dashboard.opacity, overlay.dashboard.size,
            overlay.virtualNose.opacity, overlay.virtualNose.size,
            overlay.peripheralFrame.opacity, overlay.peripheralFrame.size,
        ])
        guard (0...1).contains(overlay.baseOpacity),
              (0...1).contains(overlay.maxOpacity),
              (0...1).contains(overlay.emergencyOpacity),
              overlay.baseOpacity <= overlay.maxOpacity,
              overlay.maxOpacity <= overlay.emergencyOpacity,
              (0...2).contains(overlay.restInnerRadius),
              (0...2).contains(overlay.motionInnerRadius),
              (0...2).contains(overlay.emergencyInnerRadius),
              (0...2).contains(overlay.outerRadius),
              (0...60).contains(overlay.rampInSeconds),
              (0...60).contains(overlay.rampOutSeconds) else {
            throw ProfileTransferError.invalidProfile("overlay range")
        }
        try validateGuide(overlay.centerDot)
        try validateGuide(overlay.crosshair)
        try validateGuide(overlay.dashboard)
        try validateGuide(overlay.virtualNose)
        try validateGuide(overlay.peripheralFrame)
        guard (0...1).contains(overlay.horizon.opacity), (0...1).contains(overlay.horizon.y) else {
            throw ProfileTransferError.invalidProfile("horizon range")
        }

        let adaptive = profile.adaptive
        guard (1...60).contains(adaptive.analysisFramesPerSecond),
              (40...4_096).contains(adaptive.captureWidth),
              (30...4_096).contains(adaptive.captureHeight),
              (40...2_048).contains(adaptive.analysisWidth),
              (30...2_048).contains(adaptive.analysisHeight),
              adaptive.analysisWidth <= adaptive.captureWidth,
              adaptive.analysisHeight <= adaptive.captureHeight,
              (1...240).contains(profile.feedback.promptIntervalMinutes) else {
            throw ProfileTransferError.invalidProfile("adaptive or feedback range")
        }
        guard profile.settingsChecklist.count <= 100 else {
            throw ProfileTransferError.invalidProfile("settings checklist size")
        }
    }

    private static func validateGuide(_ guide: GuideConfig) throws {
        guard (0...1).contains(guide.opacity),
              (0...500).contains(guide.size),
              (0...1).contains(guide.positionX),
              (0...1).contains(guide.positionY) else {
            throw ProfileTransferError.invalidProfile("visual guide range")
        }
    }

    private static func validateFinite(_ values: [Float]) throws {
        guard values.allSatisfy(\.isFinite) else {
            throw ProfileTransferError.invalidProfile("non-finite number")
        }
    }

    private static func validateOptionalIdentifier(_ value: String?, label: String) throws {
        guard let value else {
            return
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 512 else {
            throw ProfileTransferError.invalidProfile(label)
        }
    }
}
