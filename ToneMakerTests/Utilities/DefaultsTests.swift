import Testing
import Foundation
@testable import ToneMaker

struct DefaultsTests {

    // MARK: - Hardware Detection

    @Test func hasAcceleratorIsConsistent() {
        // On Apple Silicon Macs, Metal is always available
        // This test just verifies the property doesn't crash and returns a Bool
        let result = Defaults.hasAccelerator
        #expect(result == true || result == false)
    }

    // MARK: - Default Constants

    @Test func standardSampleRate() {
        #expect(Defaults.standardSampleRate == 48_000.0)
    }

    @Test func proteusSampleRate() {
        #expect(Defaults.proteusSampleRate == 44_100.0)
    }

    @Test func defaultNy() {
        #expect(Defaults.ny == 8192)
    }

    @Test func defaultSeed() {
        #expect(Defaults.seed == 0)
    }

    @Test func mrstftConstants() {
        #expect(Defaults.mrstftPreEmphWeight == 2.0e-4)
        #expect(Defaults.mrstftPreEmphCoef == 0.85)
    }

    // MARK: - Architecture-Specific Defaults

    @Test func waveNetLearningRate() {
        #expect(Defaults.learningRateWaveNet == 0.004)
        #expect(Defaults.learningRate(for: .waveNet) == 0.004)
    }

    @Test func lstmLearningRate() {
        #expect(Defaults.learningRateLSTM == 0.01)
        #expect(Defaults.learningRate(for: .lstm) == 0.01)
    }

    // MARK: - GPU/CPU Dependent Defaults

    @Test func epochsDefault() {
        let expected = Defaults.hasAccelerator ? 100 : 20
        #expect(Defaults.epochs == expected)
    }

    @Test func batchSizeDefault() {
        let expected = Defaults.hasAccelerator ? 16 : 1
        #expect(Defaults.batchSize == expected)
    }

    @Test func learningRateDecayDefault() {
        let expected = Defaults.hasAccelerator ? 0.007 : 0.05
        #expect(Defaults.learningRateDecay == expected)
    }

    // MARK: - ESR Quality Assessment

    @Test func esrQualityGreat() {
        #expect(ESRQuality.from(esr: 0.005) == .great)
        #expect(ESRQuality.from(esr: 0.009) == .great)
    }

    @Test func esrQualityNotBad() {
        #expect(ESRQuality.from(esr: 0.01) == .notBad)
        #expect(ESRQuality.from(esr: 0.034) == .notBad)
    }

    @Test func esrQualityMightBeOk() {
        #expect(ESRQuality.from(esr: 0.035) == .mightBeOk)
        #expect(ESRQuality.from(esr: 0.099) == .mightBeOk)
    }

    @Test func esrQualityProbablyBad() {
        #expect(ESRQuality.from(esr: 0.1) == .probablyBad)
        #expect(ESRQuality.from(esr: 0.299) == .probablyBad)
    }

    @Test func esrQualitySomethingWrong() {
        #expect(ESRQuality.from(esr: 0.3) == .somethingWrong)
        #expect(ESRQuality.from(esr: 1.0) == .somethingWrong)
    }

    @Test func esrQualityBoundaryValues() {
        // Exact boundary: 0.01 should be "notBad", not "great"
        #expect(ESRQuality.from(esr: 0.01) == .notBad)
        // Exact boundary: 0.035 should be "mightBeOk", not "notBad"
        #expect(ESRQuality.from(esr: 0.035) == .mightBeOk)
        // Exact boundary: 0.1 should be "probablyBad", not "mightBeOk"
        #expect(ESRQuality.from(esr: 0.1) == .probablyBad)
        // Exact boundary: 0.3 should be "somethingWrong", not "probablyBad"
        #expect(ESRQuality.from(esr: 0.3) == .somethingWrong)
    }

    @Test func esrQualityHasComments() {
        for quality in [
            ESRQuality.great,
            .notBad,
            .mightBeOk,
            .probablyBad,
            .somethingWrong,
        ] {
            #expect(!quality.comment.isEmpty)
            #expect(!quality.symbolName.isEmpty)
        }
    }
}
