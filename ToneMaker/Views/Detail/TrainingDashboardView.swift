import SwiftUI
import SwiftData

/// Unified view for training progress and results.
///
/// Adapts layout based on session status. Shows live metrics during training
/// (current item's ESR + epoch progress), final results when complete, and a
/// queue indicator when the session is waiting its turn.
struct TrainingDashboardView: View {
    @Bindable var session: TrainingSession
    @Environment(TrainingEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext

    private let tileSize: CGFloat = 250
    private let tileCornerRadius: CGFloat = 28
    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
    }

    // MARK: - State Derivations

    private var isTraining: Bool {
        session.status == .training || session.status == .validating
    }

    private var isQueued: Bool {
        session.status == .queued
    }

    /// The batch item currently being trained (only meaningful while `isTraining`).
    private var currentItem: BatchItem? {
        guard let id = engine.currentBatchItemID else { return nil }
        return session.sortedBatchItems.first { $0.id == id }
    }

    /// The ESR value to display in the headline circle.
    /// Live item ESR while training; best ESR from completed items after.
    private var esrValue: Double? {
        if isTraining, let item = currentItem, let esr = item.validationESR { return esr }
        return session.bestValidationESR
    }

    private var progress: Double {
        if session.status == .completed { return 1.0 }
        let total = Double(max(session.epochs, 1))
        return Double(engine.currentEpoch) / total
    }

    private var rigName: String {
        session.metadata?.namName ?? session.displayName
    }

    private var currentItemIndex: Int? {
        guard let id = engine.currentBatchItemID else { return nil }
        return session.sortedBatchItems.firstIndex { $0.id == id }
    }

    private var failedItems: [BatchItem] {
        session.sortedBatchItems.filter { $0.status == .failed || $0.status == .cancelled }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            epochProgressBar
                .padding(.top, 48)
                .padding(.bottom, 24)

            if session.isBatchTraining {
                batchProgressStrip
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            } else {
                Spacer().frame(height: 24)
            }

            dashboardRow
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            actionArea

            if session.isBatchTraining {
                BatchItemListView(session: session)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
            }

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

            Text(progressLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var progressLabel: String {
        if isTraining {
            let epochText = "Epoch \(engine.currentEpoch) / \(session.epochs)"
            if session.isBatchTraining, let idx = currentItemIndex {
                let total = session.sortedBatchItems.count
                return "Item \(idx + 1) of \(total)  \u{00B7}  \(epochText)"
            }
            return epochText
        }
        return "Epoch \(session.epochs) / \(session.epochs)"
    }

    // MARK: - Batch Progress Strip

    private var batchProgressStrip: some View {
        HStack(spacing: 6) {
            ForEach(session.sortedBatchItems) { item in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(stripColor(for: item))
                    .frame(height: 8)
                    .overlay {
                        if engine.currentBatchItemID == item.id {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 1)
                        }
                    }
                    .help(item.displayName)
            }
        }
    }

    private func stripColor(for item: BatchItem) -> Color {
        switch item.status {
        case .pending: return .secondary.opacity(0.2)
        case .running: return .orange.opacity(0.8)
        case .completed: return .green.opacity(0.8)
        case .failed: return .red.opacity(0.8)
        case .cancelled, .skipped: return .secondary.opacity(0.4)
        }
    }

    // MARK: - Dashboard Row

    private var dashboardRow: some View {
        HStack(spacing: 0) {
            esrTile
            Spacer()
            architecturePill
            Spacer()
            statusTile
        }
    }

    // MARK: - ESR Tile

    private var esrTile: some View {
        VStack(spacing: 10) {
            ZStack {
                tileShape
                    .fill(.secondary.opacity(0.08))
                    .frame(width: tileSize, height: tileSize)

                if let esr = esrValue {
                    Text(String(format: "%.4f", esr))
                        .font(.system(.title, design: .monospaced, weight: .semibold))
                } else {
                    Text("--")
                        .font(.system(.title, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Text(esrCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var esrCaption: String {
        if isTraining, currentItem != nil, session.isBatchTraining {
            return "ESR (current item)"
        }
        if session.isBatchTraining, esrValue != nil {
            return "Best ESR"
        }
        return "ESR"
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

    // MARK: - Status Tile

    private var statusTile: some View {
        VStack(spacing: 10) {
            ZStack {
                if isTraining {
                    trainingIndicator
                } else if isQueued {
                    queuedIndicator
                } else {
                    resultIndicator
                }
            }
            .frame(width: tileSize, height: tileSize)

            statusLabel
        }
    }

    private var trainingIndicator: some View {
        ZStack {
            tileShape.fill(Color.orange.opacity(0.1))
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .symbolEffect(.breathe)
        }
    }

    private var queuedIndicator: some View {
        ZStack {
            tileShape.fill(Color.orange.opacity(0.1))
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var resultIndicator: some View {
        let quality = session.bestValidationESR.map { ESRQuality.from(esr: $0) }

        tileShape
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
        } else if isQueued {
            Text("Queued")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let esr = session.bestValidationESR {
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

    // MARK: - Action Area

    @ViewBuilder
    private var actionArea: some View {
        if isTraining {
            Button("Cancel Training", role: .destructive) {
                engine.cancelTraining(session: session)
            }
        } else if isQueued {
            Button("Remove from Queue", role: .destructive) {
                engine.cancelTraining(session: session)
            }
        } else if session.status == .completed || session.status == .failed || session.status == .cancelled {
            completedActions
        }
    }

    @ViewBuilder
    private var completedActions: some View {
        let captureCount = (session.captures ?? []).count
        VStack(spacing: 10) {
            if captureCount > 0 {
                Label(
                    "\(captureCount) capture\(captureCount == 1 ? "" : "s") saved to Library",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
                .font(.callout)
            } else {
                Label(session.status.displayName, systemImage: session.status.symbolName)
                    .foregroundStyle(statusColor)
                    .font(.callout)
            }

            if !failedItems.isEmpty {
                Button(retryButtonLabel, systemImage: "arrow.clockwise") {
                    engine.retryFailedItems(in: session, modelContext: modelContext)
                }
            }
        }
    }

    private var retryButtonLabel: String {
        let count = failedItems.count
        return count == 1 ? "Retry 1 Failed Item" : "Retry \(count) Failed Items"
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Training Log")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            LogOutputView(text: isTraining ? engine.logOutput : (session.trainingLog ?? ""))
                .frame(height: 240)
        }
    }
}
