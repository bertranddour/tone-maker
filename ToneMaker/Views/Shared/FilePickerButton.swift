import SwiftUI
import UniformTypeIdentifiers
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "FilePickerButton")

/// A reusable button that triggers `.fileImporter` for file or directory selection.
///
/// Supports drag & drop: users can drag files from Finder onto the picker.
/// Handles single file, multi-file, and directory modes.
struct FilePickerButton: View {
    let title: String
    let systemImage: String
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let selectedNames: [String]
    let onSelection: ([URL]) -> Void

    @State private var isPresented = false
    @State private var isDropTargeted = false

    init(
        title: String,
        systemImage: String = "folder",
        allowedContentTypes: [UTType] = [.audio],
        allowsMultipleSelection: Bool = false,
        selectedNames: [String] = [],
        onSelection: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.selectedNames = selectedNames
        self.onSelection = onSelection
    }

    var body: some View {
        LabeledContent(title) {
            Button {
                isPresented = true
            } label: {
                HStack {
                    Image(systemName: systemImage)
                    if selectedNames.isEmpty {
                        Text("Choose\u{2026}")
                            .foregroundStyle(.secondary)
                    } else if selectedNames.count == 1 {
                        Text(selectedNames[0])
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("\(selectedNames.count) files")
                    }
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let filtered = urls.filter { url in
                allowedContentTypes.contains { type in
                    UTType(filenameExtension: url.pathExtension)?.conforms(to: type) ?? false
                }
            }
            guard !filtered.isEmpty else { return false }
            onSelection(allowsMultipleSelection ? filtered : [filtered[0]])
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        )
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection
        ) { result in
            switch result {
            case .success(let urls):
                onSelection(urls)
            case .failure(let error):
                logger.error("File selection failed: \(error.localizedDescription)")
            }
        }
    }
}
