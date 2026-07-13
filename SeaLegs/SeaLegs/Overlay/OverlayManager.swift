import AppKit

@MainActor
final class OverlayManager {
    private let overlayState: OverlayState
    private let appState: AppState
    private var controllers: [OverlayPanelRegion.Identifier: OverlayPanelController] = [:]
    private var targetRegions: [OverlayPanelRegion.Identifier: OverlayPanelRegion]?
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
        show(regions: panelRegions(for: screens))
    }

    /// Shows overlay panels using explicit AppKit regions. This preserves the
    /// legacy screen-based API while allowing a game-window target to update its
    /// frame without changing identity.
    func show(regions: [OverlayPanelRegion]) {
        targetRegions = regionMap(for: regions)
        syncControllers(with: regions)
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
        targetRegions = nil
        overlayState.deactivate()
    }

    func refreshScreens() {
        let regions = regionsForCurrentTarget()
        targetRegions = regionMap(for: regions)
        syncControllers(with: regions)
        controllers.values.forEach { $0.updateFrame() }
        if overlayState.enabled {
            controllers.values.forEach { $0.show() }
        }
    }

    func updateTargetScreens(_ screens: [NSScreen]) {
        updateRegions(panelRegions(for: screens))
    }

    /// Updates existing panels when a target has the same identity but a new
    /// frame, such as a game window that was moved or resized.
    func updateRegions(_ regions: [OverlayPanelRegion]) {
        guard overlayState.enabled else {
            return
        }
        let nextRegions = regionMap(for: regions)
        guard nextRegions != targetRegions else {
            return
        }
        targetRegions = nextRegions
        syncControllers(with: regions)
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

    private func syncControllers(with regions: [OverlayPanelRegion]) {
        for region in regions {
            let key = region.identifier
            if let controller = controllers[key] {
                controller.update(frame: region.frame)
                continue
            }
            let controller = OverlayPanelController(frame: region.frame, overlayState: overlayState, appState: appState)
            controller.setInteractionSuspension(
                menu: menuInteractionSuspended,
                app: shouldSuspendForAppWindow
            )
            controllers[key] = controller
        }

        let currentKeys = Set(regions.map(\.identifier))
        let removedKeys = controllers.keys.filter { !currentKeys.contains($0) }
        for key in removedKeys {
            controllers[key]?.hide()
            controllers.removeValue(forKey: key)
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    private func panelRegions(for screens: [NSScreen]) -> [OverlayPanelRegion] {
        screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return OverlayPanelRegion(identifier: .display(displayID), frame: screen.frame)
        }
    }

    private func regionMap(for regions: [OverlayPanelRegion]) -> [OverlayPanelRegion.Identifier: OverlayPanelRegion] {
        Dictionary(regions.map { ($0.identifier, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func regionsForCurrentTarget() -> [OverlayPanelRegion] {
        guard let targetRegions else {
            return panelRegions(for: NSScreen.screens)
        }

        let currentScreens = Dictionary(
            NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
                guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    return nil
                }
                return (displayID, screen)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let regions = targetRegions.values.compactMap { region -> OverlayPanelRegion? in
            guard case let .display(displayID) = region.identifier else {
                return region
            }
            guard let screen = currentScreens[displayID] else {
                return nil
            }
            return OverlayPanelRegion(identifier: region.identifier, frame: screen.frame)
        }
        if !regions.isEmpty {
            return regions
        }
        return panelRegions(for: [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 })
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
