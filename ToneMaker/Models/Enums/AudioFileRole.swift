import Foundation

/// Distinguishes between input (reference) and output (reamped) audio files
/// persisted alongside a training session.
nonisolated enum AudioFileRole: String, Codable, CaseIterable, Sendable {
    case input
    case output
}
