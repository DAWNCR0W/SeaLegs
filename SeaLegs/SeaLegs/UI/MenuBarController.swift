import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusButton()
        statusItem.menu = makeMenu()
        coordinator.menuRefreshHandler = { [weak self] in
            self?.refreshMenu()
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        if let icon = NSImage(named: NSImage.Name("MenuBarIcon")) {
            icon.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.title = "SeaLegs"
        }
        button.toolTip = "SeaLegs"
        button.setAccessibilityLabel("SeaLegs")
        button.setAccessibilityHelp(coordinator.state.t("Open SeaLegs controls"))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let currentTargetFormat = coordinator.state.activeProfile == nil ? "Current App: %@" : "Current Game: %@"
        menu.addItem(
            withTitle: String(format: coordinator.state.t(currentTargetFormat), coordinator.state.localizedCurrentGameName),
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())

        let comfortMenu = NSMenu()
        for mode in ComfortMode.allCases {
            let item = NSMenuItem(title: coordinator.state.localizer.mode(mode), action: #selector(setComfortMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = coordinator.state.currentMode == mode ? .on : .off
            comfortMenu.addItem(item)
        }
        let comfortItem = NSMenuItem(title: coordinator.state.t("Comfort"), action: nil, keyEquivalent: "")
        comfortItem.submenu = comfortMenu
        menu.addItem(comfortItem)

        let overlayItem = item(coordinator.state.t("Toggle Overlay"), #selector(toggleOverlay))
        overlayItem.state = coordinator.overlayState.enabled ? .on : .off
        menu.addItem(overlayItem)

        let emergencyItem = item(coordinator.state.t("Emergency Mode"), #selector(toggleEmergency))
        emergencyItem.state = coordinator.overlayState.emergencyActive ? .on : .off
        menu.addItem(emergencyItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item(coordinator.state.t("Add Current App as Game..."), #selector(addCurrentApp)))
        menu.addItem(item(coordinator.state.t("Show Feature Demo"), #selector(showFeatureDemo)))
        let discomfortItem = item(coordinator.state.t("Record Discomfort Score..."), #selector(recordDiscomfort))
        discomfortItem.isEnabled = coordinator.state.activeProfile != nil
        menu.addItem(discomfortItem)
        menu.addItem(item(coordinator.state.t("Open Settings..."), #selector(openSettings)))
        menu.addItem(item(coordinator.state.t("Session Report..."), #selector(openSessionReport)))
        let debugItem = item(coordinator.state.t("Debug HUD"), #selector(toggleDebugHUD))
        debugItem.state = coordinator.state.debugHUDVisible ? .on : .off
        menu.addItem(debugItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item(coordinator.state.t("Quit"), #selector(quit)))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func refreshMenu() {
        statusItem.menu = makeMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        coordinator.setMenuInteractionSuspended(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        coordinator.setMenuInteractionSuspended(false)
    }

    @objc private func setComfortMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = ComfortMode(rawValue: rawValue)
        else {
            return
        }
        coordinator.setComfortMode(mode)
        refreshMenu()
    }

    @objc private func toggleEmergency() {
        coordinator.toggleEmergency()
        refreshMenu()
    }

    @objc private func toggleOverlay() {
        coordinator.toggleOverlay()
        refreshMenu()
    }

    @objc private func addCurrentApp() {
        coordinator.addCurrentAppAsGame()
        refreshMenu()
    }

    @objc private func showFeatureDemo() {
        coordinator.showFeatureDemoOverlay()
        refreshMenu()
    }

    @objc private func recordDiscomfort() {
        coordinator.promptForDiscomfortScore()
        refreshMenu()
    }

    @objc private func openSettings() {
        coordinator.openSettingsHandler?()
    }

    @objc private func openSessionReport() {
        coordinator.refreshSessionReport()
    }

    @objc private func toggleDebugHUD() {
        coordinator.toggleDebugHUD()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
