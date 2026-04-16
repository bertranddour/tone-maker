import SwiftUI

/// Main settings view shown in the Settings window (Cmd+,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Environment", systemImage: "terminal") {
                EnvironmentSettingsView()
            }
            Tab("Profile", systemImage: "person.circle") {
                ProfileSettingsView()
            }
            Tab("Training", systemImage: "cube.transparent") {
                TrainingSettingsView()
            }
        }
        .scenePadding()
        .frame(minWidth: 480, minHeight: 280)
    }
}

// MARK: - Environment

/// Python/NAM setup and hardware detection.
struct EnvironmentSettingsView: View {
    @AppStorage("pythonEnvironmentPath") private var pythonEnvironmentPath = ""
    @AppStorage("namTrainerProjectPath") private var namTrainerProjectPath = ""

    @State private var environmentStatus: String?
    @State private var isDetecting = false

    var body: some View {
        Form {
            Section("NAM-Trainer") {
                LabeledContent("Project Path") {
                    HStack {
                        TextField("Path", text: $namTrainerProjectPath)
                            .frame(minWidth: 250)
                        Button("Browse\u{2026}") {
                            browseForProject()
                        }
                    }
                }

                LabeledContent("Python") {
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

            Section {
                LabeledContent("GPU Accelerator") {
                    Text(Defaults.hasAccelerator ? "Available (MPS)" : "Not available (CPU only)")
                        .foregroundStyle(Defaults.hasAccelerator ? .green : .orange)
                }
            } header: {
                Text("Hardware")
            } footer: {
                Text("Batch size and learning rate decay are adjusted automatically based on GPU availability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            let projectURL = namTrainerProjectPath.isEmpty
                ? PythonEnvironmentDetector.defaultNAMTrainerPath
                : URL(fileURLWithPath: namTrainerProjectPath)

            let env = await PythonEnvironmentDetector.detect(namTrainerPath: projectURL)

            if let env {
                let valid = await PythonEnvironmentDetector.validate(env)
                if valid {
                    environmentStatus = "Found: \(env.pythonPath.path) (validated)"
                    pythonEnvironmentPath = env.pythonPath.path
                } else {
                    environmentStatus = "Found but validation failed"
                }
            } else {
                environmentStatus = "Not found. Install NAM-Trainer with a .venv, or set path manually."
            }
            isDetecting = false
        }
    }
}

// MARK: - Profile

/// Identity and rig calibration -- metadata embedded in every capture.
struct ProfileSettingsView: View {
    @AppStorage("defaultModeledBy") private var defaultModeledBy = ""
    @AppStorage("defaultInputLevelDBu") private var defaultInputLevelDBu: Double = 0.0
    @AppStorage("defaultOutputLevelDBu") private var defaultOutputLevelDBu: Double = 0.0

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Modeled By", text: $defaultModeledBy, prompt: Text("Your name"))
            }

            Section {
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
            } header: {
                Text("Calibration")
            } footer: {
                Text("These values are embedded in capture metadata for accurate level matching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Training

/// Default parameters for new training sessions.
struct TrainingSettingsView: View {
    @AppStorage("defaultEpochs") private var defaultEpochs = Defaults.epochs
    @AppStorage("defaultArchitecture") private var defaultArchitecture = ModelArchitecture.waveNet.rawValue
    @AppStorage("defaultArchitectureSize") private var defaultArchitectureSize = ArchitectureSize.standard.rawValue

    var body: some View {
        Form {
            Section("Defaults for New Sessions") {
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
        }
        .formStyle(.grouped)
    }
}
