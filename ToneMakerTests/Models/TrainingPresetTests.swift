import Testing
import Foundation
@testable import ToneMaker

struct TrainingPresetTests {

    // MARK: - Default Values

    @Test func defaultValues() {
        let preset = TrainingPreset(name: "Test")
        #expect(preset.name == "Test")
        #expect(preset.modelType == .waveNet)
        #expect(preset.architectureSize == .standard)
        #expect(preset.epochs == 100)
        #expect(preset.learningRate == 0.004)
        #expect(preset.learningRateDecay == 0.007)
        #expect(preset.batchSize == 16)
        #expect(preset.ny == 8192)
        #expect(preset.seed == 0)
        #expect(preset.fitMRSTFT == true)
    }

    // MARK: - Enum Accessors

    @Test func modelTypeRoundTrip() {
        let preset = TrainingPreset(name: "Test", modelType: .lstm)
        #expect(preset.modelType == .lstm)
        #expect(preset.modelTypeRaw == "LSTM")
    }

    @Test func architectureSizeRoundTrip() {
        let preset = TrainingPreset(name: "Test", architectureSize: .feather)
        #expect(preset.architectureSize == .feather)
        #expect(preset.architectureSizeRaw == "feather")
    }

    // MARK: - Factory

    @Test func fromSessionCopiesParameters() {
        let session = TrainingSession(
            modelType: .lstm,
            architectureSize: .lite,
            epochs: 400,
            learningRate: 0.01,
            learningRateDecay: 0.05,
            batchSize: 8,
            ny: 4096,
            seed: 42,
            fitMRSTFT: false
        )

        let preset = TrainingPreset.from(session: session, name: "My Preset")

        #expect(preset.name == "My Preset")
        #expect(preset.modelType == .lstm)
        #expect(preset.architectureSize == .lite)
        #expect(preset.epochs == 400)
        #expect(preset.learningRate == 0.01)
        #expect(preset.learningRateDecay == 0.05)
        #expect(preset.batchSize == 8)
        #expect(preset.ny == 4096)
        #expect(preset.seed == 42)
        #expect(preset.fitMRSTFT == false)
    }

    // MARK: - Apply

    @Test func applyToSessionSetsParameters() {
        let preset = TrainingPreset(
            name: "Fast",
            modelType: .lstm,
            architectureSize: .nano,
            epochs: 200,
            learningRate: 0.01,
            batchSize: 32
        )

        let session = TrainingSession()
        preset.apply(to: session)

        #expect(session.modelType == .lstm)
        #expect(session.architectureSize == .nano)
        #expect(session.epochs == 200)
        #expect(session.learningRate == 0.01)
        #expect(session.batchSize == 32)
    }
}
