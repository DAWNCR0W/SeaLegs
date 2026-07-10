import CoreGraphics
import XCTest
@testable import SeaLegs

final class WindowInfoProviderTests: XCTestCase {
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
