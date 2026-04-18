import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main configuration form for a training session.
///
/// Combines audio file selection, model configuration (with inline metadata),
/// training parameters, and advanced options in a single grouped form. Output
/// files are represented as `BatchItem`s so per-capture name, validation,
/// status, and result tracking happen independently.
struct TrainingConfigView: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var modelContext
    @Environment(TrainingEngine.self) private var engine
    @Environment(\.openSettings) private var openSettings

    @AppStorage("defaultModeledBy") private var defaultModeledBy = ""
    @AppStorage("defaultInputLevelDBu") private var defaultInputLevelDBu: Double = 0.0
    @AppStorage("defaultOutputLevelDBu") private var defaultOutputLevelDBu: Double = 0.0
    @AppStorage("selectedSettingsTab") private var selectedSettingsTab = SettingsTab.environment

    @Query(sort: \TrainingPreset.name) private var presets: [TrainingPreset]

    @State private var inputValidation: InputValidationResult?
    @State private var outputValidations: [UUID: InputValidationResult] = [:]
    @State private var showSavePreset = false
    @State private var presetName = ""

    var body: some View {
        Form {
            audioFilesSection
            if !session.sortedBatchItems.isEmpty {
                capturesSection
            }
            modelSection
            trainingSection
            advancedOptionsSection
        }
        .formStyle(.grouped)
        .navigationTitle(session.metadata?.namName ?? session.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(primaryActionLabel, systemImage: primaryActionSymbol) {
                    startTraining()
                }
                .disabled(!canStartTraining)
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Menu("Preset", systemImage: "slider.horizontal.3") {
                    Button("Save Current as Preset\u{2026}", systemImage: "plus") {
                        showSavePreset = true
                    }
                    if !presets.isEmpty {
                        Divider()
                        Menu("Apply Preset") {
                            ForEach(presets) { preset in
                                Button(preset.name) {
                                    preset.apply(to: session)
                                }
                            }
                        }
                        Menu("Update Preset from Current") {
                            ForEach(presets) { preset in
                                Button(preset.name) {
                                    preset.update(from: session)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Manage Presets\u{2026}", systemImage: "gearshape") {
                        selectedSettingsTab = .presets
                        openSettings()
                    }
                }
            }
        }
        .alert("Save Preset", isPresented: $showSavePreset) {
            TextField("Preset Name", text: $presetName)
            Button("Save") { savePreset() }
            Button("Cancel", role: .cancel) { presetName = "" }
        } message: {
            Text("Enter a name for this training configuration preset.")
        }
        .onChange(of: session.modelType) { _, newType in
            session.learningRate = Defaults.learningRate(for: newType)
        }
    }

    // MARK: - Audio Files Section

    private var audioFilesSection: some View {
        Section("Audio Files") {
            HStack(alignment: .top, spacing: 12) {
                AudioDropZone(
                    title: "Reference Audio",
                    allowsMultipleSelection: false,
                    selectedNames: session.inputFileName.map { [$0] } ?? [],
                    onSelection: handleInputSelection
                )

                AudioDropZone(
                    title: "Output Audio (Reamped)",
                    allowsMultipleSelection: true,
                    selectedNames: session.sortedBatchItems.map(\.outputFileName),
                    onSelection: handleOutputSelection
                )
            }

            if let validation = inputValidation {
                ValidationBannerView(
                    warnings: validation.warnings,
                    errors: validation.errors
                )
            }

            if hasOutputValidationIssues {
                ValidationBannerView(
                    warnings: allOutputWarnings,
                    errors: allOutputErrors
                )
            }
        }
    }

    // MARK: - Captures Section (per-item names)

    private var capturesSection: some View {
        Section("Captures to Produce (\(session.sortedBatchItems.count))") {
            ForEach(session.sortedBatchItems) { item in
                BatchItemConfigRow(
                    item: item,
                    validation: outputValidations[item.id]
                ) {
                    removeItem(item)
                }
            }
        }
    }

    // MARK: - Model Section (Inline Metadata)

    private var modelSection: some View {
        Section("Model") {
            TextField("Rig Name", text: metadataBinding(for: \.namName))
            TextField("Brand", text: metadataBinding(for: \.gearMake))
            TextField("Model", text: metadataBinding(for: \.gearModel))

            Picker("Type", selection: metadataGearTypeBinding) {
                Text("Not Set").tag(GearType?.none)
                ForEach(GearType.allCases) { type in
                    Text(type.displayName).tag(GearType?.some(type))
                }
            }

            Picker("Gain", selection: metadataToneTypeBinding) {
                ForEach(ToneType.allCases) { type in
                    Text(type.displayName).tag(ToneType?.some(type))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        Section("Training") {
            Picker("Epochs", selection: $session.epochs) {
                ForEach([100, 200, 400, 800, 1000], id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Advanced Options

    private var advancedOptionsSection: some View {
        Section("Advanced") {
            TextField("Learning Rate", value: $session.learningRate, format: .number)
            TextField("Batch Size", value: $session.batchSize, format: .number)
            TextField("LR Decay", value: $session.learningRateDecay, format: .number)
            TextField("Output Size (ny)", value: $session.ny, format: .number)
            TextField("Seed", value: $session.seed, format: .number)
            TextField("Latency Override (samples)", value: $session.latencyOverride, format: .number)
            TextField("ESR Threshold", value: $session.esrThreshold, format: .number)
            Toggle("MRSTFT Loss", isOn: $session.fitMRSTFT)
            Toggle("Save ESR Plot", isOn: $session.savePlot)
            Toggle("Ignore Data Checks", isOn: $session.ignoreChecks)
        }
    }

    // MARK: - Metadata Bindings

    private func metadataBinding(for keyPath: ReferenceWritableKeyPath<ModelMetadata, String?>) -> Binding<String> {
        Binding(
            get: {
                ensureMetadata()
                return session.metadata?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                ensureMetadata()
                session.metadata?[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var metadataGearTypeBinding: Binding<GearType?> {
        Binding(
            get: {
                ensureMetadata()
                return session.metadata?.gearType
            },
            set: { newValue in
                ensureMetadata()
                session.metadata?.gearType = newValue
            }
        )
    }

    private var metadataToneTypeBinding: Binding<ToneType?> {
        Binding(
            get: {
                ensureMetadata()
                return session.metadata?.toneType
            },
            set: { newValue in
                ensureMetadata()
                session.metadata?.toneType = newValue
            }
        )
    }

    // MARK: - Computed

    private var primaryActionLabel: String {
        engine.isTraining ? "Add to Queue" : "Train"
    }

    private var primaryActionSymbol: String {
        engine.isTraining ? "plus.circle" : "play.fill"
    }

    private var canStartTraining: Bool {
        session.inputFileBookmark != nil
            && !session.sortedBatchItems.isEmpty
            && (inputValidation?.isValid ?? true)
            && !hasOutputValidationErrors
    }

    private var hasOutputValidationIssues: Bool {
        outputValidations.values.contains { !$0.errors.isEmpty || !$0.warnings.isEmpty }
    }

    private var hasOutputValidationErrors: Bool {
        outputValidations.values.contains { !$0.errors.isEmpty }
    }

    private var allOutputWarnings: [String] {
        session.sortedBatchItems.flatMap { item in
            (outputValidations[item.id]?.warnings ?? []).map { "\(item.outputFileName): \($0)" }
        }
    }

    private var allOutputErrors: [String] {
        session.sortedBatchItems.flatMap { item in
            (outputValidations[item.id]?.errors ?? []).map { "\(item.outputFileName): \($0)" }
        }
    }

    // MARK: - Actions

    private func handleInputSelection(_ urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        session.inputFileName = url.lastPathComponent
        session.inputFileBookmark = try? FileBookmark.create(for: url)
        inputValidation = InputFileValidator.validateInput(at: url)

        for existing in (session.persistedAudioFiles ?? []) where existing.role == .input {
            modelContext.delete(existing)
        }
        if let data = try? Data(contentsOf: url) {
            let persisted = PersistedAudioFile(
                fileName: url.lastPathComponent,
                role: .input,
                fileData: data
            )
            modelContext.insert(persisted)
            if session.persistedAudioFiles == nil { session.persistedAudioFiles = [] }
            session.persistedAudioFiles?.append(persisted)
        }

        if let inputInfo = inputValidation?.wavInfo {
            revalidateOutputFiles(against: inputInfo)
        }
    }

    private func handleOutputSelection(_ urls: [URL]) {
        let existingNames = Set(session.sortedBatchItems.map { $0.outputFileName.lowercased() })
        let defaultName = session.metadata?.namName
        var nextOrder = (session.sortedBatchItems.last?.order ?? -1) + 1

        for url in urls where !existingNames.contains(url.lastPathComponent.lowercased()) {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let bookmark = try? FileBookmark.create(for: url) else { continue }
            let derivedName = url.deletingPathExtension().lastPathComponent

            let item = BatchItem(
                order: nextOrder,
                outputFileName: url.lastPathComponent,
                captureName: (defaultName?.isEmpty == false ? defaultName! : derivedName)
            )
            item.outputFileBookmark = bookmark
            item.session = session

            if let data = try? Data(contentsOf: url) {
                let persisted = PersistedAudioFile(
                    fileName: url.lastPathComponent,
                    role: .output,
                    fileData: data
                )
                modelContext.insert(persisted)
                item.persistedOutputFile = persisted
            }

            modelContext.insert(item)
            session.batchItems = (session.batchItems ?? []) + [item]

            if let inputInfo = inputValidation?.wavInfo {
                outputValidations[item.id] = InputFileValidator.validateOutput(at: url, against: inputInfo)
            }

            nextOrder += 1
        }

        if let first = session.sortedBatchItems.first?.outputFileName {
            let derived = first.replacingOccurrences(of: ".wav", with: "", options: .caseInsensitive)
            let metadata = ensureMetadata()
            if metadata.namName == nil || metadata.namName?.isEmpty == true {
                metadata.namName = derived
            }
        }
    }

    private func revalidateOutputFiles(against inputInfo: WAVHeaderReader.WAVInfo) {
        outputValidations = [:]
        for item in session.sortedBatchItems {
            guard let bookmark = item.outputFileBookmark,
                  let url = FileBookmark.resolveAndAccess(bookmark) else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            outputValidations[item.id] = InputFileValidator.validateOutput(at: url, against: inputInfo)
        }
    }

    private func removeItem(_ item: BatchItem) {
        outputValidations.removeValue(forKey: item.id)
        modelContext.delete(item)
        // Reindex remaining items so order stays dense
        var order = 0
        for remaining in session.sortedBatchItems where remaining.id != item.id {
            remaining.order = order
            order += 1
        }
    }

    @discardableResult
    private func ensureMetadata() -> ModelMetadata {
        if let existing = session.metadata { return existing }
        let metadata = ModelMetadata()
        if !defaultModeledBy.isEmpty {
            metadata.modeledBy = defaultModeledBy
        }
        if defaultInputLevelDBu != 0.0 {
            metadata.inputLevelDBu = defaultInputLevelDBu
        }
        if defaultOutputLevelDBu != 0.0 {
            metadata.outputLevelDBu = defaultOutputLevelDBu
        }
        modelContext.insert(metadata)
        session.metadata = metadata
        return metadata
    }

    private func startTraining() {
        engine.enqueueTraining(session: session, modelContext: modelContext)
    }

    private func savePreset() {
        let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { presetName = "" }
        guard !trimmed.isEmpty else { return }
        let unique = uniqueName(trimmed, existing: presets.map(\.name))
        let preset = TrainingPreset.from(session: session, name: unique)
        modelContext.insert(preset)
        session.preset = preset
    }
}

// MARK: - Batch Item Config Row

private struct BatchItemConfigRow: View {
    @Bindable var item: BatchItem
    let validation: InputValidationResult?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusTint)
                .imageScale(.medium)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Capture Name", text: $item.captureName)
                    .textFieldStyle(.plain)
                    .lineLimit(1)

                Text(item.outputFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var statusSymbol: String {
        if let validation, !validation.errors.isEmpty { return "exclamationmark.triangle.fill" }
        if let validation, !validation.warnings.isEmpty { return "exclamationmark.circle" }
        return "checkmark.circle"
    }

    private var statusTint: Color {
        if let validation, !validation.errors.isEmpty { return .red }
        if let validation, !validation.warnings.isEmpty { return .orange }
        return .secondary
    }
}
