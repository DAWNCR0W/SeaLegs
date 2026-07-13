import AppKit
import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 14.0, *)
struct CaptureTarget {
    let filter: SCContentFilter
    let display: SCDisplay
    let modeDescription: String
}

enum CaptureTargetResolverError: LocalizedError {
    case missingAppTarget
    case missingShareableDisplay
    case unresolvedAppTarget

    var errorDescription: String? {
        switch self {
        case .missingAppTarget:
            "No registered game target is active."
        case .missingShareableDisplay:
            "No shareable display is available."
        case .unresolvedAppTarget:
            "The active game window could not be found for adaptive capture."
        }
    }
}

@available(macOS 14.0, *)
@MainActor
final class CaptureTargetResolver {
    private let windowInfoProvider: WindowInfoProvider

    init(windowInfoProvider: WindowInfoProvider = WindowInfoProvider()) {
        self.windowInfoProvider = windowInfoProvider
    }

    func resolve(for appInfo: RunningAppInfo?) async throws -> CaptureTarget {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displays = content.displays.sorted { $0.displayID < $1.displayID }
        guard !displays.isEmpty else {
            throw CaptureTargetResolverError.missingShareableDisplay
        }

        guard let appInfo else {
            throw CaptureTargetResolverError.missingAppTarget
        }

        let appWindows = content.windows.filter {
            $0.isOnScreen && $0.owningApplication?.processID == appInfo.processIdentifier
        }.sorted {
            $0.windowID < $1.windowID
        }
        if let windowIndex = CaptureTargetGeometry.largestWindowIndex(in: appWindows.map(\.frame)) {
            let window = appWindows[windowIndex]
            guard let displayIndex = CaptureTargetGeometry.displayIndex(
                containing: window.frame,
                displayFrames: displays.map(\.frame)
            ) else {
                throw CaptureTargetResolverError.missingShareableDisplay
            }

            return CaptureTarget(
                filter: SCContentFilter(desktopIndependentWindow: window),
                display: displays[displayIndex],
                modeDescription: "window filter"
            )
        }

        if let app = content.applications.first(where: { $0.processID == appInfo.processIdentifier }) {
            let fallbackWindows = windowInfoProvider.visibleWindows(for: appInfo.processIdentifier).sorted {
                $0.windowNumber < $1.windowNumber
            }
            guard let windowIndex = CaptureTargetGeometry.largestWindowIndex(in: fallbackWindows.map(\.bounds)),
                  let displayIndex = CaptureTargetGeometry.displayIndex(
                      containing: fallbackWindows[windowIndex].bounds,
                      displayFrames: displays.map(\.frame)
                  ) else {
                throw CaptureTargetResolverError.unresolvedAppTarget
            }

            return CaptureTarget(
                filter: SCContentFilter(display: displays[displayIndex], including: [app], exceptingWindows: []),
                display: displays[displayIndex],
                modeDescription: "application filter"
            )
        }

        throw CaptureTargetResolverError.unresolvedAppTarget
    }
}

enum CaptureTargetGeometry {
    static func largestWindowIndex(in windowFrames: [CGRect]) -> Int? {
        var largestIndex: Int?
        var largestArea: CGFloat = 0

        for index in windowFrames.indices {
            let candidateArea = area(of: windowFrames[index])
            if candidateArea > largestArea {
                largestIndex = index
                largestArea = candidateArea
            }
        }

        return largestIndex
    }

    static func displayIndex(containing windowFrame: CGRect, displayFrames: [CGRect]) -> Int? {
        guard let normalizedWindow = normalized(windowFrame) else {
            return nil
        }

        let displays = displayFrames.enumerated().compactMap { index, frame -> (Int, CGRect)? in
            guard let normalizedFrame = normalized(frame) else {
                return nil
            }
            return (index, normalizedFrame)
        }
        guard !displays.isEmpty else {
            return nil
        }

        var overlappingDisplayIndex: Int?
        var largestOverlap: CGFloat = 0
        for (index, displayFrame) in displays {
            let overlap = area(of: normalizedWindow.intersection(displayFrame))
            if overlap > largestOverlap {
                overlappingDisplayIndex = index
                largestOverlap = overlap
            }
        }
        if let overlappingDisplayIndex {
            return overlappingDisplayIndex
        }

        let windowCenter = CGPoint(x: normalizedWindow.midX, y: normalizedWindow.midY)
        var nearestDisplayIndex: Int?
        var nearestDistance = CGFloat.infinity
        for (index, displayFrame) in displays {
            let distance = squaredDistance(from: windowCenter, to: displayFrame)
            if distance < nearestDistance {
                nearestDisplayIndex = index
                nearestDistance = distance
            }
        }
        return nearestDisplayIndex
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
        let frame = frame.standardized
        guard frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else {
            return nil
        }
        return frame
    }

    private static func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let leftDistance = max(frame.minX - point.x, 0)
        let rightDistance = max(point.x - frame.maxX, 0)
        let bottomDistance = max(frame.minY - point.y, 0)
        let topDistance = max(point.y - frame.maxY, 0)
        let horizontalDistance = leftDistance + rightDistance
        let verticalDistance = bottomDistance + topDistance
        return horizontalDistance * horizontalDistance + verticalDistance * verticalDistance
    }
}
