import AppKit
import Foundation

@MainActor
final class GameDetector {
    private let workspace: NSWorkspace
    private let windowInfoProvider: WindowInfoProvider
    private var observer: NSObjectProtocol?
    var onActiveAppChanged: ((RunningAppInfo?) -> Void)?

    init(workspace: NSWorkspace = .shared, windowInfoProvider: WindowInfoProvider = WindowInfoProvider()) {
        self.workspace = workspace
        self.windowInfoProvider = windowInfoProvider
    }

    func start() {
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self.onActiveAppChanged?(app.map(RunningAppInfo.init(app:)))
            }
        }
        onActiveAppChanged?(currentFrontmostAppInfo())
    }

    func stop() {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    func currentFrontmostAppInfo() -> RunningAppInfo? {
        workspace.frontmostApplication.map(RunningAppInfo.init(app:))
    }

    func isRegisteredGameActive(app: RunningAppInfo?, profiles: [GameProfile]) -> GameProfile? {
        guard
            let app,
            app.activationPolicyRaw == NSApplication.ActivationPolicy.regular.rawValue
        else {
            return nil
        }

        return profiles.first {
            $0.matches(
                bundleIdentifier: app.bundleIdentifier,
                executableName: app.executableName,
                executablePath: app.executableURL?.path
            )
        }
    }

    func activeDisplayIDs(for app: RunningAppInfo?) -> Set<CGDirectDisplayID> {
        guard let app else {
            return []
        }
        return windowInfoProvider.activeDisplayIDs(for: app.processIdentifier)
    }
}
