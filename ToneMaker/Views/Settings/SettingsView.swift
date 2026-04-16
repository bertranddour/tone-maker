import SwiftUI

/// Main settings view shown in the Settings window (Cmd+,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Training", systemImage: "brain") {
                TrainingDefaultsSettingsView()
            }
        }
        .scenePadding()
        .frame(minWidth: 450, minHeight: 300)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("pythonEnvironmentPath") private var pythonEnvironmentPath = ""
    @AppStorage("namTrainerProjectPath") private var namTrainerProjectPath = ""
    @AppStorage("defaultModeledBy") private var defaultModeledBy = ""
    @AppStorage("defaultInputLevelDBu") private var defaultInputLevelDBu: Double = 0.0
    @AppStorage("defaultOutputLevelDBu") private var defaultOutputLevelDBu: Double = 0.0

    @State private var environmentStatus: String?
    @State private var isDetecting = false

    var body: some View {
        Form {
            Section("Python Environment") {
                LabeledContent("NAM-Trainer Project") {
                    HStack {
                        TextField("Path", text: $namTrainerProjectPath)
                            .frame(minWidth: 250)
                        Button("Browse\u{2026}") {
                            browseForProject()
                        }
                    }
                }

                LabeledContent("Python/uv Path") {
                    HStack {
                        TextField("Auto-detect", text: $pythonEnvironmentPath)
                            .frame(minWidth: 250)
                        if isDetecting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Detect") {
                                detectEnvironment()
                            }
                        }
                    }
                }

                if let status = environmentStatus {
                    LabeledContent("Status") {
                        Text(status)
                            .foregroundStyle(status.contains("Found") ? .green : .red)
                    }
                }
            }

            Section("Metadata Defaults") {
                TextField("Modeled By", text: $defaultModeledBy, prompt: Text("Your name"))
            }

            Section("Calibration") {
                LabeledContent("Reamp Send Level (dBu)") {
                    TextField("dBu", value: $defaultInputLevelDBu, format: .number.precision(.fractionLength(1)))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Reamp Return Level (dBu)") {
                    TextField("dBu", value: $defaultOutputLevelDBu, format: .number.precision(.fractionLength(1)))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func browseForProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the NAM-Trainer project directory"

        if panel.runModal() == .OK, let url = panel.url {
            namTrainerProjectPath = url.path
        }
    }

    private func detectEnvironment() {
        isDetecting = true
        environmentStatus = nil

        Task {
            let projectURL = namTrainerProjectPath.isEmpty ? nil : URL(fileURLWithPath: namTrainerProjectPath)
            let env = await PythonEnvironmentDetector.detect(
                namTrainerPath: projectURL ?? PythonEnvironmentDetector.defaultNAMTrainerPath
            )

            if let env {
                let valid = await PythonEnvironmentDetector.validate(env)
                await MainActor.run {
                    if valid {
                        environmentStatus = "Found: \(env.pythonPath.path) (validated)"
                        pythonEnvironmentPath = env.pythonPath.path
                    } else {
                        environmentStatus = "Found but validation failed"
                    }
                    isDetecting = false
                }
            } else {
                await MainActor.run {
                    environmentStatus = "Not found. Install uv and NAM, or set path manually."
                    isDetecting = false
                }
            }
        }
    }
}

// MARK: - Training Defaults Settings

struct TrainingDefaultsSettingsView: View {
    @AppStorage("defaultEpochs") private var defaultEpochs = Defaults.epochs
    @AppStorage("defaultArchitecture") private var defaultArchitecture = ModelArchitecture.waveNet.rawValue
    @AppStorage("defaultArchitectureSize") private var defaultArchitectureSize = ArchitectureSize.standard.rawValue

    var body: some View {
        Form {
            Section("Default Training Parameters") {
                Picker("Epochs", selection: $defaultEpochs) {
                    ForEach([100, 200, 400, 800, 1000], id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }

                Picker("Architecture", selection: $defaultArchitecture) {
                    ForEach(ModelArchitecture.allCases) { arch in
                        Text(arch.rawValue).tag(arch.rawValue)
                    }
                }

                Picker("Size", selection: $defaultArchitectureSize) {
                    ForEach(ArchitectureSize.allCases) { size in
                        Text(size.displayName).tag(size.rawValue)
                    }
                }
            }

            Section {
                LabeledContent("GPU Accelerator") {
                    Text(Defaults.hasAccelerator ? "Available (MPS)" : "Not available (CPU only)")
                        .foregroundStyle(Defaults.hasAccelerator ? .green : .orange)
                }
            } header: {
                Text("Hardware")
            } footer: {
                Text("Default batch size and learning rate decay are automatically adjusted based on GPU availability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
