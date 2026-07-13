import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 14.0, *)
final class StreamOutputHandler: NSObject, SCStreamOutput {
    private let frameReducer: FrameReducer
    private let analyzer: MotionAnalyzer
    private let configProvider: () -> OverlayConfig?
    private let emergencyProvider: () -> Bool
    private let inputTurnScoreProvider: () -> Float
    private let generation: UUID
    private let stateLock = NSLock()
    private var isActive = true

    init(
        frameReducer: FrameReducer,
        analyzer: MotionAnalyzer,
        configProvider: @escaping () -> OverlayConfig?,
        emergencyProvider: @escaping () -> Bool,
        inputTurnScoreProvider: @escaping () -> Float,
        generation: UUID
    ) {
        self.frameReducer = frameReducer
        self.analyzer = analyzer
        self.configProvider = configProvider
        self.emergencyProvider = emergencyProvider
        self.inputTurnScoreProvider = inputTurnScoreProvider
        self.generation = generation
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard active, type == .screen else {
            return
        }
        guard isCompleteVideoFrame(sampleBuffer) else {
            return
        }
        guard CMSampleBufferIsValid(sampleBuffer), let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        guard let config = configProvider(), let reduced = frameReducer.reduce(pixelBuffer: pixelBuffer) else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        analyzer.consume(
            frame: reduced,
            timestamp: timestamp,
            config: config,
            emergencyActive: emergencyProvider(),
            optionalInputTurnScore: inputTurnScoreProvider(),
            generation: generation
        )
    }

    func invalidate() {
        stateLock.lock()
        isActive = false
        stateLock.unlock()
    }

    private var active: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isActive
    }

    private func isCompleteVideoFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let rawStatus = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return false
        }
        return status == .complete
    }
}
