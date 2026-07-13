import AppKit
import Foundation

/// A concrete AppKit panel frame resolved from either a game window or display.
///
/// Window bounds returned by `CGWindowListCopyWindowInfo` are in Quartz desktop
/// coordinates, while `NSPanel` uses AppKit desktop coordinates. Keeping the
/// converted frame and a stable identifier together prevents a move or resize
/// from being mistaken for a new overlay target.
struct OverlayPanelRegion: Equatable {
    enum Identifier: Hashable {
        case display(CGDirectDisplayID)
        case gameWindow(Int)
    }

    let identifier: Identifier
    let frame: CGRect
}

final class WindowInfoProvider {
    func visibleWindows(for processIdentifier: pid_t) -> [WindowInfo] {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawWindows.compactMap { dictionary in
            guard
                let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == processIdentifier,
                let layer = dictionary[kCGWindowLayer as String] as? Int,
                layer == 0,
                let alpha = dictionary[kCGWindowAlpha as String] as? Double,
                alpha > 0,
                let number = dictionary[kCGWindowNumber as String] as? Int,
                let boundsDict = dictionary[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                bounds.width >= 200,
                bounds.height >= 200
            else {
                return nil
            }

            return WindowInfo(
                ownerPID: ownerPID,
                name: dictionary[kCGWindowName as String] as? String,
                bounds: bounds,
                layer: layer,
                alpha: alpha,
                windowNumber: number
            )
        }
    }

    func activeDisplayIDs(for processIdentifier: pid_t) -> Set<CGDirectDisplayID> {
        let windows = visibleWindows(for: processIdentifier)
        let displayPairs: [(CGDirectDisplayID, CGRect)] = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return (displayID, CGDisplayBounds(displayID))
        }
        let displayBounds = Dictionary(uniqueKeysWithValues: displayPairs)
        return Self.activeDisplayIDs(windows: windows, displayBounds: displayBounds)
    }

    func primaryWindow(for processIdentifier: pid_t) -> WindowInfo? {
        Self.primaryWindow(in: visibleWindows(for: processIdentifier))
    }

    func primaryWindowPanelRegion(for processIdentifier: pid_t) -> OverlayPanelRegion? {
        let displayPairs: [(CGDirectDisplayID, CGRect)] = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return (displayID, CGDisplayBounds(displayID))
        }
        return Self.primaryWindowPanelRegion(
            windows: visibleWindows(for: processIdentifier),
            displayBounds: Dictionary(uniqueKeysWithValues: displayPairs)
        )
    }

    /// Chooses the largest valid visible window. Equal-area candidates use their
    /// Quartz window number so the choice is stable across polling passes.
    static func primaryWindow(in windows: [WindowInfo]) -> WindowInfo? {
        windows
            .filter { normalized($0.bounds) != nil }
            .sorted { lhs, rhs in
                let lhsArea = area(of: lhs.bounds)
                let rhsArea = area(of: rhs.bounds)
                if lhsArea != rhsArea {
                    return lhsArea > rhsArea
                }
                return lhs.windowNumber < rhs.windowNumber
            }
            .first
    }

    static func primaryWindowPanelRegion(
        windows: [WindowInfo],
        displayBounds: [CGDirectDisplayID: CGRect],
        mainDisplayID: CGDirectDisplayID = CGMainDisplayID()
    ) -> OverlayPanelRegion? {
        guard let window = primaryWindow(in: windows),
              let coordinateReference = displayBounds[mainDisplayID]
                ?? desktopQuartzBounds(displayBounds: displayBounds),
              let frame = appKitFrame(
                  fromQuartzFrame: window.bounds,
                  desktopQuartzBounds: coordinateReference
              ) else {
            return nil
        }
        return OverlayPanelRegion(identifier: .gameWindow(window.windowNumber), frame: frame)
    }

    static func desktopQuartzBounds(displayBounds: [CGDirectDisplayID: CGRect]) -> CGRect? {
        let validBounds = displayBounds.values.compactMap(normalized)
        guard var desktopBounds = validBounds.first else {
            return nil
        }
        for bounds in validBounds.dropFirst() {
            desktopBounds = desktopBounds.union(bounds)
        }
        return desktopBounds
    }

    /// Converts a global Quartz rectangle (origin at the desktop's top edge) to
    /// the matching global AppKit rectangle (origin at the desktop's bottom edge).
    static func appKitFrame(fromQuartzFrame quartzFrame: CGRect, desktopQuartzBounds: CGRect) -> CGRect? {
        guard let normalizedQuartzFrame = normalized(quartzFrame),
              let normalizedDesktopBounds = normalized(desktopQuartzBounds) else {
            return nil
        }
        let converted = CGRect(
            x: normalizedQuartzFrame.minX,
            y: normalizedDesktopBounds.maxY - normalizedQuartzFrame.maxY,
            width: normalizedQuartzFrame.width,
            height: normalizedQuartzFrame.height
        )
        return normalized(converted)
    }

    static func activeDisplayIDs(
        windows: [WindowInfo],
        displayBounds: [CGDirectDisplayID: CGRect]
    ) -> Set<CGDirectDisplayID> {
        var selected: Set<CGDirectDisplayID> = []
        var overlapByDisplay: [CGDirectDisplayID: CGFloat] = [:]

        for window in windows {
            let windowArea = max(window.bounds.width * window.bounds.height, 1)
            for (displayID, bounds) in displayBounds {
                let intersection = bounds.intersection(window.bounds)
                guard !intersection.isNull else {
                    continue
                }
                let overlapArea = intersection.width * intersection.height
                overlapByDisplay[displayID, default: 0] += overlapArea
                if overlapArea / windowArea >= 0.20 {
                    selected.insert(displayID)
                }
            }
        }

        if selected.isEmpty, let bestMatch = overlapByDisplay.max(by: { $0.value < $1.value })?.key {
            selected.insert(bestMatch)
        }
        return selected
    }

    private static func area(of frame: CGRect) -> CGFloat {
        guard let frame = normalized(frame) else {
            return 0
        }
        return frame.width * frame.height
    }

    private static func normalized(_ frame: CGRect) -> CGRect? {
        guard !frame.isNull, !frame.isInfinite else {
            return nil
        }
        let normalizedFrame = frame.standardized
        guard normalizedFrame.width.isFinite,
              normalizedFrame.height.isFinite,
              normalizedFrame.width > 0,
              normalizedFrame.height > 0 else {
            return nil
        }
        return normalizedFrame
    }
}
