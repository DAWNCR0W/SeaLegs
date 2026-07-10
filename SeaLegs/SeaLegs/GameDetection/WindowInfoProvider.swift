import AppKit
import Foundation

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
}
