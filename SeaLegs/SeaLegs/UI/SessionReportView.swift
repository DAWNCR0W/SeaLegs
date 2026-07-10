import SwiftUI

struct SessionReportWindowView: View {
    @ObservedObject var state: AppState

    var body: some View {
        SessionReportView(report: state.lastSessionReport, language: state.language)
    }
}

struct SessionReportView: View {
    let report: SessionReport?
    let language: AppLanguage

    private var localizer: AppLocalizer {
        AppLocalizer(language: language)
    }

    var body: some View {
        Group {
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(report.gameName)
                            .font(.title.bold())
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                            GridRow {
                                Text(localizer.string("Duration"))
                                Text("\(Int(report.durationSeconds))s")
                            }
                            GridRow {
                                Text(localizer.string("Average Motion"))
                                Text(String(format: "%.2f", report.averageMotionScore))
                            }
                            GridRow {
                                Text(localizer.string("Peak Motion"))
                                Text(String(format: "%.2f", report.peakMotionScore))
                            }
                            GridRow {
                                Text(localizer.string("Average Discomfort"))
                                Text(report.averageDiscomfortScore.map { String(format: "%.1f", $0) } ?? "-")
                            }
                            GridRow {
                                Text(localizer.string("Emergency Count"))
                                Text("\(report.emergencyCount)")
                            }
                        }
                        Text(localizer.string("Recommendations"))
                            .font(.headline)
                        ForEach(report.recommendations) { recommendation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizer.string(recommendation.title))
                                    .font(.subheadline.bold())
                                Text(localizer.string(recommendation.detail))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !report.highRiskMoments.isEmpty {
                            Text(localizer.string("High Risk Moments"))
                                .font(.headline)
                            ForEach(report.highRiskMoments) { moment in
                                Text("\(Int(moment.timestamp))s · \(localizer.highRiskReason(moment.reason)) · \(String(format: "%.2f", moment.motionScore))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(localizer.string("No session report yet."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
