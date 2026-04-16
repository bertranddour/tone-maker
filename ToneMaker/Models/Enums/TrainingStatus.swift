import Foundation
import SwiftUI

/// Status of a training session lifecycle.
nonisolated enum TrainingStatus: String, Codable, Sendable {
    case configuring
    case validating
    case training
    case completed
    case failed
    case cancelled

    var displayName: String {
        rawValue.capitalized
    }

    /// Whether this status represents an active (in-progress) session.
    var isActive: Bool {
        switch self {
        case .configuring, .validating, .training: true
        case .completed, .failed, .cancelled: false
        }
    }

    /// SF Symbol name for this status.
    var symbolName: String {
        switch self {
        case .configuring: "slider.horizontal.3"
        case .validating: "checkmark.shield"
        case .training: "cube.transparent"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    /// Tint color for this status indicator.
    var tintColor: Color {
        switch self {
        case .configuring: .secondary
        case .validating: .blue
        case .training: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}
