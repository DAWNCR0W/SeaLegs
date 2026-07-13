import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayPanelController {
    private var panel: OverlayPanel?
    private var panelFrame: CGRect
    private let overlayState: OverlayState
    private let appState: AppState
    private var menuInteractionSuspended = false
    private var appInteractionSuspended = false

    init(screen: NSScreen, overlayState: OverlayState, appState: AppState) {
        self.panelFrame = screen.frame
        self.overlayState = overlayState
        self.appState = appState
    }

    init(frame: CGRect, overlayState: OverlayState, appState: AppState) {
        self.panelFrame = frame
        self.overlayState = overlayState
        self.appState = appState
    }

    func show() {
        guard panel == nil else {
            updateFrame()
            updatePresentationOrder()
            return
        }

        let nextPanel = OverlayPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        nextPanel.isOpaque = false
        nextPanel.backgroundColor = .clear
        nextPanel.hasShadow = false
        nextPanel.ignoresMouseEvents = true
        nextPanel.hidesOnDeactivate = false
        nextPanel.isFloatingPanel = true
        nextPanel.worksWhenModal = true
        configureForFullscreenPersistence(nextPanel)

        let container = NSView(frame: nextPanel.contentView?.bounds ?? CGRect(origin: .zero, size: panelFrame.size))
        container.autoresizingMask = [.width, .height]

        let metalView = OverlayMetalView(frame: container.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.bind(state: overlayState)
        container.addSubview(metalView)

        let hudView = NSHostingView(rootView: OverlayHUDOverlayView(appState: appState, overlayState: overlayState))
        hudView.frame = container.bounds
        hudView.autoresizingMask = [.width, .height]
        hudView.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(hudView)

        nextPanel.contentView = container
        panel = nextPanel
        updatePresentationOrder()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func update(screen: NSScreen) {
        update(frame: screen.frame)
    }

    func update(frame: CGRect) {
        panelFrame = frame
        updateFrame()
    }

    func setInteractionSuspension(menu: Bool, app: Bool) {
        menuInteractionSuspended = menu
        appInteractionSuspended = app
        updatePresentationOrder()
    }

    func updateFrame() {
        panel?.setFrame(panelFrame, display: true)
        configureForFullscreenPersistence(panel)
        updatePresentationOrder()
    }

    private func configureForFullscreenPersistence(_ panel: OverlayPanel?) {
        guard let panel else {
            return
        }
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
    }

    private func updatePresentationOrder() {
        guard let panel else {
            return
        }
        configureForFullscreenPersistence(panel)
        if appInteractionSuspended {
            panel.level = .normal
            panel.orderBack(nil)
        } else if menuInteractionSuspended {
            panel.level = .floating
            panel.orderFrontRegardless()
        } else {
            panel.level = .screenSaver
            panel.orderFrontRegardless()
        }
    }
}

private struct OverlayHUDOverlayView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var overlayState: OverlayState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if overlayState.enabled, overlayState.emergencyActive || appState.overlayHUDVisible {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(appState.overlayHUDMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text(appState.overlayHUDDetail)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        .black.opacity(reduceTransparency ? 0.88 : (overlayState.emergencyActive ? 0.56 : 0.32)),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .foregroundStyle(.white)
                    .padding(.top, 22)
                    .padding(.trailing, 24)
                }
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
