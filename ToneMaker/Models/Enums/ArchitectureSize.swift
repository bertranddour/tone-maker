import Foundation

/// Size variant for neural network architectures.
///
/// Each size offers a different trade-off between model quality and training/inference speed.
/// Maps directly to NAM's `Architecture` enum (core.py:59-63).
nonisolated enum ArchitectureSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case lite
    case feather
    case nano

    var id: Self { self }

    var displayName: String {
        rawValue.capitalized
    }

    /// Human-readable description of the size variant's characteristics.
    var subtitle: String {
        switch self {
        case .standard: "Best quality, slower training"
        case .lite: "Good quality, faster training"
        case .feather: "Medium quality, light footprint"
        case .nano: "Smallest model, fastest inference"
        }
    }
}
