import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private lazy var coordinator: AppCoordinator = {
        let environment = ProcessInfo.processInfo.environment
        let profileStore = environment["SEALEGS_UI_TEST_DATA_DIR"].map {
            ProfileStore(baseURL: URL(fileURLWithPath: $0, isDirectory: true))
        } ?? ProfileStore()
        return AppCoordinator(
            profileStore: profileStore,
            runtimeServicesEnabled: !isUITesting
        )
    }()
    private var menuBarController: MenuBarController?
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var reportWindowController: NSWindowController?
    private var debugWindowController: NSWindowController?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var didFinishLaunching = false
    private var pendingProfileURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.openSettingsHandler = { [weak self] in
            self?.showSettings()
        }
        coordinator.showReportHandler = { [weak self] in
            self?.showReport()
        }
        coordinator.showDebugHUDHandler = { [weak self] visible in
            self?.setDebugHUDVisible(visible)
        }
        if !isUITesting {
            menuBarController = MenuBarController(coordinator: coordinator)
            observeWorkspaceLifecycle()
        }
        coordinator.start()
        didFinishLaunching = true
        if let pendingProfileURL = pendingProfileURLs.first {
            pendingProfileURLs.removeAll()
            openProfileArchive(pendingProfileURL)
            return
        }
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--show-settings") {
            showSettings()
        }
        if arguments.contains("--show-feature-demo") {
            coordinator.showFeatureDemoOverlay(duration: 60)
            return
        }
        if arguments.contains("--show-settings") {
            return
        }
#endif
        if !UserDefaults.standard.bool(forKey: AppConstants.onboardingCompletedKey) {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver(_:))
        workspaceObservers.removeAll()
        coordinator.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let profileURL = urls.first(where: { $0.pathExtension.lowercased() == "sealegsprofile" }) else {
            return
        }
        guard didFinishLaunching else {
            pendingProfileURLs.append(profileURL)
            return
        }
        openProfileArchive(profileURL)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.applicationDidBecomeActive()
        updateOverlayInteractionSuspension()
    }

    func applicationDidResignActive(_ notification: Notification) {
        updateOverlayInteractionSuspension()
    }

    private func showOnboarding() {
        if let onboardingWindowController {
            coordinator.setAppInteractionSuspended(true)
            onboardingWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(coordinator: coordinator) { [weak self] in
            UserDefaults.standard.set(true, forKey: AppConstants.onboardingCompletedKey)
            self?.onboardingWindowController?.close()
            self?.onboardingWindowController = nil
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = coordinator.state.t("Welcome to SeaLegs")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: view)
        let controller = NSWindowController(window: window)
        onboardingWindowController = controller
        coordinator.setAppInteractionSuspended(true)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if let settingsWindowController {
            coordinator.setAppInteractionSuspended(true)
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsRootView(coordinator: coordinator)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppConstants.appName
        window.identifier = NSUserInterfaceItemIdentifier("sealegs.settings.window")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 960, height: 620)
        window.center()
        window.setFrameAutosaveName("SeaLegs.SettingsWindow")
        window.contentView = NSHostingView(rootView: view)
        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        coordinator.setAppInteractionSuspended(true)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openProfileArchive(_ url: URL) {
        showSettings()
        coordinator.importProfiles(from: url)
    }

    func showReport() {
        if let reportWindowController {
            reportWindowController.window?.contentView = NSHostingView(
                rootView: SessionReportWindowView(state: coordinator.state)
            )
            coordinator.setAppInteractionSuspended(true)
            reportWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SessionReportWindowView(state: coordinator.state)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = coordinator.state.t("Session Report")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 560, height: 420)
        window.center()
        window.setFrameAutosaveName("SeaLegs.SessionReportWindow")
        window.contentView = NSHostingView(rootView: view)
        let controller = NSWindowController(window: window)
        reportWindowController = controller
        coordinator.setAppInteractionSuspended(true)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setDebugHUDVisible(_ visible: Bool) {
        if visible {
            showDebugHUD()
            return
        }

        debugWindowController?.close()
        debugWindowController = nil
        updateOverlayInteractionSuspension()
    }

    private func showDebugHUD() {
        if let debugWindowController {
            debugWindowController.window?.contentView = NSHostingView(
                rootView: DebugHUDView(state: coordinator.state, overlayState: coordinator.overlayState)
            )
            coordinator.setAppInteractionSuspended(true)
            debugWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = DebugHUDView(state: coordinator.state, overlayState: coordinator.overlayState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = coordinator.state.t("Debug HUD")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 360, height: 300)
        window.center()
        window.setFrameAutosaveName("SeaLegs.DebugWindow")
        window.contentView = NSHostingView(rootView: view)
        let controller = NSWindowController(window: window)
        debugWindowController = controller
        coordinator.setAppInteractionSuspended(true)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        if window == settingsWindowController?.window {
            settingsWindowController = nil
        }
        if window == onboardingWindowController?.window {
            onboardingWindowController = nil
        }
        if window == reportWindowController?.window {
            reportWindowController = nil
        }
        if window == debugWindowController?.window {
            debugWindowController = nil
            coordinator.setDebugHUDVisible(false)
        }
        updateOverlayInteractionSuspension()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        updateOverlayInteractionSuspension()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        updateOverlayInteractionSuspension()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateOverlayInteractionSuspension()
    }

    func windowDidResignKey(_ notification: Notification) {
        updateOverlayInteractionSuspension()
    }

    private func updateOverlayInteractionSuspension() {
        let hasFocusedAppWindow = [
            settingsWindowController,
            onboardingWindowController,
            reportWindowController,
            debugWindowController
        ].contains { controller in
            guard let window = controller?.window else {
                return false
            }
            return window.isVisible
                && !window.isMiniaturized
                && (window.isKeyWindow || window.isMainWindow)
        }
        coordinator.setAppInteractionSuspended(hasFocusedAppWindow)
    }

    private func observeWorkspaceLifecycle() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.coordinator.systemWillSleep()
                }
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.coordinator.systemDidWake()
                }
            }
        )
    }
}
