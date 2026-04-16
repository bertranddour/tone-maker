import Foundation
import Metal
import SwiftUI

/// Quality assessment for an ESR (Error-to-Signal Ratio) value.
///
/// Thresholds from core.py:1152-1161.
/// Marked `nonisolated` so it can be used from any concurrency context
/// (project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
nonisolated enum ESRQuality: Sendable, Equatable {
    case great       // < 0.01
    case notBad      // < 0.035
    case mightBeOk   // < 0.1
    case probablyBad // < 0.3
    case somethingWrong // >= 0.3

    var comment: String {
        switch self {
        case .great: "Great!"
        case .notBad: "Not bad!"
        case .mightBeOk: "This might sound ok"
        case .probablyBad: "This probably won't sound great"
        case .somethingWrong: "Something seems to have gone wrong"
        }
    }

    var symbolName: String {
        switch self {
        case .great: "star.fill"
        case .notBad: "hand.thumbsup.fill"
        case .mightBeOk: "questionmark.circle.fill"
        case .probablyBad: "exclamationmark.triangle.fill"
        case .somethingWrong: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .great: .green
        case .notBad: .blue
        case .mightBeOk: .yellow
        case .probablyBad: .orange
        case .somethingWrong: .red
        }
    }

    /// Categorizes an ESR value into a quality tier.
    static func from(esr: Double) -> ESRQuality {
        if esr < 0.01 { return .great }
        if esr < 0.035 { return .notBad }
        if esr < 0.1 { return .mightBeOk }
        if esr < 0.3 { return .probablyBad }
        return .somethingWrong
    }
}

/// Computes training parameter defaults based on hardware capabilities.
///
/// Mirrors the logic in NAM's gui/__init__.py lines 78-85:
/// - GPU/MPS available: 100 epochs, batch 16, lr_decay 0.007
/// - CPU only: 20 epochs, batch 1, lr_decay 0.05
nonisolated enum Defaults {

    /// Whether the system has a GPU accelerator (CUDA or MPS).
    /// On Apple Silicon Macs, MPS is always available.
    static let hasAccelerator: Bool = MTLCreateSystemDefaultDevice() != nil

    /// Default number of training epochs.
    static var epochs: Int {
        hasAccelerator ? 100 : 20
    }

    /// Default batch size.
    static var batchSize: Int {
        hasAccelerator ? 16 : 1
    }

    /// Default learning rate decay for WaveNet.
    /// LSTM uses a fixed gamma=0.995, not this value.
    static var learningRateDecay: Double {
        hasAccelerator ? 0.007 : 0.05
    }

    /// Default learning rate for WaveNet.
    static let learningRateWaveNet: Double = 0.004

    /// Default learning rate for LSTM (from core.py:1079).
    static let learningRateLSTM: Double = 0.01

    /// Default output size in samples (core.py:56).
    static let ny: Int = 8192

    /// Default seed for reproducibility (core.py: seed=0).
    static let seed: Int = 0

    /// Standard NAM training sample rate (core.py:54).
    static let standardSampleRate: Double = 48_000.0

    /// Proteus (v4) sample rate.
    static let proteusSampleRate: Double = 44_100.0

    /// MRSTFT pre-emphasis weight (core.py:958).
    static let mrstftPreEmphWeight: Double = 2.0e-4

    /// MRSTFT pre-emphasis coefficient (core.py:959).
    static let mrstftPreEmphCoef: Double = 0.85

    /// Returns the appropriate defaults for a given architecture type.
    static func learningRate(for architecture: ModelArchitecture) -> Double {
        switch architecture {
        case .waveNet: learningRateWaveNet
        case .lstm: learningRateLSTM
        }
    }
}
