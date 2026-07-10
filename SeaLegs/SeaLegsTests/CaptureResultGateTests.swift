import XCTest
@testable import SeaLegs

final class CaptureResultGateTests: XCTestCase {
    func testAcceptsOnlyCurrentAdaptiveSessionResults() {
        let generation = UUID()
        let profileID = UUID()

        XCTAssertTrue(CaptureResultGate.shouldAccept(
            resultGeneration: generation,
            activeGeneration: generation,
            mode: .adaptive,
            overlayEnabled: true,
            activeProfileID: profileID,
            sessionProfileID: profileID
        ))
    }

    func testRejectsStaleOrInactiveResults() {
        let generation = UUID()
        let profileID = UUID()

        XCTAssertFalse(CaptureResultGate.shouldAccept(
            resultGeneration: UUID(),
            activeGeneration: generation,
            mode: .adaptive,
            overlayEnabled: true,
            activeProfileID: profileID,
            sessionProfileID: profileID
        ))
        XCTAssertFalse(CaptureResultGate.shouldAccept(
            resultGeneration: generation,
            activeGeneration: generation,
            mode: .adaptive,
            overlayEnabled: false,
            activeProfileID: profileID,
            sessionProfileID: profileID
        ))
        XCTAssertFalse(CaptureResultGate.shouldAccept(
            resultGeneration: generation,
            activeGeneration: generation,
            mode: .medium,
            overlayEnabled: true,
            activeProfileID: profileID,
            sessionProfileID: profileID
        ))
    }
}
