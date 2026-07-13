import Foundation
import XCTest

@testable import SeaLegs

final class ProfileTransferTests: XCTestCase {
    func testArchiveRoundTripExcludesExecutablePathHashAndPrivateRuntimeData() throws {
        var profile = DefaultProfiles.customProfile(
            displayName: "Windowed Game",
            bundleIdentifier: "com.example.game",
            executableName: "ExampleGame",
            executablePath: "/Users/example/Private/Game",
            category: .desktopFPS
        )
        profile.overlay.centerDot.positionX = 0.27
        let archive = try SeaLegsProfileArchive.make(profiles: [profile], appVersion: "0.2.0")

        let data = try archive.encoded()
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try SeaLegsProfileArchive.decode(data)

        XCTAssertEqual(decoded, archive)
        XCTAssertEqual(decoded.profiles.first?.overlay.centerDot.positionX, 0.27)
        XCTAssertFalse(json.contains("executablePathHash"))
        XCTAssertFalse(json.contains("/Users/example/Private/Game"))
        XCTAssertFalse(json.contains("diagnosticsHashSalt"))
        XCTAssertFalse(json.contains("Sessions"))
    }

    func testDecodeRejectsMalformedFutureEmptyDuplicateAndNonFiniteArchives() throws {
        XCTAssertThrowsError(try SeaLegsProfileArchive.decode(Data("not-json".utf8))) {
            XCTAssertEqual($0 as? ProfileTransferError, .malformedDocument)
        }
        XCTAssertThrowsError(
            try SeaLegsProfileArchive.decode(
                Data(repeating: 0, count: SeaLegsProfileArchive.maximumArchiveBytes + 1)
            )
        ) {
            XCTAssertEqual($0 as? ProfileTransferError, .archiveTooLarge)
        }

        let valid = PortableGameProfile(profile: DefaultProfiles.profile(for: .desktopFPS))
        let futureData = try rawEncodedArchive(formatVersion: 2, profiles: [valid])
        XCTAssertThrowsError(try SeaLegsProfileArchive.decode(futureData)) {
            XCTAssertEqual($0 as? ProfileTransferError, .unsupportedFormatVersion(2))
        }

        XCTAssertThrowsError(
            try SeaLegsProfileArchive(formatVersion: 1, exportedAt: Date(), appVersion: "0.2.0", profiles: []).encoded()
        ) {
            XCTAssertEqual($0 as? ProfileTransferError, .emptyArchive)
        }

        XCTAssertThrowsError(
            try SeaLegsProfileArchive(
                formatVersion: 1,
                exportedAt: Date(),
                appVersion: "0.2.0",
                profiles: [valid, valid]
            ).encoded()
        ) {
            XCTAssertEqual($0 as? ProfileTransferError, .duplicateProfileID)
        }

        let duplicateBinding = PortableGameProfile(
            profile: DefaultProfiles.customProfile(
                displayName: "Duplicate Binding",
                bundleIdentifier: "com.example.duplicate",
                executableName: "Duplicate",
                category: .desktopFPS
            )
        )
        let firstBinding = PortableGameProfile(
            profile: DefaultProfiles.customProfile(
                displayName: "First Binding",
                bundleIdentifier: "com.example.duplicate",
                executableName: "First",
                category: .desktopFPS
            )
        )
        XCTAssertThrowsError(
            try SeaLegsProfileArchive(
                formatVersion: 1,
                exportedAt: Date(),
                appVersion: "0.2.0",
                profiles: [firstBinding, duplicateBinding]
            ).encoded()
        ) {
            XCTAssertEqual($0 as? ProfileTransferError, .duplicateMatchHint)
        }

        var invalid = valid
        invalid.overlay.centerDot.positionX = .nan
        XCTAssertThrowsError(
            try SeaLegsProfileArchive(
                formatVersion: 1,
                exportedAt: Date(),
                appVersion: "0.2.0",
                profiles: [invalid]
            ).encoded()
        )
    }

    func testImportPreviewAndReplacePreserveExistingIdentityAndCreationTime() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        var existing = DefaultProfiles.customProfile(
            displayName: "Old",
            bundleIdentifier: "com.example.game",
            executableName: "OldExecutable",
            category: .desktopFPS
        )
        existing.createdAt = createdAt
        var incomingProfile = existing
        incomingProfile.id = UUID()
        incomingProfile.displayName = "Updated"
        incomingProfile.executableName = "NewExecutable"
        let archive = try SeaLegsProfileArchive.make(profiles: [incomingProfile], appVersion: "0.2.0")
        let preview = ProfileImportResolver.preview(archive: archive, existing: [existing])
        let now = Date(timeIntervalSince1970: 200)

        let resolved = ProfileImportResolver.resolve(
            preview: preview,
            existing: [existing],
            strategy: .replace,
            now: now
        )

        XCTAssertEqual(preview.conflicts.map(\.kind), [.bundleIdentifier])
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].id, existing.id)
        XCTAssertEqual(resolved[0].displayName, "Updated")
        XCTAssertEqual(resolved[0].createdAt, createdAt)
        XCTAssertEqual(resolved[0].updatedAt, now)
        XCTAssertFalse(resolved[0].isTemplate)
    }

    func testKeepBothCreatesUniqueIdentityAndCancelLeavesProfilesUnchanged() throws {
        let existing = DefaultProfiles.customProfile(
            displayName: "Game",
            bundleIdentifier: "com.example.game",
            executableName: "Game",
            category: .racing
        )
        let archive = try SeaLegsProfileArchive.make(profiles: [existing], appVersion: "0.2.0")
        let preview = ProfileImportResolver.preview(archive: archive, existing: [existing])

        let kept = ProfileImportResolver.resolve(preview: preview, existing: [existing], strategy: .keepBoth)
        let cancelled = ProfileImportResolver.resolve(preview: preview, existing: [existing], strategy: .cancel)

        XCTAssertEqual(kept.count, 2)
        XCTAssertNotEqual(kept[1].id, existing.id)
        XCTAssertEqual(kept[1].displayName, "Game (Imported)")
        XCTAssertNil(kept[1].bundleIdentifier)
        XCTAssertNil(kept[1].executableName)
        XCTAssertTrue(preview.warnings.contains {
            $0.contains("activate automatically")
        })
        XCTAssertEqual(cancelled, [existing])
    }

    func testUnlinkedImportIsEditableCustomProfileAndWarnsForRelink() throws {
        let template = DefaultProfiles.profile(for: .walkingSimulator)
        let archive = try SeaLegsProfileArchive.make(profiles: [template], appVersion: "0.2.0")
        let preview = ProfileImportResolver.preview(archive: archive, existing: [])

        let resolved = ProfileImportResolver.resolve(preview: preview, existing: [], strategy: .keepBoth)

        XCTAssertEqual(preview.warnings.count, 1)
        XCTAssertEqual(resolved.count, 1)
        XCTAssertFalse(resolved[0].isTemplate)
        XCTAssertNil(resolved[0].bundleIdentifier)
        XCTAssertNil(resolved[0].executableName)
    }

    func testReplaceNeverOverwritesBuiltInTemplate() throws {
        let template = DefaultProfiles.profile(for: .desktopFPS)
        let archive = try SeaLegsProfileArchive.make(profiles: [template], appVersion: "0.2.0")
        let preview = ProfileImportResolver.preview(archive: archive, existing: [template])

        let resolved = ProfileImportResolver.resolve(
            preview: preview,
            existing: [template],
            strategy: .replace
        )

        XCTAssertFalse(preview.canReplaceAll)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertTrue(resolved[0].isTemplate)
        XCTAssertFalse(resolved[1].isTemplate)
        XCTAssertNotEqual(resolved[0].id, resolved[1].id)
    }

    private func rawEncodedArchive(formatVersion: Int, profiles: [PortableGameProfile]) throws -> Data {
        let archive = SeaLegsProfileArchive(
            formatVersion: formatVersion,
            exportedAt: Date(),
            appVersion: "0.2.0",
            profiles: profiles
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }
}

@MainActor
final class ProfileImportCoordinatorTests: XCTestCase {
    func testImportingArchiveURLPreparesPreviewForFinderOpenFlow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileImportURLTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let coordinator = AppCoordinator(
            profileStore: ProfileStore(baseURL: directory.appendingPathComponent("Data")),
            runtimeServicesEnabled: false
        )
        coordinator.start()
        let archive = try SeaLegsProfileArchive.make(
            profiles: [DefaultProfiles.profile(for: .general3D)],
            appVersion: "0.2.0"
        )
        let archiveURL = directory.appendingPathComponent("Finder.sealegsprofile")
        try archive.encoded().write(to: archiveURL, options: .atomic)

        coordinator.importProfiles(from: archiveURL)

        XCTAssertEqual(coordinator.state.pendingProfileImport?.archive, archive)
    }

    func testReplacingActiveProfileSynchronizesRuntimeModeWhileOverlayIsHidden() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileImportCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ProfileStore(baseURL: directory)
        var existing = DefaultProfiles.customProfile(
            displayName: "Imported Game",
            bundleIdentifier: "com.example.imported-game",
            executableName: "ImportedGame",
            category: .desktopFPS
        )
        existing.overlay.mode = .low
        try store.saveProfiles([existing])

        let coordinator = AppCoordinator(profileStore: store, runtimeServicesEnabled: false)
        coordinator.start()
        let loaded = try XCTUnwrap(coordinator.state.profiles.first(where: { $0.id == existing.id }))
        coordinator.state.activeProfile = loaded
        coordinator.state.selectedProfileID = loaded.id
        coordinator.state.currentMode = .low

        var incoming = loaded
        incoming.overlay.mode = .high
        incoming.overlay.centerDot.positionX = 0.23
        let archive = try SeaLegsProfileArchive.make(profiles: [incoming], appVersion: "0.2.0")
        coordinator.state.pendingProfileImport = ProfileImportResolver.preview(
            archive: archive,
            existing: coordinator.state.profiles
        )

        coordinator.resolvePendingProfileImport(.replace)

        XCTAssertEqual(coordinator.state.activeProfile?.overlay.centerDot.positionX, 0.23)
        XCTAssertEqual(coordinator.state.currentMode, .high)
        XCTAssertNil(coordinator.state.pendingProfileImport)
    }
}
