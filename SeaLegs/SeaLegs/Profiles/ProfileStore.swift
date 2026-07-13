import Foundation
import OSLog

struct StoredProfiles: Codable, Equatable {
    var schemaVersion: Int
    var profiles: [GameProfile]
}

struct StoredSettings: Codable, Equatable {
    var schemaVersion: Int
    var settings: AppSettings
}

struct AppSettings: Codable, Equatable {
    var telemetry: TelemetrySettings
    var privacy: PrivacySettings
    var interface: InterfaceSettings

    static let standard = AppSettings(
        telemetry: .standard,
        privacy: .standard,
        interface: .standard
    )

    enum CodingKeys: String, CodingKey {
        case telemetry
        case privacy
        case interface
    }

    init(telemetry: TelemetrySettings, privacy: PrivacySettings, interface: InterfaceSettings) {
        self.telemetry = telemetry
        self.privacy = privacy
        self.interface = interface
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        telemetry = try container.decodeIfPresent(TelemetrySettings.self, forKey: .telemetry) ?? .standard
        privacy = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacy) ?? .standard
        interface = try container.decodeIfPresent(InterfaceSettings.self, forKey: .interface) ?? .legacy
    }
}

struct TelemetrySettings: Codable, Equatable {
    var sessionLoggingEnabled: Bool
    var sessionSampleIntervalSeconds: TimeInterval
    var sessionLogRetentionDays: Int

    static let standard = TelemetrySettings(
        sessionLoggingEnabled: true,
        sessionSampleIntervalSeconds: 1,
        sessionLogRetentionDays: 14
    )
}

struct PrivacySettings: Codable, Equatable {
    var diagnosticsHashSalt: String
    var inputSignalEnabled: Bool

    static var standard: PrivacySettings {
        PrivacySettings(diagnosticsHashSalt: UUID().uuidString, inputSignalEnabled: false)
    }

    enum CodingKeys: String, CodingKey {
        case diagnosticsHashSalt
        case inputSignalEnabled
    }

    init(diagnosticsHashSalt: String, inputSignalEnabled: Bool) {
        self.diagnosticsHashSalt = diagnosticsHashSalt
        self.inputSignalEnabled = inputSignalEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        diagnosticsHashSalt = try container.decodeIfPresent(String.self, forKey: .diagnosticsHashSalt) ?? UUID().uuidString
        inputSignalEnabled = try container.decodeIfPresent(Bool.self, forKey: .inputSignalEnabled) ?? false
    }
}

final class ProfileStore {
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "ProfileStore")
    private let fileManager: FileManager
    let baseURL: URL
    let profilesURL: URL
    let settingsURL: URL
    let sessionsURL: URL

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        let supportURL = baseURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppConstants.supportDirectoryName, isDirectory: true)
        self.baseURL = supportURL
        self.profilesURL = supportURL.appendingPathComponent("profiles.json")
        self.settingsURL = supportURL.appendingPathComponent("settings.json")
        self.sessionsURL = supportURL.appendingPathComponent("Sessions", isDirectory: true)
    }

    func bootstrapIfNeeded() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: profilesURL.path) {
            try saveProfiles(DefaultProfiles.all)
        }
        if !fileManager.fileExists(atPath: settingsURL.path) {
            try saveSettings(.standard)
        }
    }

    func loadProfiles() -> [GameProfile] {
        do {
            try bootstrapIfNeeded()
            let data = try Data(contentsOf: profilesURL)
            let stored = try JSONDecoder.seaLegs.decode(StoredProfiles.self, from: data)
            guard stored.schemaVersion <= AppConstants.schemaVersion else {
                logger.error("Unsupported profile schema version: \(stored.schemaVersion)")
                return DefaultProfiles.all
            }
            guard !stored.profiles.isEmpty else {
                return DefaultProfiles.all
            }
            let mergedProfiles = mergeMissingDefaultProfiles(into: stored.profiles)
            if mergedProfiles.count != stored.profiles.count {
                try? saveProfiles(mergedProfiles)
            }
            return mergedProfiles
        } catch {
            logger.error("Failed to load profiles: \(error.localizedDescription)")
            return DefaultProfiles.all
        }
    }

    func saveProfiles(_ profiles: [GameProfile]) throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let stored = StoredProfiles(schemaVersion: AppConstants.schemaVersion, profiles: profiles)
        let data = try JSONEncoder.pretty.encode(stored)
        try atomicWrite(data: data, to: profilesURL)
    }

    func loadSettings() -> AppSettings {
        do {
            try bootstrapIfNeeded()
            let data = try Data(contentsOf: settingsURL)
            let stored = try JSONDecoder.seaLegs.decode(StoredSettings.self, from: data)
            guard stored.schemaVersion <= AppConstants.schemaVersion else {
                logger.error("Unsupported settings schema version: \(stored.schemaVersion)")
                return .standard
            }
            return stored.settings
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
            let settings = AppSettings.standard
            try? saveSettings(settings)
            return settings
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let stored = StoredSettings(schemaVersion: AppConstants.schemaVersion, settings: settings)
        try atomicWrite(data: JSONEncoder.pretty.encode(stored), to: settingsURL)
    }

    func upsert(_ profile: GameProfile, into profiles: [GameProfile]) -> [GameProfile] {
        var next = profiles
        if let index = next.firstIndex(where: { $0.id == profile.id }) {
            next[index] = profile
        } else {
            next.append(profile)
        }
        return next
    }

    func delete(_ profile: GameProfile, from profiles: [GameProfile]) -> [GameProfile] {
        profiles.filter { $0.id != profile.id }
    }

    private func mergeMissingDefaultProfiles(into profiles: [GameProfile]) -> [GameProfile] {
        var merged = profiles
        let existingKeys = Set(profiles.compactMap(defaultIdentityKey(for:)))
        for defaultProfile in DefaultProfiles.all {
            guard let key = defaultIdentityKey(for: defaultProfile), !existingKeys.contains(key) else {
                continue
            }
            merged.append(defaultProfile)
        }
        return merged
    }

    private func defaultIdentityKey(for profile: GameProfile) -> String? {
        guard profile.isTemplate else {
            return nil
        }

        let normalizedName = profile.displayName
            .replacingOccurrences(of: "Default - ", with: "")
            .lowercased()
        return "\(profile.category.rawValue):\(normalizedName)"
    }

    func atomicWrite(data: Data, to url: URL) throws {
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        defer {
            if fileManager.fileExists(atPath: tmp.path) {
                try? fileManager.removeItem(at: tmp)
            }
        }
        try data.write(to: tmp, options: [.atomic])
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: tmp, backupItemName: nil, options: [.usingNewMetadataOnly])
            return
        }
        try fileManager.moveItem(at: tmp, to: url)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom(ISO8601DateCodec.encode(_:encoder:))
        return encoder
    }
}

extension JSONDecoder {
    static var seaLegs: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ISO8601DateCodec.decode(_:))
        return decoder
    }
}

private enum ISO8601DateCodec {
    static func encode(_ date: Date, encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(formatter(includeFractionalSeconds: true).string(from: date))
    }

    static func decode(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = formatter(includeFractionalSeconds: true).date(from: value)
            ?? formatter(includeFractionalSeconds: false).date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
    }

    private static func formatter(includeFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includeFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }
}
