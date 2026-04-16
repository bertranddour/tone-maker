import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main configuration form for a training session.
///
/// Combines audio file selection, model configuration (with inline metadata),
/// training parameters, and advanced options in a single grouped form.
struct TrainingConfigView: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var modelContext
    @Environment(TrainingEngine.self) private var engine

    @AppStorage("defaultModeledBy") private var defaultModeledBy = ""
    @AppStorage("defaultInputLevelDBu") private var defaultInputLevelDBu: Double = 0.0
    @AppStorage("defaultOutputLevelDBu") private var defaultOutputLevelDBu: Double = 0.0

    @Query(sort: \TrainingPreset.name) private var presets: [TrainingPreset]

    @State private var inputValidation: InputValidationResult?
    @State private var outputValidations: [String: InputValidationResult] = [:]
    @State private var showSavePreset = false
    @State private var presetName = ""

    var body: some View {
        Form {
            presetSection
            audioFilesSection
            modelSection
            trainingSection
            advancedOptionsSection
        }
        .formStyle(.grouped)
        .navigationTitle(session.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Train", systemImage: "play.fill") {
                    startTraining()
                }
                .disabled(!canStartTraining)
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Menu("Preset", systemImage: "slider.horizontal.3") {
                    Button("Save Current as Preset\u{2026}") {
                        showSavePreset = true
                    }
                    if !presets.isEmpty {
                        Divider()
                        ForEach(presets) { preset in
                            Button(preset.name) {
                                preset.apply(to: session)
                            }
                        }
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

    // MARK: - Preset Section

    @ViewBuilder
    private var presetSection: some View {
        if !presets.isEmpty {
            Section {
                Picker("Load Preset", selection: .constant("")) {
                    Text("Custom").tag("")
                    ForEach(presets) { preset in
                        Text(preset.name).tag(preset.id.uuidString)
                    }
                }
            }
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
                    selectedNames: session.outputFileNames,
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

    /// Creates a non-optional String binding for a metadata field.
    /// Ensures metadata object exists before binding.
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

    private var canStartTraining: Bool {
        session.inputFileBookmark != nil
            && !session.outputFileBookmarks.isEmpty
            && (inputValidation?.isValid ?? true)
            && !hasOutputValidationErrors
            && !engine.isTraining
    }

    private var hasOutputValidationIssues: Bool {
        outputValidations.values.contains { !$0.errors.isEmpty || !$0.warnings.isEmpty }
    }

    private var hasOutputValidationErrors: Bool {
        outputValidations.values.contains { !$0.errors.isEmpty }
    }

    private var allOutputWarnings: [String] {
        outputValidations.flatMap { (name, result) in
            result.warnings.map { "\(name): \($0)" }
        }
    }

    private var allOutputErrors: [String] {
        outputValidations.flatMap { (name, result) in
            result.errors.map { "\(name): \($0)" }
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

        // Persist file data for session relaunch
        for existing in (session.persistedAudioFiles ?? []) where existing.role == .input {
            modelContext.delete(existing)
        }
        if let data = try? Data(contentsOf: url) {
            let persisted = PersistedAudioFile(
                fileName: url.lastPathComponent,
                role: .input,
                order: 0,
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
        // Clear previous persisted output files
        for existing in (session.persistedAudioFiles ?? []) where existing.role == .output {
            modelContext.delete(existing)
        }

        var bookmarks: [Data] = []
        var names: [String] = []
        outputValidations = [:]

        for (index, url) in urls.enumerated() {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            if let bookmark = try? FileBookmark.create(for: url) {
                bookmarks.append(bookmark)
            }
            names.append(url.lastPathComponent)

            // Persist file data for session relaunch
            if let data = try? Data(contentsOf: url) {
                let persisted = PersistedAudioFile(
                    fileName: url.lastPathComponent,
                    role: .output,
                    order: index,
                    fileData: data
                )
                modelContext.insert(persisted)
                if session.persistedAudioFiles == nil { session.persistedAudioFiles = [] }
            session.persistedAudioFiles?.append(persisted)
            }

            // Validate against input if available
            if let inputInfo = inputValidation?.wavInfo {
                outputValidations[url.lastPathComponent] = InputFileValidator.validateOutput(at: url, against: inputInfo)
            }
        }

        session.outputFileBookmarks = bookmarks
        session.outputFileNames = names

        // Auto-populate Rig Name from first output filename if not already set
        if let firstName = names.first {
            let derived = firstName.replacingOccurrences(of: ".wav", with: "", options: .caseInsensitive)
            let metadata = ensureMetadata()
            if metadata.namName == nil || metadata.namName?.isEmpty == true {
                metadata.namName = derived
            }
        }
    }

    private func revalidateOutputFiles(against inputInfo: WAVHeaderReader.WAVInfo) {
        outputValidations = [:]
        for (index, bookmark) in session.outputFileBookmarks.enumerated() {
            guard let url = FileBookmark.resolveAndAccess(bookmark) else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let name = index < session.outputFileNames.count ? session.outputFileNames[index] : url.lastPathComponent
            outputValidations[name] = InputFileValidator.validateOutput(at: url, against: inputInfo)
        }
    }

    @discardableResult
    private func ensureMetadata() -> ModelMetadata {
        if let existing = session.metadata { return existing }
        let metadata = ModelMetadata()
        // Auto-fill from Settings (gear type and tone type default in ModelMetadata init)
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
        engine.startTraining(session: session, modelContext: modelContext)
    }

    private func savePreset() {
        guard !presetName.isEmpty else { return }
        let preset = TrainingPreset.from(session: session, name: presetName)
        modelContext.insert(preset)
        presetName = ""
    }
}
