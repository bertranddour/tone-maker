import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "LibraryImport")

/// Displays captures as a color-coded grid sorted by gain type.
///
/// Sections grouped by Brand + Model, with sticky headers.
/// Supports search, multi-select, delete, import, and inspector.
struct LibraryGridView: View {
    let captures: [CaptureItem]
    @Binding var selectedCapture: CaptureItem?
    @Environment(\.modelContext) private var modelContext
    @State private var selection = Set<CaptureItem.ID>()
    @State private var searchText = ""
    @State private var showInspector = false
    @State private var showImporter = false
    @State private var showDeleteConfirmation = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        Group {
            if filteredCaptures.isEmpty {
                ContentUnavailableView {
                    Label(
                        searchText.isEmpty ? "No Captures" : "No Results",
                        systemImage: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass"
                    )
                } description: {
                    Text(searchText.isEmpty
                         ? "Import .nam files or train a model to add captures."
                         : "No captures match \"\(searchText)\".")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedCaptures, id: \.key) { group in
                            Section {
                                ForEach(group.captures) { capture in
                                    CaptureGridCell(
                                        capture: capture,
                                        isSelected: selection.contains(capture.id)
                                    )
                                    .onTapGesture(count: 2) {
                                        selectedCapture = capture
                                        showInspector = true
                                    }
                                    .onTapGesture {
                                        if NSEvent.modifierFlags.contains(.command) {
                                            if selection.contains(capture.id) {
                                                selection.remove(capture.id)
                                            } else {
                                                selection.insert(capture.id)
                                            }
                                        } else {
                                            selection = [capture.id]
                                        }
                                        selectedCapture = capture
                                    }
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            if !selection.contains(capture.id) {
                                                selection = [capture.id]
                                            }
                                            showDeleteConfirmation = true
                                        }
                                    }
                                }
                            } header: {
                                Text(group.key.isEmpty ? "Unknown" : group.key)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)
                                    .background(.bar)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search captures")
        .inspector(isPresented: $showInspector) {
            if let capture = selectedCapture {
                CaptureInspectorView(capture: capture)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import", systemImage: "square.and.arrow.down") {
                    showImporter = true
                }
            }
            ToolbarItem {
                Button("Delete", systemImage: "trash") {
                    showDeleteConfirmation = true
                }
                .disabled(selection.isEmpty)
            }
            ToolbarItem {
                Button("Inspector", systemImage: "sidebar.trailing") {
                    showInspector.toggle()
                }
                .disabled(selectedCapture == nil)
            }
        }
        .onDeleteCommand {
            if !selection.isEmpty { showDeleteConfirmation = true }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                importNAMFiles(urls)
            }
        }
        .confirmationDialog(
            "Delete \(selection.count) capture\(selection.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Filtering & Grouping

    private var filteredCaptures: [CaptureItem] {
        guard !searchText.isEmpty else { return captures }
        let query = searchText.lowercased()
        return captures.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.brand.localizedCaseInsensitiveContains(query)
            || $0.model.localizedCaseInsensitiveContains(query)
            || ($0.toneType?.displayName.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var groupedCaptures: [(key: String, captures: [CaptureItem])] {
        let sorted = sortedCaptures(from: filteredCaptures)
        let grouped = Dictionary(grouping: sorted) { capture in
            [capture.brand, capture.model].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return grouped
            .map { (key: $0.key, captures: $0.value) }
            .sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
    }

    private func sortedCaptures(from items: [CaptureItem]) -> [CaptureItem] {
        let order: [ToneType] = [.clean, .overdrive, .crunch, .hiGain, .fuzz]
        return items.sorted { a, b in
            let aIndex = a.toneType.flatMap { order.firstIndex(of: $0) } ?? order.count
            let bIndex = b.toneType.flatMap { order.firstIndex(of: $0) } ?? order.count
            if aIndex != bIndex { return aIndex < bIndex }
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - Delete

    private func performDelete() {
        for id in selection {
            if let capture = captures.first(where: { $0.id == id }) {
                modelContext.delete(capture)
            }
        }
        if let selected = selectedCapture, selection.contains(selected.id) {
            selectedCapture = nil
            showInspector = false
        }
        selection.removeAll()
    }

    // MARK: - Import

    private func importNAMFiles(_ urls: [URL]) {
        let namURLs = urls.filter { $0.pathExtension.lowercased() == "nam" }
        guard !namURLs.isEmpty else {
            logger.warning("No .nam files in selection (\(urls.count) files)")
            return
        }
        logger.info("Importing \(namURLs.count) .nam file(s)")

        for url in namURLs {
            logger.debug("Processing: \(url.lastPathComponent)")

            guard url.startAccessingSecurityScopedResource() else {
                logger.error("Security-scoped access denied: \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let fileData = try? Data(contentsOf: url) else {
                logger.error("Failed to read file data: \(url.lastPathComponent)")
                continue
            }
            logger.debug("Read \(fileData.count) bytes from \(url.lastPathComponent)")

            let capture = CaptureItem()
            capture.modelFileData = fileData
            capture.modelFileName = url.lastPathComponent
            capture.name = url.deletingPathExtension().lastPathComponent

            if let meta = NAMMetadataReader.readMetadata(from: url.path) {
                logger.info("Metadata extracted for \(url.lastPathComponent): name=\(meta.name ?? "nil"), gearType=\(meta.gearType ?? "nil"), toneType=\(meta.toneType ?? "nil")")
                if let name = meta.name, !name.isEmpty { capture.name = name }
                if let brand = meta.gearMake { capture.brand = brand }
                if let model = meta.gearModel { capture.model = model }
                if let by = meta.modeledBy { capture.modeledBy = by }
                if let gt = meta.gearType { capture.gearTypeRaw = gt }
                if let tt = meta.toneType { capture.toneTypeRaw = tt }
                capture.inputLevelDBu = meta.inputLevelDBu
                capture.outputLevelDBu = meta.outputLevelDBu
            } else {
                logger.warning("No metadata extracted for \(url.lastPathComponent)")
            }

            modelContext.insert(capture)
            logger.info("Imported capture: \(capture.name) (\(url.lastPathComponent))")
        }
    }
}
