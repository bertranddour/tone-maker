import SwiftUI
import SwiftData

/// Unified view for training progress and results.
///
/// Adapts layout based on session status: shows live metrics during training,
/// final results when complete.
struct TrainingDashboardView: View {
    @Bindable var session: TrainingSession
    @Environment(TrainingEngine.self) private var engine

    private let circleSize: CGFloat = 250

    private var isTraining: Bool {
        session.status == .training || session.status == .validating
    }

    private var esrValue: Double? {
        isTraining ? engine.currentESR : session.validationESR
    }

    private var progress: Double {
        if session.status == .completed { return 1.0 }
        let total = Double(max(session.epochs, 1))
        return Double(engine.currentEpoch) / total
    }

    private var rigName: String {
        session.metadata?.namName ?? session.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            epochProgressBar
                .padding(.top, 48)
                .padding(.bottom, 80)

            dashboardRow
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            actionButton

            Spacer()

            logSection
        }
        .padding()
        .navigationTitle(rigName)
    }

    // MARK: - Epoch Progress Bar

    private var epochProgressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)

            Text(isTraining
                 ? "Epoch \(engine.currentEpoch) / \(session.epochs)"
                 : "Epoch \(session.epochs) / \(session.epochs)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Dashboard Row

    private var dashboardRow: some View {
        HStack(spacing: 0) {
            esrCircle
            Spacer()
            architecturePill
            Spacer()
            statusCircle
        }
    }

    // MARK: - ESR Circle

    private var esrCircle: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.08))
                    .frame(width: circleSize, height: circleSize)

                if let esr = esrValue {
                    Text(String(format: "%.4f", esr))
                        .font(.system(.title, design: .monospaced, weight: .semibold))
                } else {
                    Text("--")
                        .font(.system(.title, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Text("ESR")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Architecture Pill

    private var architecturePill: some View {
        Text("\(session.modelType.rawValue) \(session.architectureSize.displayName)")
            .font(.callout.weight(.medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.secondary.opacity(0.08))
            .clipShape(Capsule())
    }

    // MARK: - Status Circle

    private var statusCircle: some View {
        VStack(spacing: 10) {
            ZStack {
                if isTraining {
                    trainingIndicator
                } else {
                    resultIndicator
                }
            }
            .frame(width: circleSize, height: circleSize)

            statusLabel
        }
    }

    private var trainingIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))

            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .symbolEffect(.breathe)
        }
    }

    @ViewBuilder
    private var resultIndicator: some View {
        let quality = session.validationESR.map { ESRQuality.from(esr: $0) }

        Circle()
            .fill((quality?.color ?? statusColor).opacity(0.1))

        Image(systemName: quality?.symbolName ?? session.status.symbolName)
            .font(.system(size: 48))
            .foregroundStyle(quality?.color ?? statusColor)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isTraining {
            Text("Training")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let esr = session.validationESR {
            let quality = ESRQuality.from(esr: esr)
            Text(quality.comment)
                .font(.caption.weight(.medium))
                .foregroundStyle(quality.color)
        } else {
            Text(session.status.displayName)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        default: .orange
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if isTraining {
            Button("Cancel Training", role: .destructive) {
                engine.cancelTraining(session: session)
            }
        } else if session.status == .completed {
            let captureCount = (session.captures ?? []).count
            Label(
                captureCount > 0
                    ? "\(captureCount) capture\(captureCount == 1 ? "" : "s") saved to Library"
                    : "Completed",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .font(.callout)
        }
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Training Log")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            LogOutputView(text: isTraining ? engine.logOutput : (session.trainingLog ?? ""))
                .frame(height: 300)
        }
    }
}
