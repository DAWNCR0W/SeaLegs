import CoreGraphics
import Foundation

struct InputMotionSignal {
    let timestamp: TimeInterval
    let mouseDeltaMagnitude: Float
    let mouseDeltaX: Float
    let mouseDeltaY: Float
    let gamepadRightStickMagnitude: Float?
}

final class OptionalInputMonitor {
    private let lock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var smoothedTurnScore: Float = 0
    private var lastTimestamp: TimeInterval?

    var turnScore: Float {
        let now = Date().timeIntervalSince1970
        return lock.withLock {
            guard let lastTimestamp else {
                return 0
            }
            return Self.decayedTurnScore(
                smoothedTurnScore,
                elapsed: max(0, now - lastTimestamp)
            )
        }
    }

    func start() -> Bool {
        stop()
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<OptionalInputMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.reenableEventTap()
                    return Unmanaged.passUnretained(event)
                }
                guard type == .mouseMoved else {
                    return Unmanaged.passUnretained(event)
                }
                monitor.consume(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        lock.withLock {
            smoothedTurnScore = 0
            lastTimestamp = nil
        }
    }

    private func consume(event: CGEvent) {
        let now = Date().timeIntervalSince1970
        let deltaX = Float(event.getDoubleValueField(.mouseEventDeltaX))
        let deltaY = Float(event.getDoubleValueField(.mouseEventDeltaY))
        let magnitude = abs(deltaX) + abs(deltaY)
        lock.withLock {
            let dt = Float(max(0.001, now - (lastTimestamp ?? now)))
            let alpha = 1 - exp(-dt / 0.12)
            smoothedTurnScore += alpha * (clamp(magnitude / 120) - smoothedTurnScore)
            lastTimestamp = now
        }
    }

    private func reenableEventTap() {
        guard let eventTap else {
            return
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    static func decayedTurnScore(_ score: Float, elapsed: TimeInterval) -> Float {
        clamp(score * exp(-Float(max(0, elapsed)) / 0.18))
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
