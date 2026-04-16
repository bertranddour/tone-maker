import Foundation

/// Type of gear being modeled.
///
/// Maps directly to NAM's `GearType` enum (metadata.py:16-23).
nonisolated enum GearType: String, Codable, CaseIterable, Identifiable, Sendable {
    case amp
    case pedal
    case pedalAmp = "pedal_amp"
    case ampCab = "amp_cab"
    case ampPedalCab = "amp_pedal_cab"
    case preamp
    case studio

    var id: Self { self }

    var displayName: String {
        switch self {
        case .amp: "Amp"
        case .pedal: "Pedal"
        case .pedalAmp: "Pedal + Amp"
        case .ampCab: "Amp + Cab"
        case .ampPedalCab: "Amp + Pedal + Cab"
        case .preamp: "Preamp"
        case .studio: "Studio"
        }
    }
}
