import CoreGraphics
import XCTest
@testable import SeaLegs

final class WindowInfoProviderTests: XCTestCase {
    func testPrimaryWindowChoosesLargestAreaThenLowestWindowNumber() {
        let windows = [
            WindowInfo(ownerPID: 1, name: "Small", bounds: CGRect(x: 0, y: 0, width: 800, height: 600), layer: 0, alpha: 1, windowNumber: 30),
            WindowInfo(ownerPID: 1, name: "Large later", bounds: CGRect(x: 0, y: 0, width: 1_600, height: 900), layer: 0, alpha: 1, windowNumber: 40),
            WindowInfo(ownerPID: 1, name: "Large first", bounds: CGRect(x: 100, y: 100, width: 1_600, height: 900), layer: 0, alpha: 1, windowNumber: 20),
        ]

        XCTAssertEqual(WindowInfoProvider.primaryWindow(in: windows)?.windowNumber, 20)
    }

    func testQuartzToAppKitConversionFlipsVerticalDesktopOrigin() throws {
        let desktop = try XCTUnwrap(
            WindowInfoProvider.desktopQuartzBounds(displayBounds: [
                1: CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080),
                2: CGRect(x: 0, y: -300, width: 2_560, height: 1_740),
            ])
        )
        let converted = try XCTUnwrap(
            WindowInfoProvider.appKitFrame(
                fromQuartzFrame: CGRect(x: 120, y: 200, width: 800, height: 600),
                desktopQuartzBounds: desktop
            )
        )

        XCTAssertEqual(converted, CGRect(x: 120, y: 640, width: 800, height: 600))
    }

    func testPrimaryWindowPanelRegionUsesStableWindowIdentifierAndConvertedFrame() throws {
        let windows = [
            WindowInfo(ownerPID: 1, name: "Game", bounds: CGRect(x: 100, y: 200, width: 1_200, height: 700), layer: 0, alpha: 1, windowNumber: 99),
            WindowInfo(ownerPID: 1, name: "Launcher", bounds: CGRect(x: 0, y: 0, width: 400, height: 300), layer: 0, alpha: 1, windowNumber: 2),
        ]
        let region = try XCTUnwrap(
            WindowInfoProvider.primaryWindowPanelRegion(
                windows: windows,
                displayBounds: [1: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)],
                mainDisplayID: 1
            )
        )

        XCTAssertEqual(region.identifier, .gameWindow(99))
        XCTAssertEqual(region.frame, CGRect(x: 100, y: 180, width: 1_200, height: 700))
    }

    func testPrimaryWindowPanelRegionUsesMainDisplayAsVerticalCoordinateReference() throws {
        let windows = [
            WindowInfo(
                ownerPID: 1,
                name: "Game Below Main",
                bounds: CGRect(x: 100, y: 1_200, width: 900, height: 500),
                layer: 0,
                alpha: 1,
                windowNumber: 50
            )
        ]
        let region = try XCTUnwrap(
            WindowInfoProvider.primaryWindowPanelRegion(
                windows: windows,
                displayBounds: [
                    1: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
                    2: CGRect(x: 0, y: 1_080, width: 1_920, height: 1_080),
                ],
                mainDisplayID: 1
            )
        )

        XCTAssertEqual(region.frame, CGRect(x: 100, y: -620, width: 900, height: 500))
    }

    func testActiveDisplaySelectionUsesWindowOverlapInQuartzCoordinates() {
        let windows = [
            WindowInfo(
                ownerPID: 1,
                name: "Game",
                bounds: CGRect(x: 2100, y: 100, width: 1200, height: 800),
                layer: 0,
                alpha: 1,
                windowNumber: 10
            )
        ]
        let displays: [CGDirectDisplayID: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            2: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        ]

        XCTAssertEqual(WindowInfoProvider.activeDisplayIDs(windows: windows, displayBounds: displays), [2])
    }

    func testActiveDisplaySelectionFallsBackToLargestOverlap() {
        let windows = [
            WindowInfo(
                ownerPID: 1,
                name: "Game",
                bounds: CGRect(x: 1800, y: 1000, width: 400, height: 600),
                layer: 0,
                alpha: 1,
                windowNumber: 11
            )
        ]
        let displays: [CGDirectDisplayID: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            2: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        ]

        XCTAssertEqual(WindowInfoProvider.activeDisplayIDs(windows: windows, displayBounds: displays), [2])
    }
}
