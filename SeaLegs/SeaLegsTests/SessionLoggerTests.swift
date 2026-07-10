import XCTest
@testable import SeaLegs

final class SessionLoggerTests: XCTestCase {
    func testDisabledLoggingKeepsReportDataInMemoryWithoutWritingFiles() throws {
        let sessionsURL = temporaryDirectory()
        let settings = TelemetrySettings(
            sessionLoggingEnabled: false,
            sessionSampleIntervalSeconds: 1,
            sessionLogRetentionDays: 14
        )
        let logger = SessionLogger(sessionsURL: sessionsURL, telemetrySettings: settings)
        logger.start(gameName: "Example")

        logger.record(sample: sample(timestamp: 0, score: 0.4))
        logger.record(rating: DiscomfortRating(timestamp: 0.5, score: 8, context: .manual))
        logger.recordEmergency(active: true)

        let files = try FileManager.default.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty)
        XCTAssertEqual(logger.makeReport().averageMotionScore, 0.4, accuracy: 0.001)
        XCTAssertEqual(logger.makeReport().averageDiscomfortScore, 8)
        XCTAssertEqual(logger.makeReport().emergencyCount, 1)
    }

    func testInMemorySamplesRespectConfiguredInterval() {
        let settings = TelemetrySettings(
            sessionLoggingEnabled: false,
            sessionSampleIntervalSeconds: 1,
            sessionLogRetentionDays: 14
        )
        let logger = SessionLogger(sessionsURL: temporaryDirectory(), telemetrySettings: settings)
        logger.start(gameName: "Example")

        logger.record(sample: sample(timestamp: 0, score: 0.2))
        logger.record(sample: sample(timestamp: 0.2, score: 0.9))
        logger.record(sample: sample(timestamp: 1.1, score: 0.6))

        let report = logger.makeReport()
        XCTAssertEqual(report.averageMotionScore, 0.4, accuracy: 0.001)
        XCTAssertEqual(report.peakMotionScore, 0.6, accuracy: 0.001)
    }

    func testRapidSessionsUseDistinctFiles() throws {
        let sessionsURL = temporaryDirectory()
        let logger = SessionLogger(sessionsURL: sessionsURL)

        logger.start(gameName: "First")
        logger.record(rating: DiscomfortRating(timestamp: 0, score: 2, context: .manual))
        logger.start(gameName: "Second")
        logger.record(rating: DiscomfortRating(timestamp: 0, score: 3, context: .manual))

        let files = try FileManager.default.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.pathExtension == "jsonl" }.count, 2)
    }

    private func sample(timestamp: TimeInterval, score: Float) -> SessionSample {
        SessionSample(
            timestamp: timestamp,
            gameProfileID: nil,
            motionScore: score,
            vignetteOpacity: 0.2,
            innerRadius: 0.8,
            visual: .zero,
            cadence: .stable,
            permissionState: .unknown
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
