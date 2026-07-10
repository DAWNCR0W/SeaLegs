import AppKit

@MainActor
final class OverlayManager {
    private let overlayState: OverlayState
    private let appState: AppState
    private var controllers: [CGDirectDisplayID: OverlayPanelController] = [:]
    private var targetDisplayIDs: Set<CGDirectDisplayID>?
    private var menuInteractionSuspended = false
    private var appInteractionSuspended = false
    private var modalInteractionSuspended = false

    init(overlayState: OverlayState, appState: AppState) {
        self.overlayState = overlayState
        self.appState = appState
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func show(on screens: [NSScreen] = NSScreen.screens) {
        targetDisplayIDs = Set(screens.map(displayID(for:)))
        syncControllers(with: screens)
        controllers.values.forEach {
            $0.setInteractionSuspension(
                menu: menuInteractionSuspended,
                app: shouldSuspendForAppWindow
            )
            $0.show()
        }
        overlayState.enabled = true
    }

    func hide() {
        controllers.values.forEach { $0.hide() }
        controllers.removeAll()
        targetDisplayIDs = nil
        overlayState.deactivate()
    }

    func refreshScreens() {
        let screens = screensForCurrentTarget()
        syncControllers(with: screens)
        controllers.values.forEach { $0.updateFrame() }
        if overlayState.enabled {
            controllers.values.forEach { $0.show() }
        }
    }

    func updateTargetScreens(_ screens: [NSScreen]) {
        guard overlayState.enabled else {
            return
        }
        let nextDisplayIDs = Set(screens.map(displayID(for:)))
        guard nextDisplayIDs != targetDisplayIDs else {
            return
        }
        targetDisplayIDs = nextDisplayIDs
        syncControllers(with: screens)
        controllers.values.forEach { $0.show() }
    }

    func setMenuInteractionSuspended(_ suspended: Bool) {
        menuInteractionSuspended = suspended
        updateInteractionSuspension()
    }

    func setAppInteractionSuspended(_ suspended: Bool) {
        appInteractionSuspended = suspended
        updateInteractionSuspension()
    }

    func setModalInteractionSuspended(_ suspended: Bool) {
        modalInteractionSuspended = suspended
        updateInteractionSuspension()
    }

    private func syncControllers(with screens: [NSScreen]) {
        for screen in screens {
            let key = displayID(for: screen)
            if let controller = controllers[key] {
                controller.update(screen: screen)
                continue
            }
            let controller = OverlayPanelController(screen: screen, overlayState: overlayState, appState: appState)
            controller.setInteractionSuspension(
                menu: menuInteractionSuspended,
                app: shouldSuspendForAppWindow
            )
            controllers[key] = controller
        }

        let currentKeys = Set(screens.map(displayID(for:)))
        for key in controllers.keys where !currentKeys.contains(key) {
            controllers[key]?.hide()
            controllers.removeValue(forKey: key)
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    private func screensForCurrentTarget() -> [NSScreen] {
        guard let targetDisplayIDs else {
            return NSScreen.screens
        }
        let matches = NSScreen.screens.filter { targetDisplayIDs.contains(displayID(for: $0)) }
        if !matches.isEmpty {
            return matches
        }
        return [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
    }

    private func updateInteractionSuspension() {
        controllers.values.forEach {
            $0.setInteractionSuspension(
                menu: menuInteractionSuspended,
                app: shouldSuspendForAppWindow
            )
        }
    }

    private var shouldSuspendForAppWindow: Bool {
        appInteractionSuspended
            || modalInteractionSuspended
            || NSApp.windows.contains { window in
                !(window is OverlayPanel)
                    && window.isVisible
                    && !window.isMiniaturized
                    && (window.isKeyWindow || window.isMainWindow)
            }
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        refreshScreens()
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        refreshScreens()
    }
}
