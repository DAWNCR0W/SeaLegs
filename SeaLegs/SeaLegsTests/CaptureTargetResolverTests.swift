import CoreGraphics
import XCTest

@testable import SeaLegs

final class CaptureTargetResolverTests: XCTestCase {
    func testLargestWindowIndexChoosesLargestPositiveFrame() {
        let frames = [
            CGRect(x: 0, y: 0, width: 640, height: 480),
            CGRect(x: 100, y: 100, width: 1920, height: 1080),
            .zero,
        ]

        XCTAssertEqual(CaptureTargetGeometry.largestWindowIndex(in: frames), 1)
    }

    func testLargestWindowIndexKeepsFirstWindowWhenAreasMatch() {
        let frames = [
            CGRect(x: 0, y: 0, width: 800, height: 600),
            CGRect(x: 200, y: 100, width: 800, height: 600),
        ]

        XCTAssertEqual(CaptureTargetGeometry.largestWindowIndex(in: frames), 0)
    }

    func testDisplayIndexChoosesDisplayWithLargestWindowOverlap() {
        let displays = [
            CGRect(x: 0, y: 0, width: 1_000, height: 800),
            CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
        ]
        let window = CGRect(x: 900, y: 100, width: 500, height: 500)

        XCTAssertEqual(CaptureTargetGeometry.displayIndex(containing: window, displayFrames: displays), 1)
    }

    func testDisplayIndexKeepsFirstDisplayWhenOverlapMatches() {
        let displays = [
            CGRect(x: 0, y: 0, width: 1_000, height: 800),
            CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
        ]
        let window = CGRect(x: 750, y: 100, width: 500, height: 500)

        XCTAssertEqual(CaptureTargetGeometry.displayIndex(containing: window, displayFrames: displays), 0)
    }

    func testDisplayIndexFallsBackToNearestDisplayWithoutOverlap() {
        let displays = [
            CGRect(x: 0, y: 0, width: 1_000, height: 800),
            CGRect(x: 1_200, y: 0, width: 1_000, height: 800),
        ]
        let window = CGRect(x: 2_300, y: 100, width: 400, height: 400)

        XCTAssertEqual(CaptureTargetGeometry.displayIndex(containing: window, displayFrames: displays), 1)
    }
}
