import Foundation

enum CaptureResultGate {
    static func shouldAccept(
        resultGeneration: UUID,
        activeGeneration: UUID,
        mode: ComfortMode,
        overlayEnabled: Bool,
        activeProfileID: UUID?,
        sessionProfileID: UUID?
    ) -> Bool {
        resultGeneration == activeGeneration
            && mode == .adaptive
            && overlayEnabled
            && activeProfileID != nil
            && activeProfileID == sessionProfileID
    }
}
