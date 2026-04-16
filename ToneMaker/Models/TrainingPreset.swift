import Foundation
import SwiftData

/// A reusable snapshot of training parameters that can be applied to new sessions.
///
/// Presets store architecture and training configuration but not file paths or results.
@Model
final class TrainingPreset {

    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // MARK: - Architecture

    var modelTypeRaw: String = ModelArchitecture.waveNet.rawValue
    var architectureSizeRaw: String = ArchitectureSize.standard.rawValue

    // MARK: - Training Parameters

    var epochs: Int = 100
    var learningRate: Double = 0.004
    var learningRateDecay: Double = 0.007
    var batchSize: Int = 16
    var ny: Int = 8192
    var seed: Int = 0
    var fitMRSTFT: Bool = true

    // MARK: - Relationships

    @Relationship(inverse: \TrainingSession.preset)
    var sessions: [TrainingSession]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modelType: ModelArchitecture = .waveNet,
        architectureSize: ArchitectureSize = .standard,
        epochs: Int = 100,
        learningRate: Double = 0.004,
        learningRateDecay: Double = 0.007,
        batchSize: Int = 16,
        ny: Int = 8192,
        seed: Int = 0,
        fitMRSTFT: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modelTypeRaw = modelType.rawValue
        self.architectureSizeRaw = architectureSize.rawValue
        self.epochs = epochs
        self.learningRate = learningRate
        self.learningRateDecay = learningRateDecay
        self.batchSize = batchSize
        self.ny = ny
        self.seed = seed
        self.fitMRSTFT = fitMRSTFT
    }
}

// MARK: - Typed Enum Access

extension TrainingPreset {

    var modelType: ModelArchitecture {
        get { ModelArchitecture(rawValue: modelTypeRaw) ?? .waveNet }
        set { modelTypeRaw = newValue.rawValue }
    }

    var architectureSize: ArchitectureSize {
        get { ArchitectureSize(rawValue: architectureSizeRaw) ?? .standard }
        set { architectureSizeRaw = newValue.rawValue }
    }
}

// MARK: - Factory

extension TrainingPreset {

    /// Creates a preset from an existing training session's parameters.
    static func from(session: TrainingSession, name: String) -> TrainingPreset {
        TrainingPreset(
            name: name,
            modelType: session.modelType,
            architectureSize: session.architectureSize,
            epochs: session.epochs,
            learningRate: session.learningRate,
            learningRateDecay: session.learningRateDecay,
            batchSize: session.batchSize,
            ny: session.ny,
            seed: session.seed,
            fitMRSTFT: session.fitMRSTFT
        )
    }

    /// Applies this preset's parameters to a training session.
    func apply(to session: TrainingSession) {
        session.modelType = modelType
        session.architectureSize = architectureSize
        session.epochs = epochs
        session.learningRate = learningRate
        session.learningRateDecay = learningRateDecay
        session.batchSize = batchSize
        session.ny = ny
        session.seed = seed
        session.fitMRSTFT = fitMRSTFT
        session.preset = self
    }
}
