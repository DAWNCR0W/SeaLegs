import XCTest
@testable import SeaLegs

final class DiagnosticsExporterTests: XCTestCase {
    func testExportRedactsWindowTitleAndExecutablePath() throws {
        let rawPath = "/Users/example/Games/Private Game.app/Contents/MacOS/GameBinary"
        let rawTitle = "Private Match - Secret Level"
        let snapshot = DiagnosticsExporter.makeSnapshot(
            state: state(statusMessage: "Capturing a private window"),
            overlay: overlay(),
            target: DiagnosticsTargetInput(
                processIdentifier: 12_345,
                bundleIdentifier: "com.example.private-game",
                executablePath: rawPath,
                windowTitle: rawTitle,
                captureModeDescription: "window filter"
            ),
            generatedAt: Date(timeIntervalSince1970: 1_234)
        )

        let json = try DiagnosticsExporter.jsonString(from: snapshot)

        XCTAssertFalse(json.contains(rawPath))
        XCTAssertFalse(json.contains(rawTitle))
        XCTAssertFalse(json.contains("Capturing a private window"))
        XCTAssertTrue(json.contains("\"executablePathHash\""))
        XCTAssertTrue(json.contains("\"windowTitleHash\""))
        XCTAssertTrue(json.contains("\"statusMessageHash\""))
        XCTAssertTrue(json.contains("\"executableNameHash\""))
        XCTAssertFalse(json.contains("com.example.private-game"))
        XCTAssertFalse(json.contains("\"executableName\" : \"GameBinary\""))
    }

    func testTargetHashesUseProvidedSaltAndDoNotExposeRawValues() throws {
        let target = DiagnosticsTargetInput(
            processIdentifier: 7,
            bundleIdentifier: "com.example.game",
            executablePath: "/Applications/Game.app/Contents/MacOS/Game",
            windowTitle: "Lobby Code 1234",
            captureModeDescription: "application filter"
        )

        let first = DiagnosticsExporter.makeSnapshot(
            state: state(),
            overlay: overlay(),
            target: target,
            generatedAt: Date(timeIntervalSince1970: 10),
            redactionSalt: "salt-a"
        )
        let second = DiagnosticsExporter.makeSnapshot(
            state: state(),
            overlay: overlay(),
            target: target,
            generatedAt: Date(timeIntervalSince1970: 20),
            redactionSalt: "salt-a"
        )
        let third = DiagnosticsExporter.makeSnapshot(
            state: state(),
            overlay: overlay(),
            target: target,
            generatedAt: Date(timeIntervalSince1970: 30),
            redactionSalt: "salt-b"
        )

        XCTAssertEqual(first.target?.executablePathHash, second.target?.executablePathHash)
        XCTAssertEqual(first.target?.windowTitleHash, second.target?.windowTitleHash)
        XCTAssertNotEqual(first.target?.executablePathHash, third.target?.executablePathHash)
        XCTAssertNotEqual(first.target?.executablePathHash, first.target?.windowTitleHash)
        XCTAssertEqual(first.target?.windowTitleCharacterCount, Optional("Lobby Code 1234".count))
        XCTAssertEqual(first.target?.bundleIdentifierCharacterCount, Optional("com.example.game".count))
    }

    func testExportDoesNotContainImageOrScreenshotFields() throws {
        let snapshot = DiagnosticsExporter.makeSnapshot(
            state: state(),
            overlay: overlay(),
            target: DiagnosticsTargetInput(windowTitle: "Sensitive Window"),
            generatedAt: Date(timeIntervalSince1970: 42)
        )
        let data = try DiagnosticsExporter.jsonData(from: snapshot)
        let object = try JSONSerialization.jsonObject(with: data)
        let keys = allKeys(in: object)

        XCTAssertFalse(keys.contains { $0.localizedCaseInsensitiveContains("image") })
        XCTAssertFalse(keys.contains { $0.localizedCaseInsensitiveContains("screenshot") })
    }

    private func state(statusMessage: String = "Ready") -> DiagnosticsStateSnapshot {
        DiagnosticsStateSnapshot(
            profileCount: 2,
            activeProfileIDHash: DiagnosticsRedactor.hash("00000000-0000-0000-0000-000000000001", salt: "test"),
            activeProfileNameHash: DiagnosticsRedactor.hash("Private Profile", salt: "test"),
            activeProfileCategory: .desktopFPS,
            currentMode: .adaptive,
            permissionState: PermissionState(
                screenRecordingGranted: true,
                screenRecordingRequested: true,
                inputMonitoringRequested: true,
                inputMonitoringEnabled: false,
                lastRefreshedAt: Date(timeIntervalSince1970: 1)
            ),
            debugHUDVisible: false,
            captureModeDescription: "window filter",
            statusMessage: statusMessage
        )
    }

    private func overlay() -> DiagnosticsOverlaySnapshot {
        DiagnosticsOverlaySnapshot(
            enabled: true,
            emergencyActive: false,
            vignetteOpacity: 0.2,
            vignetteInnerRadius: 0.82,
            vignetteOuterRadius: 1.12,
            vignetteSoftness: 0.12,
            centerDotEnabled: true,
            centerDotOpacity: 0.18,
            centerDotRadius: 3,
            crosshairEnabled: false,
            crosshairOpacity: 0.16,
            crosshairLength: 22,
            crosshairThickness: 1,
            horizonEnabled: true,
            horizonOpacity: 0.12,
            horizonY: 0.5,
            dashboardEnabled: false,
            dashboardOpacity: 0.12,
            virtualNoseEnabled: false,
            virtualNoseOpacity: 0.1,
            peripheralFrameEnabled: true,
            peripheralFrameOpacity: 0.08,
            peripheralFrameThickness: 1
        )
    }

    private func allKeys(in value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.flatMap { key in
                guard let nestedValue = dictionary[key] else {
                    return [key]
                }
                return [key] + allKeys(in: nestedValue)
            }
        }
        if let array = value as? [Any] {
            return array.flatMap(allKeys(in:))
        }
        return []
    }
}
