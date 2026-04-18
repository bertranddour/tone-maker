import SwiftUI
import SwiftData

/// Compact per-item status list shown inside `TrainingDashboardView` when a session
/// has more than one batch item.
struct BatchItemListView: View {
    @Bindable var session: TrainingSession
    @Environment(TrainingEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Captures")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                let items = session.sortedBatchItems
                ForEach(items) { item in
                    BatchItemRow(
                        item: item,
                        index: item.order,
                        isActive: engine.currentBatchItemID == item.id
                    ) {
                        engine.retryBatchItem(item, modelContext: modelContext)
                    } onCancel: {
                        engine.cancelBatchItem(item)
                    }
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
            .background(.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Row

private struct BatchItemRow: View {
    @Bindable var item: BatchItem
    let index: Int
    let isActive: Bool
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 24)

            Image(systemName: item.status.symbolName)
                .foregroundStyle(item.status.tintColor)
                .imageScale(.medium)
                .frame(width: 20)
                .symbolEffect(.pulse, options: .repeating, isActive: item.status == .running)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout)
                    .lineLimit(1)
                if let error = item.errorMessage, item.status == .failed {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text(item.outputFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let esr = item.validationESR {
                Text(String(format: "%.4f", esr))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ESRQuality.from(esr: esr).color)
            }

            rowActionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    @ViewBuilder
    private var rowActionButton: some View {
        switch item.status {
        case .running:
            Button("Cancel", systemImage: "stop.circle") { onCancel() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        case .failed, .cancelled, .skipped:
            Button("Retry", systemImage: "arrow.clockwise") { onRetry() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        case .pending:
            Button("Skip", systemImage: "forward.end") { onCancel() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
        case .completed:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .imageScale(.small)
        }
    }
}
