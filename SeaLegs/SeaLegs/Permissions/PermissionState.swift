import Foundation

struct PermissionState: Codable, Equatable {
    var screenRecordingGranted: Bool
    var screenRecordingRequested: Bool
    var inputMonitoringRequested: Bool
    var inputMonitoringEnabled: Bool
    var lastRefreshedAt: Date

    static let unknown = PermissionState(
        screenRecordingGranted: false,
        screenRecordingRequested: false,
        inputMonitoringRequested: false,
        inputMonitoringEnabled: false,
        lastRefreshedAt: .distantPast
    )
}
