import Carbon
import Foundation
import OSLog

enum HotkeyAction: UInt32, CaseIterable {
    case toggleOverlay = 1
    case increaseStrength = 2
    case decreaseStrength = 3
    case emergencyMode = 4
    case discomfortRating = 5
    case debugHUD = 6

    var label: String {
        switch self {
        case .toggleOverlay: "Overlay Toggle"
        case .increaseStrength: "Comfort Up"
        case .decreaseStrength: "Comfort Down"
        case .emergencyMode: "Emergency"
        case .discomfortRating: "Discomfort Score"
        case .debugHUD: "Debug HUD"
        }
    }
}

struct HotkeyRegistrationStatus: Identifiable, Equatable {
    let action: HotkeyAction
    let shortcut: String
    let registered: Bool
    let statusCode: OSStatus

    var id: UInt32 { action.rawValue }

    var label: String { action.label }

    var statusDescription: String {
        registered ? "Registered" : "Unavailable (\(statusCode))"
    }
}

private struct HotkeyDescriptor {
    let action: HotkeyAction
    let keyCode: Int
    let modifiers: UInt32
    let shortcut: String
}

final class HotkeyManager {
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Hotkeys")
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?
    nonisolated(unsafe) private static var callback: ((HotkeyAction) -> Void)?
    private static let signature = OSType(UInt32(ascii: "SLmf"))
    private static let comfortModifiers = UInt32(optionKey | cmdKey)
    private static let utilityModifiers = UInt32(controlKey | optionKey | cmdKey)

    private static let defaultDescriptors: [HotkeyDescriptor] = [
        HotkeyDescriptor(action: .toggleOverlay, keyCode: kVK_F10, modifiers: comfortModifiers, shortcut: "⌥⌘F10"),
        HotkeyDescriptor(action: .increaseStrength, keyCode: kVK_F11, modifiers: comfortModifiers, shortcut: "⌥⌘F11"),
        HotkeyDescriptor(action: .decreaseStrength, keyCode: kVK_F9, modifiers: comfortModifiers, shortcut: "⌥⌘F9"),
        HotkeyDescriptor(action: .emergencyMode, keyCode: kVK_F12, modifiers: comfortModifiers, shortcut: "⌥⌘F12"),
        HotkeyDescriptor(action: .discomfortRating, keyCode: kVK_ANSI_S, modifiers: utilityModifiers, shortcut: "⌃⌥⌘S"),
        HotkeyDescriptor(action: .debugHUD, keyCode: kVK_ANSI_D, modifiers: utilityModifiers, shortcut: "⌃⌥⌘D")
    ]

    static var defaultRegistrationStatuses: [HotkeyRegistrationStatus] {
        defaultDescriptors.map {
            HotkeyRegistrationStatus(action: $0.action, shortcut: $0.shortcut, registered: false, statusCode: -1)
        }
    }

    @discardableResult
    func registerDefaults(callback: @escaping (HotkeyAction) -> Void) -> [HotkeyRegistrationStatus] {
        unregister()
        Self.callback = callback
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else {
                    return noErr
                }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, let action = HotkeyAction(rawValue: hotKeyID.id) else {
                    return status
                }
                HotkeyManager.callback?(action)
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )

        guard installStatus == noErr else {
            logger.error("Failed to install hotkey handler: \(installStatus)")
            return Self.defaultDescriptors.map {
                HotkeyRegistrationStatus(action: $0.action, shortcut: $0.shortcut, registered: false, statusCode: installStatus)
            }
        }

        return Self.defaultDescriptors.map { descriptor in
            let status = register(action: descriptor.action, keyCode: descriptor.keyCode, modifiers: descriptor.modifiers)
            return HotkeyRegistrationStatus(
                action: descriptor.action,
                shortcut: descriptor.shortcut,
                registered: status == noErr,
                statusCode: status
            )
        }
    }

    func unregister() {
        hotKeyRefs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
        Self.callback = nil
    }

    private func register(action: HotkeyAction, keyCode: Int, modifiers: UInt32) -> OSStatus {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        } else {
            logger.warning("Failed to register hotkey \(action.rawValue): \(status)")
        }
        return status
    }
}

extension UInt32 {
    init(ascii: String) {
        self = ascii.utf8.reduce(0) { partial, byte in
            (partial << 8) + UInt32(byte)
        }
    }
}
