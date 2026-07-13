import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: String, Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case unavailable

    var isEnabled: Bool { self == .enabled }

    var label: String {
        switch self {
        case .enabled: "Enabled"
        case .notRegistered: "Not Registered"
        case .requiresApproval: "Requires Approval"
        case .unavailable: "Unavailable"
        }
    }
}

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

@MainActor
final class LaunchAtLoginService: LaunchAtLoginControlling {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LaunchAtLoginStatus {
        Self.status(from: service.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status != .enabled else {
                return
            }
            try service.register()
            return
        }
        guard service.status != .notRegistered else {
            return
        }
        try service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func status(from status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
}
