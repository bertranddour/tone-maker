import SwiftUI
import Charts

/// Renders a training run's per-epoch validation-loss curve.
///
/// Uses a log-scale y-axis because loss values typically span several orders of
/// magnitude over a training run — linear scaling flattens all the interesting
/// decay into an unreadable bottom band. Catmull-Rom interpolation smooths the
/// line between sparse samples, and a light area gradient under the line
/// matches the visual weight of Apple's first-party charts.
struct LossChartView: View {
    let metrics: [TrainingMetric]

    @State private var selectedEpoch: Int?

    private var selectedMetric: TrainingMetric? {
        guard let selectedEpoch else { return nil }
        return metrics.min(by: { abs($0.epoch - selectedEpoch) < abs($1.epoch - selectedEpoch) })
    }

    var body: some View {
        if metrics.isEmpty {
            ContentUnavailableView {
                Label("No Loss Data Yet", systemImage: "chart.xyaxis.line")
            } description: {
                Text("The validation loss curve will appear here as epochs complete.")
            }
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(metrics, id: \.epoch) { metric in
                AreaMark(
                    x: .value("Epoch", metric.epoch),
                    y: .value("Val Loss", metric.valLoss)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Epoch", metric.epoch),
                    y: .value("Val Loss", metric.valLoss)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if let selectedMetric {
                RuleMark(x: .value("Epoch", selectedMetric.epoch))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit, y: .disabled)) {
                        annotation(for: selectedMetric)
                    }

                PointMark(
                    x: .value("Epoch", selectedMetric.epoch),
                    y: .value("Val Loss", selectedMetric.valLoss)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(80)
            }
        }
        .chartYScale(type: .log)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let loss = value.as(Double.self) {
                        Text(formatLoss(loss))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let epoch = value.as(Int.self) {
                        Text("\(epoch)")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .chartXAxisLabel("Epoch", alignment: .center)
        .chartYAxisLabel("Validation Loss", position: .leading)
        .chartXSelection(value: $selectedEpoch)
        .accessibilityLabel("Validation loss curve")
        .accessibilityValue(accessibilitySummary)
    }

    @ViewBuilder
    private func annotation(for metric: TrainingMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Epoch \(metric.epoch)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatLoss(metric.valLoss))
                .font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func formatLoss(_ value: Double) -> String {
        if value >= 0.01 {
            return String(format: "%.4f", value)
        }
        return String(format: "%.2e", value)
    }

    private var accessibilitySummary: String {
        guard let first = metrics.first, let last = metrics.last else { return "" }
        let startLoss = formatLoss(first.valLoss)
        let endLoss = formatLoss(last.valLoss)
        return "\(metrics.count) samples from epoch \(first.epoch) (\(startLoss)) to epoch \(last.epoch) (\(endLoss))"
    }
}
