import Foundation
import SwiftUI

/// Type of tone the modeled gear produces.
///
/// Maps directly to NAM's `ToneType` enum (metadata.py:27-32).
nonisolated enum ToneType: String, Codable, CaseIterable, Identifiable, Sendable {
    case clean
    case overdrive
    case crunch
    case hiGain = "hi_gain"
    case fuzz

    var id: Self { self }

    var displayName: String {
        switch self {
        case .clean: "Clean"
        case .overdrive: "Overdrive"
        case .crunch: "Crunch"
        case .hiGain: "High Gain"
        case .fuzz: "Fuzz"
        }
    }

    var color: Color {
        switch self {
        case .clean: .cyan
        case .crunch: .orange
        case .overdrive: .yellow
        case .hiGain: .red
        case .fuzz: .purple
        }
    }
}
