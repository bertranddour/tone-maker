import Foundation
import SwiftData

/// A single output file within a `TrainingSession`'s batch.
///
/// Each `BatchItem` represents one capture to produce: it carries its own
/// status, ESR, detected latency, error message, and produced `CaptureItem`
/// so cancellation or partial failure in a multi-file batch preserves the
/// state of every other item.
@Model
final class BatchItem {

    // MARK: - Identity

    var id: UUID = UUID()
    var order: Int = 0
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?

    // MARK: - File Reference

    var outputFileBookmark: Data?
    var outputFileName: String = ""

    /// Per-item NAM name embedded in the exported `.nam` metadata and used as
    /// the resulting `CaptureItem.name`. Defaults to the output filename
    /// (without extension) when the user has not customized it.
    var captureName: String = ""

    // MARK: - Status

    /// Raw backing for `BatchItemStatus`. Use the computed `status` for typed access.
    var statusRaw: String = BatchItemStatus.pending.rawValue

    // MARK: - Results

    var validationESR: Double?
    var calibratedLatency: Int?
    var outputModelPath: String?
    var comparisonPlotPath: String?
    var errorMessage: String?

    // MARK: - Relationships

    @Relationship(inverse: \TrainingSession.batchItems)
    var session: TrainingSession?

    @Relationship(deleteRule: .nullify)
    var capture: CaptureItem?

    @Relationship(deleteRule: .cascade)
    var persistedOutputFile: PersistedAudioFile?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        outputFileName: String = "",
        captureName: String = ""
    ) {
        self.id = id
        self.order = order
        self.outputFileName = outputFileName
        self.captureName = captureName
    }
}

// MARK: - Typed Enum Access

extension BatchItem {

    var status: BatchItemStatus {
        get { BatchItemStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// User-facing label: prefers `captureName`, falls back to the output filename
    /// with the `.wav` extension stripped.
    var displayName: String {
        if !captureName.isEmpty { return captureName }
        if outputFileName.isEmpty { return "Untitled Item" }
        return outputFileName.replacingOccurrences(of: ".wav", with: "", options: .caseInsensitive)
    }
}
