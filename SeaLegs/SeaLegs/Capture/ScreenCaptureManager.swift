import AVFoundation
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit

@MainActor
@available(macOS 14.0, *)
final class ScreenCaptureManager: NSObject, SCStreamDelegate {
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "ScreenCapture")
    private let resolver: CaptureTargetResolver
    private let analyzer: MotionAnalyzer
    private let outputQueue = DispatchQueue(label: "SeaLegs.capture.output", qos: .userInitiated)
    private var stream: SCStream?
    private var outputHandler: StreamOutputHandler?
    private var transitionInProgress = false
    private var transitionWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var modeDescription: String = "stopped"

    var onError: ((Error) -> Void)?

    init(
        resolver: CaptureTargetResolver = CaptureTargetResolver(),
        analyzer: MotionAnalyzer
    ) {
        self.resolver = resolver
        self.analyzer = analyzer
    }

    func start(
        appInfo: RunningAppInfo?,
        adaptiveConfig: AdaptiveConfig,
        overlayConfigProvider: @escaping () -> OverlayConfig?,
        emergencyProvider: @escaping () -> Bool,
        inputTurnScoreProvider: @escaping () -> Float,
        generation: UUID
    ) async {
        await withSerializedTransition {
            await startCapture(
                appInfo: appInfo,
                adaptiveConfig: adaptiveConfig,
                overlayConfigProvider: overlayConfigProvider,
                emergencyProvider: emergencyProvider,
                inputTurnScoreProvider: inputTurnScoreProvider,
                generation: generation
            )
        }
    }

    func stop() async {
        await withSerializedTransition {
            _ = await stopCurrentCapture()
        }
    }

    nonisolated func stream(_ stoppedStream: SCStream, didStopWithError error: Error) {
        let stoppedStreamIdentifier = ObjectIdentifier(stoppedStream)
        Task { @MainActor [weak self] in
            self?.handleStoppedStream(stoppedStreamIdentifier, error: error)
        }
    }

    private func handleStoppedStream(_ stoppedStreamIdentifier: ObjectIdentifier, error: Error) {
        logger.error("SCStream stopped with error: \(error.localizedDescription)")
        guard let stream, ObjectIdentifier(stream) == stoppedStreamIdentifier else {
            return
        }
        clearCapture(ifMatching: stream, modeDescription: "fallback: basic overlay")
        onError?(error)
    }

    private func startCapture(
        appInfo: RunningAppInfo?,
        adaptiveConfig: AdaptiveConfig,
        overlayConfigProvider: @escaping () -> OverlayConfig?,
        emergencyProvider: @escaping () -> Bool,
        inputTurnScoreProvider: @escaping () -> Float,
        generation: UUID
    ) async {
        guard await stopCurrentCapture() else {
            return
        }
        guard !Task.isCancelled else {
            return
        }

        analyzer.resetSession()
        do {
            let target = try await resolver.resolve(for: appInfo)
            guard !Task.isCancelled else {
                return
            }

            let effectiveFramesPerSecond = adaptiveConfig.effectiveFramesPerSecond
            let configuration = SCStreamConfiguration()
            configuration.width = adaptiveConfig.captureWidth
            configuration.height = adaptiveConfig.captureHeight
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, effectiveFramesPerSecond)))
            configuration.queueDepth = adaptiveConfig.effectiveQueueDepth
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.pixelFormat = kCVPixelFormatType_32BGRA

            let handler = StreamOutputHandler(
                frameReducer: FrameReducer(
                    targetWidth: adaptiveConfig.effectiveAnalysisWidth,
                    targetHeight: adaptiveConfig.effectiveAnalysisHeight
                ),
                analyzer: analyzer,
                configProvider: overlayConfigProvider,
                emergencyProvider: emergencyProvider,
                inputTurnScoreProvider: inputTurnScoreProvider,
                generation: generation
            )
            let newStream = SCStream(filter: target.filter, configuration: configuration, delegate: self)
            try newStream.addStreamOutput(handler, type: .screen, sampleHandlerQueue: outputQueue)
            stream = newStream
            self.outputHandler = handler
            do {
                try await newStream.startCapture()
            } catch {
                let failureMode = Task.isCancelled ? "stopped" : "fallback: basic overlay"
                clearCapture(ifMatching: newStream, modeDescription: failureMode)
                guard !Task.isCancelled else {
                    return
                }
                throw error
            }

            guard !Task.isCancelled else {
                _ = await stopCurrentCapture()
                return
            }
            guard stream === newStream else {
                return
            }
            self.modeDescription = target.modeDescription
        } catch {
            guard !Task.isCancelled else {
                if stream == nil {
                    modeDescription = "stopped"
                }
                return
            }
            logger.error("Screen capture failed: \(error.localizedDescription)")
            modeDescription = "fallback: basic overlay"
            onError?(error)
        }
    }

    private func stopCurrentCapture() async -> Bool {
        guard let currentStream = stream else {
            outputHandler = nil
            modeDescription = "stopped"
            return true
        }

        outputHandler?.invalidate()
        do {
            try await currentStream.stopCapture()
        } catch {
            logger.error("Failed to stop screen capture: \(error.localizedDescription)")
            guard stream === currentStream else {
                if stream == nil {
                    modeDescription = "stopped"
                }
                return true
            }
            if let outputHandler {
                try? currentStream.removeStreamOutput(outputHandler, type: .screen)
            }
            clearCapture(ifMatching: currentStream, modeDescription: "stopped")
            onError?(error)
            return false
        }

        if stream === currentStream {
            clearCapture(ifMatching: currentStream, modeDescription: "stopped")
        } else if stream == nil {
            modeDescription = "stopped"
        }
        return true
    }

    private func clearCapture(ifMatching stoppedStream: SCStream, modeDescription: String) {
        guard stream === stoppedStream else {
            return
        }
        outputHandler?.invalidate()
        stream = nil
        outputHandler = nil
        self.modeDescription = modeDescription
    }

    private func withSerializedTransition(_ operation: () async -> Void) async {
        await acquireTransition()
        defer { releaseTransition() }
        guard !Task.isCancelled else {
            return
        }
        await operation()
    }

    private func acquireTransition() async {
        guard transitionInProgress else {
            transitionInProgress = true
            return
        }

        await withCheckedContinuation { continuation in
            transitionWaiters.append(continuation)
        }
    }

    private func releaseTransition() {
        guard !transitionWaiters.isEmpty else {
            transitionInProgress = false
            return
        }

        transitionWaiters.removeFirst().resume()
    }
}
