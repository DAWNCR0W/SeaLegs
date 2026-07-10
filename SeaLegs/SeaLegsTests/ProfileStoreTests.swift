import XCTest
@testable import SeaLegs

final class ProfileStoreTests: XCTestCase {
    func testDefaultProfilesAreCreated() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        try store.bootstrapIfNeeded()

        XCTAssertFalse(store.loadProfiles().isEmpty)
        XCTAssertTrue(store.loadProfiles().contains { $0.displayName == "Default - Competitive FPS" })
        XCTAssertTrue(store.loadProfiles().contains { $0.displayName == "Default - Strong Comfort" })
    }

    func testSaveLoadRoundTrip() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        let profile = DefaultProfiles.customProfile(displayName: "Example", bundleIdentifier: "com.example.game", executableName: "Example", category: .racing)

        try store.saveProfiles([profile])

        let loadedProfile = try XCTUnwrap(store.loadProfiles().first)
        XCTAssertEqual(loadedProfile.id, profile.id)
        XCTAssertEqual(loadedProfile.displayName, profile.displayName)
        XCTAssertEqual(loadedProfile.bundleIdentifier, profile.bundleIdentifier)
        XCTAssertEqual(loadedProfile.executableName, profile.executableName)
        XCTAssertEqual(loadedProfile.category, profile.category)
        XCTAssertEqual(loadedProfile.overlay, profile.overlay)
        XCTAssertEqual(loadedProfile.adaptive, profile.adaptive)
        XCTAssertEqual(loadedProfile.feedback, profile.feedback)
        XCTAssertEqual(loadedProfile.settingsChecklist, profile.settingsChecklist)
        XCTAssertEqual(loadedProfile.createdAt.timeIntervalSince1970, profile.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loadedProfile.updatedAt.timeIntervalSince1970, profile.updatedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testLegacyProfileMissingNewFieldsLoadsWithDefaults() throws {
        let profile = DefaultProfiles.customProfile(
            displayName: "Legacy",
            bundleIdentifier: "com.example.legacy",
            executableName: "Legacy",
            category: .flightOrSpace
        )
        let stored = StoredProfiles(schemaVersion: AppConstants.schemaVersion, profiles: [profile])
        let data = try JSONEncoder.pretty.encode(stored)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var profiles = try XCTUnwrap(object["profiles"] as? [[String: Any]])
        profiles[0].removeValue(forKey: "settingsChecklist")
        var overlay = try XCTUnwrap(profiles[0]["overlay"] as? [String: Any])
        overlay.removeValue(forKey: "peripheralFrame")
        profiles[0]["overlay"] = overlay
        object["profiles"] = profiles
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder.seaLegs.decode(StoredProfiles.self, from: legacyData)
        let decodedProfile = try XCTUnwrap(decoded.profiles.first)

        XCTAssertFalse(decodedProfile.settingsChecklist.isEmpty)
        XCTAssertFalse(decodedProfile.overlay.peripheralFrame.enabled)
        XCTAssertEqual(decodedProfile.overlay.peripheralFrame.opacity, 0.08)
    }

    func testProfileMatchesExecutablePathHash() {
        let path = "/Applications/Example.app/Contents/MacOS/Example"
        let profile = DefaultProfiles.customProfile(
            displayName: "Example",
            bundleIdentifier: nil,
            executableName: nil,
            executablePath: path,
            category: .general3D
        )

        XCTAssertTrue(profile.matches(bundleIdentifier: nil, executableName: nil, executablePath: path))
        XCTAssertFalse(profile.matches(bundleIdentifier: nil, executableName: nil, executablePath: "/Applications/Other.app/Contents/MacOS/Other"))
    }

    func testBundleIdentifierDoesNotFallBackToMatchingExecutableName() {
        let profile = DefaultProfiles.customProfile(
            displayName: "Example",
            bundleIdentifier: "com.example.game",
            executableName: "SharedExecutable",
            category: .general3D
        )

        XCTAssertFalse(
            profile.matches(
                bundleIdentifier: "com.other.app",
                executableName: "SharedExecutable",
                executablePath: nil
            )
        )
    }

    func testExecutablePathDoesNotFallBackToMatchingExecutableName() {
        let profile = DefaultProfiles.customProfile(
            displayName: "Example",
            bundleIdentifier: nil,
            executableName: "SharedExecutable",
            executablePath: "/Applications/Example.app/Contents/MacOS/SharedExecutable",
            category: .general3D
        )

        XCTAssertFalse(
            profile.matches(
                bundleIdentifier: nil,
                executableName: "SharedExecutable",
                executablePath: "/Applications/Other.app/Contents/MacOS/SharedExecutable"
            )
        )
    }

    func testUnknownSchemaVersionFallsBackToDefaults() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        try FileManager.default.createDirectory(at: store.baseURL, withIntermediateDirectories: true)
        let bad = StoredProfiles(schemaVersion: AppConstants.schemaVersion + 99, profiles: [])
        try JSONEncoder.pretty.encode(bad).write(to: store.profilesURL)

        XCTAssertFalse(store.loadProfiles().isEmpty)
    }

    func testCorruptJSONFallsBackToDefaults() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        try FileManager.default.createDirectory(at: store.baseURL, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.profilesURL)

        XCTAssertFalse(store.loadProfiles().isEmpty)
    }

    func testSettingsUseDedicatedSchema() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        var settings = AppSettings.standard
        settings.telemetry.sessionLoggingEnabled = false
        settings.telemetry.sessionLogRetentionDays = 30
        settings.interface.language = .korean
        settings.interface.overlayDisplayScope = .allDisplays
        settings.privacy.inputSignalEnabled = true

        try store.saveSettings(settings)

        let loaded = store.loadSettings()
        XCTAssertEqual(loaded.telemetry.sessionLoggingEnabled, false)
        XCTAssertEqual(loaded.telemetry.sessionLogRetentionDays, 30)
        XCTAssertEqual(loaded.interface.language, .korean)
        XCTAssertEqual(loaded.interface.overlayDisplayScope, .allDisplays)
        XCTAssertTrue(loaded.privacy.inputSignalEnabled)
        XCTAssertFalse(loaded.privacy.diagnosticsHashSalt.isEmpty)
    }

    func testLegacySettingsMissingInterfaceLoadsWithDefaultLanguage() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        try FileManager.default.createDirectory(at: store.baseURL, withIntermediateDirectories: true)
        let legacyJSON = """
        {
          "schemaVersion": \(AppConstants.schemaVersion),
          "settings": {
            "telemetry": {
              "sessionLoggingEnabled": true,
              "sessionSampleIntervalSeconds": 1,
              "sessionLogRetentionDays": 14
            },
            "privacy": {
              "diagnosticsHashSalt": "legacy-salt"
            }
          }
        }
        """
        try Data(legacyJSON.utf8).write(to: store.settingsURL)

        let loaded = store.loadSettings()

        XCTAssertEqual(loaded.interface.language, .system)
        XCTAssertEqual(loaded.interface.overlayDisplayScope, .activeGameDisplay)
        XCTAssertEqual(loaded.privacy.diagnosticsHashSalt, "legacy-salt")
        XCTAssertFalse(loaded.privacy.inputSignalEnabled)
    }

    func testLegacySettingsWithLanguageLoadsNewPreferencesWithDefaults() throws {
        let store = ProfileStore(baseURL: temporaryDirectory())
        try FileManager.default.createDirectory(at: store.baseURL, withIntermediateDirectories: true)
        let legacyJSON = """
        {
          "schemaVersion": \(AppConstants.schemaVersion),
          "settings": {
            "telemetry": {
              "sessionLoggingEnabled": true,
              "sessionSampleIntervalSeconds": 1,
              "sessionLogRetentionDays": 14
            },
            "privacy": {
              "diagnosticsHashSalt": "legacy-salt"
            },
            "interface": {
              "language": "korean"
            }
          }
        }
        """
        try Data(legacyJSON.utf8).write(to: store.settingsURL)

        let loaded = store.loadSettings()

        XCTAssertEqual(loaded.interface.language, .korean)
        XCTAssertEqual(loaded.interface.overlayDisplayScope, .activeGameDisplay)
        XCTAssertFalse(loaded.privacy.inputSignalEnabled)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
