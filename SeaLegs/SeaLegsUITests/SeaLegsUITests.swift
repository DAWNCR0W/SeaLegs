import XCTest

@MainActor
final class SeaLegsUITests: XCTestCase {
    func testSettingsSmokeUsesDeterministicTestLaunchConfiguration() {
        continueAfterFailure = false
        let supportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeaLegsUITests-\(UUID().uuidString)", isDirectory: true)
        let app = XCUIApplication()
        defer {
            app.terminate()
            try? FileManager.default.removeItem(at: supportDirectory)
        }
        app.launchArguments = [
            "--ui-testing",
            "--show-settings",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["SEALEGS_UI_TEST_DATA_DIR"] = supportDirectory.path
        app.launch()
        let settingsWindow = app.windows["sealegs.settings.window"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))

        let settingsNavigation = app.descendants(matching: .any)["sealegs.settings.navigation"]
        XCTAssertTrue(settingsNavigation.waitForExistence(timeout: 5))

        let resolvedTarget = app.descendants(matching: .any)["sealegs.general.resolved-target"]
        XCTAssertTrue(resolvedTarget.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: resolvedTarget.value ?? "").contains("Game Window"))

        let compatibilityLink = app.descendants(matching: .any)["sealegs.settings.page.compatibility"]
        XCTAssertTrue(compatibilityLink.waitForExistence(timeout: 5))
        compatibilityLink.click()
        XCTAssertTrue(
            app.descendants(matching: .any)["sealegs.compatibility.page"]
                .waitForExistence(timeout: 5)
        )

        let overlayLink = app.descendants(matching: .any)["sealegs.settings.page.overlay"]
        XCTAssertTrue(overlayLink.waitForExistence(timeout: 5))
        overlayLink.click()
        XCTAssertTrue(
            app.descendants(matching: .any)["sealegs.overlay.page"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.sliders["Center Dot Horizontal Position"].exists)
    }
}
