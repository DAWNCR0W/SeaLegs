import ServiceManagement
import XCTest

@testable import SeaLegs

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testServiceManagementStatusesMapToUserFacingState() {
        XCTAssertEqual(LaunchAtLoginService.status(from: .enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginService.status(from: .notRegistered), .notRegistered)
        XCTAssertEqual(LaunchAtLoginService.status(from: .requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginService.status(from: .notFound), .unavailable)
    }

    func testCoordinatorUsesServiceStatusAsSourceOfTruth() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAtLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = FakeLaunchAtLoginService()
        let coordinator = AppCoordinator(
            profileStore: ProfileStore(baseURL: directory),
            launchAtLoginService: service,
            runtimeServicesEnabled: false
        )

        coordinator.start()
        coordinator.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(service.status, .enabled)
        XCTAssertEqual(coordinator.state.launchAtLoginStatus, .enabled)
        XCTAssertEqual(service.requestedValues, [true])
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus = .notRegistered
    var requestedValues: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        requestedValues.append(enabled)
        status = enabled ? .enabled : .notRegistered
    }

    func openSystemSettings() {}
}
