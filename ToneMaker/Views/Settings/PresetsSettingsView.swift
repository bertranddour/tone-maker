import SwiftUI
import SwiftData

/// Preset management — list, rename, inspect, delete.
///
/// Creation and application happen in `TrainingConfigView`'s toolbar menu, where
/// presets are contextual. This view is the one place users go to curate the
/// full set.
struct PresetsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPreset.name) private var presets: [TrainingPreset]

    @State private var presetToDelete: TrainingPreset?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if presets.isEmpty {
                emptyState
            } else {
                presetList
            }
        }
        .confirmationDialog(
            "Delete Preset?",
            isPresented: $showDeleteConfirmation,
            presenting: presetToDelete
        ) { preset in
            Button("Delete", role: .destructive) {
                performDelete(preset)
            }
            Button("Cancel", role: .cancel) {
                presetToDelete = nil
            }
        } message: { preset in
            let count = preset.sessions?.count ?? 0
            if count > 0 {
                Text("'\(preset.name)' is applied to \(count) session\(count == 1 ? "" : "s"). Deleting it will not remove the sessions; they will simply lose their preset link.")
            } else {
                Text("Delete '\(preset.name)'? This cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Presets", systemImage: "slider.horizontal.3")
        } description: {
            Text("Save a training configuration as a preset from the Preset menu in any training session to reuse it later.")
        }
    }

    // MARK: - List

    private var presetList: some View {
        List {
            ForEach(presets) { preset in
                PresetRow(
                    preset: preset,
                    allNames: presets.filter { $0.id != preset.id }.map(\.name),
                    onDuplicate: { duplicate(preset) },
                    onDelete: { requestDelete(preset) }
                )
            }
        }
    }

    // MARK: - Actions

    private func requestDelete(_ preset: TrainingPreset) {
        presetToDelete = preset
        showDeleteConfirmation = true
    }

    private func performDelete(_ preset: TrainingPreset) {
        modelContext.delete(preset)
        presetToDelete = nil
    }

    private func duplicate(_ preset: TrainingPreset) {
        let copyName = uniqueName(preset.name, existing: presets.map(\.name))
        let copy = TrainingPreset(
            name: copyName,
            modelType: preset.modelType,
            architectureSize: preset.architectureSize,
            epochs: preset.epochs,
            learningRate: preset.learningRate,
            learningRateDecay: preset.learningRateDecay,
            batchSize: preset.batchSize,
            ny: preset.ny,
            seed: preset.seed,
            fitMRSTFT: preset.fitMRSTFT
        )
        modelContext.insert(copy)
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    @Bindable var preset: TrainingPreset
    let allNames: [String]
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @FocusState private var isRenaming: Bool
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            parameterGrid
                .padding(.top, 6)
        } label: {
            rowLabel
        }
        .contextMenu {
            RenameButton()
            Button("Duplicate", systemImage: "plus.square.on.square") {
                onDuplicate()
            }
            Divider()
            Button("Delete\u{2026}", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .renameAction { isRenaming = true }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    // MARK: - Label

    private var rowLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
                .imageScale(.medium)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Preset Name", text: nameBinding)
                    .focused($isRenaming)
                    .textFieldStyle(.plain)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(preset.modelType.rawValue)
                    Text("\u{2014}")
                    Text(preset.architectureSize.displayName)
                    Text("\u{2014}")
                    Text("\(preset.epochs)ep")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(preset.updatedAt, format: .relative(presentation: .numeric))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Parameter Grid

    private var parameterGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 4) {
            parameterRow("Learning Rate", String(format: "%.4f", preset.learningRate))
            parameterRow("LR Decay", String(format: "%.4f", preset.learningRateDecay))
            parameterRow("Batch Size", "\(preset.batchSize)")
            parameterRow("Ny", "\(preset.ny)")
            parameterRow("Seed", "\(preset.seed)")
            parameterRow("MR-STFT", preset.fitMRSTFT ? "On" : "Off")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func parameterRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .gridColumnAlignment(.leading)
            Text(value)
                .gridColumnAlignment(.leading)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Name Binding

    private var nameBinding: Binding<String> {
        Binding(
            get: { preset.name },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                preset.name = uniqueName(trimmed, existing: allNames)
                preset.updatedAt = Date()
            }
        )
    }
}
