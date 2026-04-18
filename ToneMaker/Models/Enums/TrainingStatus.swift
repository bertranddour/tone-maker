import Foundation
import SwiftUI

/// Status of a training session lifecycle.
nonisolated enum TrainingStatus: String, Codable, Sendable {
    case configuring
    case queued
    case validating
    case training
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .configuring: "Configuring"
        case .queued: "Queued"
        case .validating: "Validating"
        case .training: "Training"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    /// Whether this status represents an active (in-progress or about-to-run) session.
    var isActive: Bool {
        switch self {
        case .configuring, .queued, .validating, .training: true
        case .completed, .failed, .cancelled: false
        }
    }

    /// SF Symbol name for this status.
    var symbolName: String {
        switch self {
        case .configuring: "slider.horizontal.3"
        case .queued: "list.bullet.circle"
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
        case .queued: .orange
        case .validating: .blue
        case .training: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}
