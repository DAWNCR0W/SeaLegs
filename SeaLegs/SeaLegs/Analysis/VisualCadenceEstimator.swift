import Foundation

final class VisualCadenceEstimator {
    private struct Sample {
        let timestamp: TimeInterval
        let repeated: Bool
    }

    private let maxSamples: Int
    private let windowSeconds: TimeInterval
    private var samples: [Sample] = []

    init(maxSamples: Int = 120, windowSeconds: TimeInterval = 5) {
        self.maxSamples = maxSamples
        self.windowSeconds = windowSeconds
    }

    func consume(timestamp: TimeInterval, repeatedFrameProbability: Float) -> VisualCadenceMetrics {
        samples.append(Sample(timestamp: timestamp, repeated: repeatedFrameProbability >= 0.5))
        trim(now: timestamp)
        return metrics()
    }

    func reset() {
        samples.removeAll()
    }

    private func trim(now: TimeInterval) {
        samples.removeAll { now - $0.timestamp > windowSeconds }
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    private func metrics() -> VisualCadenceMetrics {
        guard samples.count >= 2 else {
            return .stable
        }

        let intervals = zip(samples.dropFirst(), samples).map { current, previous in
            Float(max(0, current.timestamp - previous.timestamp) * 1000)
        }.sorted()
        let mean = intervals.reduce(0, +) / Float(intervals.count)
        let median = intervals[intervals.count / 2]
        let p95Index = min(intervals.count - 1, Int(Float(intervals.count - 1) * 0.95))
        let p95 = intervals[p95Index]
        let repeatedRatio = Float(samples.filter(\.repeated).count) / Float(samples.count)
        let jitter = clamp(((p95 / max(median, 0.001)) - 1) / 1.5)
        let cadenceRisk = clamp(0.65 * jitter + 0.35 * repeatedRatio)

        return VisualCadenceMetrics(
            meanFrameIntervalMs: mean,
            p95FrameIntervalMs: p95,
            jitterScore: jitter,
            repeatedFrameRatio: repeatedRatio,
            visualCadenceRisk: cadenceRisk
        )
    }
}
