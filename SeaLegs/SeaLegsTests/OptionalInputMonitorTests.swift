import XCTest
@testable import SeaLegs

final class OptionalInputMonitorTests: XCTestCase {
    func testTurnScoreDecaysAfterInputStops() {
        let recent = OptionalInputMonitor.decayedTurnScore(1, elapsed: 0.05)
        let stale = OptionalInputMonitor.decayedTurnScore(1, elapsed: 1)

        XCTAssertGreaterThan(recent, 0.7)
        XCTAssertLessThan(stale, 0.01)
    }

    func testTurnScoreDecayStaysWithinUnitRange() {
        XCTAssertEqual(OptionalInputMonitor.decayedTurnScore(0, elapsed: 1), 0)
        XCTAssertEqual(OptionalInputMonitor.decayedTurnScore(2, elapsed: 0), 1)
    }
}
