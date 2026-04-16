import Testing
import Foundation
@testable import ToneMaker

struct TrainingSessionTests {

    // MARK: - Default Values

    @Test func defaultsUseWaveNetStandard() {
        let session = TrainingSession()
        #expect(session.modelType == .waveNet)
        #expect(session.architectureSize == .standard)
    }

    @Test func defaultStatusIsConfiguring() {
        let session = TrainingSession()
        #expect(session.status == .configuring)
    }

    @Test func defaultTrainingParameters() {
        let session = TrainingSession()
        #expect(session.epochs == 100)
        #expect(session.learningRate == 0.004)
        #expect(session.learningRateDecay == 0.007)
        #expect(session.batchSize == 16)
        #expect(session.ny == 8192)
        #expect(session.seed == 0)
        #expect(session.savePlot == true)
        #expect(session.fitMRSTFT == true)
        #expect(session.ignoreChecks == false)
    }

    @Test func defaultOptionalFieldsAreNil() {
        let session = TrainingSession()
        #expect(session.latencyOverride == nil)
        #expect(session.esrThreshold == nil)
        #expect(session.validationESR == nil)
        #expect(session.comparisonPlotPath == nil)
        #expect(session.trainingLog == nil)
        #expect(session.inputFileBookmark == nil)
        #expect(session.metadata == nil)
        #expect(session.preset == nil)
    }

    // MARK: - Typed Enum Access

    @Test func statusEnumRoundTrip() {
        let session = TrainingSession()

        session.status = .training
        #expect(session.statusRaw == "training")
        #expect(session.status == .training)

        session.status = .completed
        #expect(session.statusRaw == "completed")
        #expect(session.status == .completed)

        session.status = .failed
        #expect(session.statusRaw == "failed")
        #expect(session.status == .failed)
    }

    @Test func modelTypeEnumRoundTrip() {
        let session = TrainingSession()

        session.modelType = .lstm
        #expect(session.modelTypeRaw == "LSTM")
        #expect(session.modelType == .lstm)

        session.modelType = .waveNet
        #expect(session.modelTypeRaw == "WaveNet")
        #expect(session.modelType == .waveNet)
    }

    @Test func architectureSizeEnumRoundTrip() {
        let session = TrainingSession()

        for size in ArchitectureSize.allCases {
            session.architectureSize = size
            #expect(session.architectureSize == size)
            #expect(session.architectureSizeRaw == size.rawValue)
        }
    }

    @Test func unknownStatusRawFallsBackToConfiguring() {
        let session = TrainingSession()
        session.statusRaw = "invalid_status"
        #expect(session.status == .configuring)
    }

    // MARK: - Display Name

    @Test func displayNameFromOutputFileName() {
        let session = TrainingSession()
        session.outputFileNames = ["MyAmp_Crunch.wav"]
        #expect(session.displayName == "MyAmp_Crunch")
    }

    @Test func displayNameFallsBackToUntitled() {
        let session = TrainingSession()
        #expect(session.displayName == "Untitled Session")
    }

    // MARK: - Batch Training

    @Test func isBatchTrainingDetection() {
        let session = TrainingSession()
        #expect(session.isBatchTraining == false)

        session.outputFileBookmarks = [Data(), Data()]
        #expect(session.isBatchTraining == true)
    }

    @Test func emptyOutputArraysByDefault() {
        let session = TrainingSession()
        #expect(session.outputFileBookmarks.isEmpty)
        #expect(session.outputFileNames.isEmpty)
        #expect(session.outputModelPaths.isEmpty)
    }
}
