import Foundation

/// Neural network architecture type used for NAM training.
///
/// WaveNet is the default and most common architecture.
/// LSTM is an alternative with different performance characteristics.
nonisolated enum ModelArchitecture: String, Codable, CaseIterable, Identifiable, Sendable {
    case waveNet = "WaveNet"
    case lstm = "LSTM"

    var id: Self { self }

    /// Default learning rate for this architecture type.
    /// WaveNet uses 0.004, LSTM uses 0.01 (from core.py:1061,1079).
    var defaultLearningRate: Double {
        switch self {
        case .waveNet: 0.004
        case .lstm: 0.01
        }
    }

    /// Default learning rate decay for this architecture type.
    /// WaveNet uses a configurable decay (default 0.007 GPU / 0.05 CPU).
    /// LSTM uses a fixed gamma of 0.995 regardless of GPU/CPU.
    var defaultLearningRateDecay: Double? {
        switch self {
        case .waveNet: nil // Computed from GPU/CPU defaults
        case .lstm: nil // LSTM uses fixed gamma=0.995, not lr_decay
        }
    }
}
