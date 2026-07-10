import XCTest
@testable import SeaLegs

final class GameControllerMonitorTests: XCTestCase {
    func testTurnScoreUsesDeadzoneAndGammaCurve() {
        XCTAssertEqual(GameControllerMonitor.computeTurnScore(x: 0.05, y: 0.05), 0, accuracy: 0.001)
        XCTAssertGreaterThan(GameControllerMonitor.computeTurnScore(x: 0.9, y: 0), 0.6)
        XCTAssertLessThanOrEqual(GameControllerMonitor.computeTurnScore(x: 1, y: 1), 1)
    }
}
