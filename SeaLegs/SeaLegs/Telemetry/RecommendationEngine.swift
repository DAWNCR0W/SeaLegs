import Foundation

final class RecommendationEngine {
    func recommendations(samples: [SessionSample], ratings: [DiscomfortRating], emergencyCount: Int) -> [Recommendation] {
        guard !samples.isEmpty else {
            return [
                Recommendation(
                    title: "In-game settings checklist",
                    detail: "Turn down or disable Motion Blur, Camera Shake, Head Bob, Chromatic Aberration, Film Grain, and Sprint FOV Effect."
                )
            ]
        }

        let avgRotation = average(samples.map(\.visual.rotationProxy))
        let avgRadial = average(samples.map(\.visual.radialExpansion))
        let avgVertical = average(samples.map(\.visual.verticalMotion))
        let avgCadence = average(samples.map(\.cadence.visualCadenceRisk))
        var output: [Recommendation] = []

        if avgRotation > 0.45 {
            output.append(Recommendation(title: "Reduce camera rotation", detail: "Camera rotation was strong. Try lowering in-game mouse sensitivity or turn speed."))
        }
        if avgRadial > 0.40 {
            output.append(Recommendation(title: "Reduce sprint and FOV effects", detail: "Fast forward-motion sections were frequent. Try lowering sprint FOV effect, motion blur, and camera shake."))
        }
        if avgVertical > 0.35 {
            output.append(Recommendation(title: "Reduce vertical bobbing", detail: "Vertical motion was strong. Turning off head bob or view bob is recommended."))
        }
        if avgCadence > 0.35 {
            output.append(Recommendation(title: "Improve frame stability", detail: "Visual stability was low. Try lowering graphics settings or setting a stable FPS cap."))
        }
        if emergencyCount >= 2 || ratings.contains(where: { $0.score >= 10 }) {
            output.append(Recommendation(title: "Increase profile strength", detail: "Emergency mode or high discomfort was recorded. Consider raising the current profile's vignette max strength by one step."))
        }
        if output.isEmpty {
            output.append(Recommendation(title: "Keep current settings", detail: "High-risk signals were limited. Keeping the current comfort profile is reasonable."))
        }
        return output
    }

    private func average(_ values: [Float]) -> Float {
        guard !values.isEmpty else {
            return 0
        }
        return values.reduce(0, +) / Float(values.count)
    }
}
