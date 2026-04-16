import Foundation
import SwiftData

/// Core entity representing a single NAM training run.
///
/// Stores all configuration parameters, file references (as security-scoped bookmarks),
/// training results, and relationships to metadata and presets.
@Model
final class TrainingSession {

    // MARK: - Identity

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var completedAt: Date?

    // MARK: - Status

    /// Raw string backing for `TrainingStatus`. Use the computed `status` property for typed access.
    var statusRaw: String = TrainingStatus.configuring.rawValue

    // MARK: - File References (security-scoped bookmarks for sandbox)

    var inputFileBookmark: Data?
    var inputFileName: String?

    /// Multiple output files support batch training. Each entry is a security-scoped bookmark.
    var outputFileBookmarks: [Data] = []
    var outputFileNames: [String] = []


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

    var validationESR: Double?
    var outputModelPaths: [String] = []
    var comparisonPlotPath: String?
    var trainingLog: String?

    // MARK: - Detected During Validation

    var detectedInputVersion: String?
    var calibratedLatency: Int?

    // MARK: - Relationships

    var metadata: ModelMetadata?
    var preset: TrainingPreset?
    @Relationship(deleteRule: .cascade) var persistedAudioFiles: [PersistedAudioFile]?
    @Relationship(deleteRule: .nullify) var captures: [CaptureItem]?

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

    /// Display name: prefers user-set sessionName, then output filename, then fallback.
    var displayName: String {
        if let name = sessionName, !name.isEmpty { return name }
        if let first = outputFileNames.first, !first.isEmpty {
            return first.replacingOccurrences(of: ".wav", with: "")
        }
        return "Untitled Session"
    }

    /// Whether this session supports batch training (multiple output files).
    var isBatchTraining: Bool {
        outputFileBookmarks.count > 1
    }

    /// The persisted input (reference) audio file, if any.
    var persistedInputFile: PersistedAudioFile? {
        (persistedAudioFiles ?? []).first { $0.role == .input }
    }

    /// The persisted output (reamped) audio files, sorted by selection order.
    var persistedOutputFiles: [PersistedAudioFile] {
        (persistedAudioFiles ?? []).filter { $0.role == .output }.sorted { $0.order < $1.order }
    }
}
