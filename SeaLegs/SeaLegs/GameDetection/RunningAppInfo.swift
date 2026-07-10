import AppKit
import Foundation

struct RunningAppInfo: Codable, Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
    let executableURL: URL?
    let activationPolicyRaw: Int

    init(app: NSRunningApplication) {
        self.processIdentifier = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName
        self.executableURL = app.executableURL
        self.activationPolicyRaw = app.activationPolicy.rawValue
    }

    var executableName: String? {
        executableURL?.lastPathComponent
    }
}

struct WindowInfo: Equatable {
    let ownerPID: pid_t
    let name: String?
    let bounds: CGRect
    let layer: Int
    let alpha: Double
    let windowNumber: Int
}
