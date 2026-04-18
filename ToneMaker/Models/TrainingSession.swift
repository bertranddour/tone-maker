import Foundation
import SwiftData

/// Core entity representing a single NAM training run.
///
/// Holds configuration parameters, the input (DI) file reference, and a collection
/// of `BatchItem`s — one per output (reamped) file to train. Per-item results
/// (ESR, latency, error, produced `CaptureItem`) live on the `BatchItem`, not here.
@Model
final class TrainingSession {

    // MARK: - Identity

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var completedAt: Date?

    // MARK: - Status

    /// Raw string backing for `TrainingStatus`. Use the computed `status` property for typed access.
    var statusRaw: String = TrainingStatus.configuring.rawValue

    /// Timestamp set when the user enqueues this session for training. The engine
    /// advances the queue by picking the oldest `.queued` session (earliest `queuedAt`).
    var queuedAt: Date?

    // MARK: - Input File Reference

    var inputFileBookmark: Data?
    var inputFileName: String?

    // MARK: - Architecture

    /// Raw string backing for `ModelArchitecture`.
    var modelTypeRaw: String = ModelArchitecture.waveNet.rawValue
    /// Raw string backing for `ArchitectureSize`.
    var architectureSizeRaw: String = ArchitectureSize.standard.rawValue

    // MARK: - Training Parameters

    var epochs: Int = 100
    var learningRate: Double = 0.004
    var learningRateDecay: Double = 0.007
    var batchSize: Int = 16
    var ny: Int = 8192
    var seed: Int = 0
    var latencyOverride: Int?
    var esrThreshold: Double?
    var savePlot: Bool = true
    var fitMRSTFT: Bool = true
    var ignoreChecks: Bool = false

    /// User-editable session name for the sidebar.
    var sessionName: String?

    // MARK: - Results

    var trainingLog: String?
    var detectedInputVersion: String?

    // MARK: - Relationships

    var metadata: ModelMetadata?
    var preset: TrainingPreset?
    @Relationship(deleteRule: .cascade) var persistedAudioFiles: [PersistedAudioFile]?
    @Relationship(deleteRule: .nullify) var captures: [CaptureItem]?
    @Relationship(deleteRule: .cascade) var batchItems: [BatchItem]?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        status: TrainingStatus = .configuring,
        modelType: ModelArchitecture = .waveNet,
        architectureSize: ArchitectureSize = .standard,
        epochs: Int = 100,
        learningRate: Double = 0.004,
        learningRateDecay: Double = 0.007,
        batchSize: Int = 16,
        ny: Int = 8192,
        seed: Int = 0,
        savePlot: Bool = true,
        fitMRSTFT: Bool = true,
        ignoreChecks: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.statusRaw = status.rawValue
        self.modelTypeRaw = modelType.rawValue
        self.architectureSizeRaw = architectureSize.rawValue
        self.epochs = epochs
        self.learningRate = learningRate
        self.learningRateDecay = learningRateDecay
        self.batchSize = batchSize
        self.ny = ny
        self.seed = seed
        self.savePlot = savePlot
        self.fitMRSTFT = fitMRSTFT
        self.ignoreChecks = ignoreChecks
    }
}

// MARK: - Typed Enum Access

extension TrainingSession {

    var status: TrainingStatus {
        get { TrainingStatus(rawValue: statusRaw) ?? .configuring }
        set { statusRaw = newValue.rawValue }
    }

    var modelType: ModelArchitecture {
        get { ModelArchitecture(rawValue: modelTypeRaw) ?? .waveNet }
        set { modelTypeRaw = newValue.rawValue }
    }

    var architectureSize: ArchitectureSize {
        get { ArchitectureSize(rawValue: architectureSizeRaw) ?? .standard }
        set { architectureSizeRaw = newValue.rawValue }
    }

    /// Display name: prefers user-set sessionName, then first batch item's file, then fallback.
    var displayName: String {
        if let name = sessionName, !name.isEmpty { return name }
        if let first = sortedBatchItems.first?.outputFileName, !first.isEmpty {
            return first.replacingOccurrences(of: ".wav", with: "", options: .caseInsensitive)
        }
        return "Untitled Session"
    }

    /// Whether this session supports batch training (multiple output files).
    var isBatchTraining: Bool {
        (batchItems?.count ?? 0) > 1
    }

    /// Batch items sorted by `order` for deterministic display and execution.
    var sortedBatchItems: [BatchItem] {
        (batchItems ?? []).sorted { $0.order < $1.order }
    }

    /// The best (lowest) ESR across completed batch items, or `nil` if none produced one.
    var bestValidationESR: Double? {
        sortedBatchItems.compactMap(\.validationESR).min()
    }

    /// Whether the session has at least one item and every item is `.completed`.
    var allItemsSucceeded: Bool {
        let items = sortedBatchItems
        return !items.isEmpty && items.allSatisfy { $0.status == .completed }
    }

    /// Whether any item is `.completed`. Used to distinguish "fully failed" from "partial success".
    var hasAnyCompletedItem: Bool {
        sortedBatchItems.contains { $0.status == .completed }
    }

    /// The persisted input (reference) audio file, if any.
    var persistedInputFile: PersistedAudioFile? {
        (persistedAudioFiles ?? []).first { $0.role == .input }
    }
}
