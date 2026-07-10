import Foundation

enum AppConstants {
    static let appName = "SeaLegs"
    static let supportDirectoryName = "SeaLegs"
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.dawncrow.SeaLegs"
    }
    static let schemaVersion = 1
    static let supportedMacOS = "macOS 14+"
    static let privacySummary = "Frames, screenshots, audio, OCR, key strings, and raw mouse paths are never stored."
    static let onboardingCompletedKey = "SeaLegs.onboardingCompleted"
}
