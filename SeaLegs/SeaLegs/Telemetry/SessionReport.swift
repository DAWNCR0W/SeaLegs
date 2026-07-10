import Foundation

enum RatingContext: String, Codable, CaseIterable, Identifiable {
    case manual
    case periodicPrompt
    case sessionEnd
    case emergency

    var id: String { rawValue }
}

struct DiscomfortRating: Codable, Equatable {
    let timestamp: TimeInterval
    let score: Int
    let context: RatingContext
}

struct HighRiskMoment: Codable, Equatable, Identifiable {
    var id = UUID()
    let timestamp: TimeInterval
    let reason: String
    let motionScore: Float
}

struct Recommendation: Codable, Equatable, Identifiable {
    var id = UUID()
    let title: String
    let detail: String
}

struct SessionReport: Codable, Equatable {
    let gameName: String
    let durationSeconds: TimeInterval
    let averageMotionScore: Float
    let peakMotionScore: Float
    let averageDiscomfortScore: Float?
    let peakDiscomfortScore: Int?
    let emergencyCount: Int
    let highRiskMoments: [HighRiskMoment]
    let recommendations: [Recommendation]
}

enum SessionEvent: Codable, Equatable {
    case sample(SessionSample)
    case rating(DiscomfortRating)
    case emergency(timestamp: TimeInterval, active: Bool)

    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    enum EventType: String, Codable {
        case sample
        case rating
        case emergency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EventType.self, forKey: .type) {
        case .sample:
            self = .sample(try container.decode(SessionSample.self, forKey: .payload))
        case .rating:
            self = .rating(try container.decode(DiscomfortRating.self, forKey: .payload))
        case .emergency:
            let payload = try container.decode(EmergencyPayload.self, forKey: .payload)
            self = .emergency(timestamp: payload.timestamp, active: payload.active)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sample(let sample):
            try container.encode(EventType.sample, forKey: .type)
            try container.encode(sample, forKey: .payload)
        case .rating(let rating):
            try container.encode(EventType.rating, forKey: .type)
            try container.encode(rating, forKey: .payload)
        case .emergency(let timestamp, let active):
            try container.encode(EventType.emergency, forKey: .type)
            try container.encode(EmergencyPayload(timestamp: timestamp, active: active), forKey: .payload)
        }
    }
}

struct SessionSample: Codable, Equatable {
    let timestamp: TimeInterval
    let gameProfileID: UUID?
    let motionScore: Float
    let vignetteOpacity: Float
    let innerRadius: Float
    let visual: VisualMotionMetrics
    let cadence: VisualCadenceMetrics
    let permissionState: PermissionState
}

private struct EmergencyPayload: Codable, Equatable {
    let timestamp: TimeInterval
    let active: Bool
}
