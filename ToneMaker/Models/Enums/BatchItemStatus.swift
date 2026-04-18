import Foundation
import SwiftUI

/// Lifecycle status of a single `BatchItem` within a training session's batch.
nonisolated enum BatchItemStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case skipped

    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .running: "Running"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .skipped: "Skipped"
        }
    }

    /// Whether this status represents a finished (non-running) state.
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .skipped: true
        case .pending, .running: false
        }
    }

    var symbolName: String {
        switch self {
        case .pending: "circle.dotted"
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        case .skipped: "forward.end.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .pending: .secondary
        case .running: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        case .skipped: .secondary
        }
    }
}
