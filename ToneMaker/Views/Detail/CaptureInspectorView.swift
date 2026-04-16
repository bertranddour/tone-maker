import SwiftUI
import UniformTypeIdentifiers

/// Editable inspector pane for a single capture.
///
/// Uses `@Bindable` for direct SwiftData model binding per Apple docs.
struct CaptureInspectorView: View {
    @Bindable var capture: CaptureItem
    @State private var showExporter = false

    var body: some View {
        Form {
            Section("Capture") {
                TextField("Rig Name", text: $capture.name)
                TextField("Brand", text: $capture.brand)
                TextField("Model", text: $capture.model)
                TextField("Modeled By", text: $capture.modeledBy)
            }

            Section("Category") {
                Picker("Type", selection: gearTypeBinding) {
                    Text("Not Set").tag(GearType?.none)
                    ForEach(GearType.allCases) { type in
                        Text(type.displayName).tag(GearType?.some(type))
                    }
                }

                Picker("Gain", selection: toneTypeBinding) {
                    ForEach(ToneType.allCases) { type in
                        Text(type.displayName).tag(ToneType?.some(type))
                    }
                }
            }

            if let esr = capture.validationESR {
                Section("Quality") {
                    HStack {
                        Text(String(format: "%.6f", esr))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        ESRQualityBadge(esr: esr)
                    }
                }
            }

            Section("Details") {
                LabeledContent("Architecture") {
                    Text("\(capture.architecture.rawValue) \(capture.architectureSize.displayName)")
                }
                if let inputLevel = capture.inputLevelDBu {
                    LabeledContent("Input Level", value: String(format: "%.1f dBu", inputLevel))
                }
                if let outputLevel = capture.outputLevelDBu {
                    LabeledContent("Output Level", value: String(format: "%.1f dBu", outputLevel))
                }
                LabeledContent("Created", value: capture.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                Button {
                    showExporter = true
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        .fileExporter(
            isPresented: $showExporter,
            item: capture.modelFileData,
            contentTypes: [.data],
            defaultFilename: capture.modelFileName
        ) { _ in }
    }

    private var gearTypeBinding: Binding<GearType?> {
        Binding(
            get: { capture.gearType },
            set: { capture.gearTypeRaw = $0?.rawValue }
        )
    }

    private var toneTypeBinding: Binding<ToneType?> {
        Binding(
            get: { capture.toneType },
            set: { capture.toneTypeRaw = $0?.rawValue }
        )
    }
}
