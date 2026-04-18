import Foundation

/// A single epoch's validation-loss sample, captured during training and
/// persisted on the `BatchItem` so the loss curve survives across launches.
nonisolated struct TrainingMetric: Codable, Sendable, Hashable {
    let epoch: Int
    let valLoss: Double
}
