import Foundation
import OSLog

final class SessionLogger {
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "SessionLogger")
    private let fileManager: FileManager
    private let sessionsURL: URL
    private let recommendationEngine: RecommendationEngine
    private var telemetrySettings: TelemetrySettings
    private var sessionURL: URL?
    private var startedAt = Date()
    private var lastRecordedSampleTimestamp: TimeInterval?
    private var samples: [SessionSample] = []
    private var ratings: [DiscomfortRating] = []
    private var emergencyCount = 0
    private var gameName = "None"

    init(
        sessionsURL: URL,
        recommendationEngine: RecommendationEngine = RecommendationEngine(),
        telemetrySettings: TelemetrySettings = .standard,
        fileManager: FileManager = .default
    ) {
        self.sessionsURL = sessionsURL
        self.recommendationEngine = recommendationEngine
        self.telemetrySettings = telemetrySettings
        self.fileManager = fileManager
    }

    func configure(settings: TelemetrySettings) {
        telemetrySettings = settings
    }

    func start(gameName: String) {
        self.gameName = gameName
        startedAt = Date()
        lastRecordedSampleTimestamp = nil
        samples.removeAll()
        ratings.removeAll()
        emergencyCount = 0
        try? fileManager.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        pruneStoredSessions()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let name = formatter.string(from: startedAt).replacingOccurrences(of: ":", with: "-")
        let suffix = UUID().uuidString.prefix(8)
        sessionURL = sessionsURL.appendingPathComponent("\(name)-\(suffix).jsonl")
    }

    func record(sample: SessionSample) {
        guard shouldRecord(sample: sample) else {
            return
        }
        lastRecordedSampleTimestamp = sample.timestamp
        samples.append(sample)
        guard telemetrySettings.sessionLoggingEnabled else {
            return
        }
        append(.sample(sample))
    }

    func record(rating: DiscomfortRating) {
        ratings.append(rating)
        if telemetrySettings.sessionLoggingEnabled {
            append(.rating(rating))
        }
    }

    func recordEmergency(active: Bool) {
        if active {
            emergencyCount += 1
        }
        if telemetrySettings.sessionLoggingEnabled {
            append(.emergency(timestamp: Date().timeIntervalSince(startedAt), active: active))
        }
    }

    func makeReport() -> SessionReport {
        let duration = Date().timeIntervalSince(startedAt)
        let averageMotion = average(samples.map(\.motionScore))
        let peakMotion = samples.map(\.motionScore).max() ?? 0
        let ratingScores = ratings.map(\.score)
        let highRisk = highRiskMoments()
        return SessionReport(
            gameName: gameName,
            durationSeconds: duration,
            averageMotionScore: averageMotion,
            peakMotionScore: peakMotion,
            averageDiscomfortScore: ratingScores.isEmpty ? nil : Float(ratingScores.reduce(0, +)) / Float(ratingScores.count),
            peakDiscomfortScore: ratingScores.max(),
            emergencyCount: emergencyCount,
            highRiskMoments: highRisk,
            recommendations: recommendationEngine.recommendations(samples: samples, ratings: ratings, emergencyCount: emergencyCount)
        )
    }

    func flush() {}

    func elapsedTimestamp(now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince(startedAt)
    }

    func deleteStoredSessions() throws {
        guard fileManager.fileExists(atPath: sessionsURL.path) else {
            return
        }
        let urls = try fileManager.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for url in urls where url.pathExtension == "jsonl" {
            try fileManager.removeItem(at: url)
        }
    }

    private func append(_ event: SessionEvent) {
        guard let sessionURL else {
            return
        }
        do {
            let data = try JSONEncoder.pretty.encode(event)
            guard var line = String(data: data, encoding: .utf8) else {
                return
            }
            line = line.replacingOccurrences(of: "\n", with: "") + "\n"
            if fileManager.fileExists(atPath: sessionURL.path) {
                let handle = try FileHandle(forWritingTo: sessionURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try Data(line.utf8).write(to: sessionURL)
            }
        } catch {
            logger.error("Failed to append session event: \(error.localizedDescription)")
        }
    }

    private func shouldRecord(sample: SessionSample) -> Bool {
        guard let lastRecordedSampleTimestamp else {
            return true
        }
        return sample.timestamp - lastRecordedSampleTimestamp >= telemetrySettings.sessionSampleIntervalSeconds
    }

    private func pruneStoredSessions(now: Date = Date()) {
        guard telemetrySettings.sessionLogRetentionDays > 0,
              let urls = try? fileManager.contentsOfDirectory(
                at: sessionsURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let cutoff = now.addingTimeInterval(-TimeInterval(telemetrySettings.sessionLogRetentionDays) * 24 * 60 * 60)
        for url in urls where url.pathExtension == "jsonl" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantFuture
            if modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func highRiskMoments() -> [HighRiskMoment] {
        var moments = samples
            .filter { $0.motionScore >= 0.75 }
            .map {
                HighRiskMoment(
                    timestamp: $0.timestamp,
                    reason: "Motion score stayed high",
                    motionScore: $0.motionScore
                )
            }

        for rating in ratings where rating.score >= 10 {
            moments.append(
                HighRiskMoment(
                    timestamp: rating.timestamp,
                    reason: "User discomfort score reached \(rating.score)",
                    motionScore: samples.last(where: { $0.timestamp <= rating.timestamp })?.motionScore ?? 0
                )
            )
        }
        return Array(moments.sorted { $0.timestamp < $1.timestamp }.prefix(20))
    }

    private func average(_ values: [Float]) -> Float {
        guard !values.isEmpty else {
            return 0
        }
        return values.reduce(0, +) / Float(values.count)
    }
}
