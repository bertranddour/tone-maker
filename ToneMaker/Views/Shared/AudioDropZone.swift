import SwiftUI
import UniformTypeIdentifiers

/// A visible drop zone for audio files with dashed border and drag feedback.
///
/// Fixed height regardless of content state. Supports drag & drop and click-to-browse.
struct AudioDropZone: View {
    let title: String
    let allowsMultipleSelection: Bool
    let selectedNames: [String]
    let onSelection: ([URL]) -> Void

    @State private var isPresented = false
    @State private var isDropTargeted = false

    private let zoneHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack {
                // Background + border (always same size)
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary)
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : .secondary.opacity(selectedNames.isEmpty ? 0.25 : 0.15),
                        style: selectedNames.isEmpty
                            ? StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [6, 4])
                            : StrokeStyle(lineWidth: isDropTargeted ? 2 : 1)
                    )

                // Content
                if selectedNames.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Text(allowsMultipleSelection ? "Drop audio files here" : "Drop audio file here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("or click to browse")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(selectedNames, id: \.self) { name in
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(name)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .frame(height: zoneHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isPresented = true }
            .dropDestination(for: URL.self) { urls, _ in
                let filtered = urls.filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "wav" || ext == "aif" || ext == "aiff"
                }
                guard !filtered.isEmpty else { return false }
                onSelection(allowsMultipleSelection ? filtered : [filtered[0]])
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTargeted = targeted
                }
            }
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.wav, .audio],
                allowsMultipleSelection: allowsMultipleSelection
            ) { result in
                if case .success(let urls) = result {
                    onSelection(urls)
                }
            }
        }
    }
}
