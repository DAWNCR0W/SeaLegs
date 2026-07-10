import Foundation
import GameController

final class GameControllerMonitor {
    private let lock = NSLock()
    private var storedRightStickMagnitude: Float = 0

    var rightStickMagnitude: Float {
        lock.lock()
        defer { lock.unlock() }
        return storedRightStickMagnitude
    }

    func start() {
        stop()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        GCController.controllers().forEach(register(controller:))
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
        GCController.controllers().forEach { controller in
            controller.extendedGamepad?.rightThumbstick.valueChangedHandler = nil
        }
        lock.lock()
        storedRightStickMagnitude = 0
        lock.unlock()
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        register(controller: controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        lock.lock()
        storedRightStickMagnitude = 0
        lock.unlock()
    }

    private func register(controller: GCController) {
        controller.extendedGamepad?.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else {
                return
            }
            self.lock.lock()
            self.storedRightStickMagnitude = Self.computeTurnScore(x: xValue, y: yValue)
            self.lock.unlock()
        }
    }

    static func computeTurnScore(x: Float, y: Float) -> Float {
        let magnitude = sqrt(x * x + y * y)
        let deadzone: Float = 0.12
        let normalized = max(0, (magnitude - deadzone) / (1 - deadzone))
        return pow(min(1, normalized), 1.4)
    }
}
