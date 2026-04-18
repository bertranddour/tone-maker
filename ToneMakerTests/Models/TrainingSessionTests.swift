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
        #expect(session.trainingLog == nil)
        #expect(session.inputFileBookmark == nil)
        #expect(session.metadata == nil)
        #expect(session.preset == nil)
        #expect(session.queuedAt == nil)
    }

    // MARK: - Typed Enum Access

    @Test func statusEnumRoundTrip() {
        let session = TrainingSession()

        for status in [TrainingStatus.configuring, .queued, .validating, .training, .completed, .failed, .cancelled] {
            session.status = status
            #expect(session.statusRaw == status.rawValue)
            #expect(session.status == status)
        }
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

    @Test func displayNameFromFirstBatchItem() {
        let session = TrainingSession()
        let item = BatchItem(order: 0, outputFileName: "MyAmp_Crunch.wav")
        item.session = session
        session.batchItems = [item]

        #expect(session.displayName == "MyAmp_Crunch")
    }

    @Test func displayNameFallsBackToUntitled() {
        let session = TrainingSession()
        #expect(session.displayName == "Untitled Session")
    }

    @Test func displayNamePrefersSessionName() {
        let session = TrainingSession()
        session.sessionName = "My Rig"
        let item = BatchItem(order: 0, outputFileName: "anything.wav")
        session.batchItems = [item]
        #expect(session.displayName == "My Rig")
    }

    // MARK: - Batch Training

    @Test func isBatchTrainingFalseWhenSingleOrZero() {
        let session = TrainingSession()
        #expect(session.isBatchTraining == false)

        session.batchItems = [BatchItem()]
        #expect(session.isBatchTraining == false)
    }

    @Test func isBatchTrainingTrueWhenTwoOrMore() {
        let session = TrainingSession()
        session.batchItems = [BatchItem(), BatchItem()]
        #expect(session.isBatchTraining == true)
    }

    @Test func sortedBatchItemsOrdered() {
        let session = TrainingSession()
        let a = BatchItem(order: 2, outputFileName: "a.wav")
        let b = BatchItem(order: 0, outputFileName: "b.wav")
        let c = BatchItem(order: 1, outputFileName: "c.wav")
        session.batchItems = [a, b, c]

        let sorted = session.sortedBatchItems
        #expect(sorted.map(\.outputFileName) == ["b.wav", "c.wav", "a.wav"])
    }

    @Test func bestValidationESRReturnsMinimum() {
        let session = TrainingSession()
        let a = BatchItem(order: 0); a.validationESR = 0.05
        let b = BatchItem(order: 1); b.validationESR = 0.01
        let c = BatchItem(order: 2); c.validationESR = 0.1
        session.batchItems = [a, b, c]

        #expect(session.bestValidationESR == 0.01)
    }

    @Test func bestValidationESRIgnoresNilValues() {
        let session = TrainingSession()
        let a = BatchItem(order: 0); a.validationESR = 0.05
        let b = BatchItem(order: 1) // nil
        session.batchItems = [a, b]

        #expect(session.bestValidationESR == 0.05)
    }

    @Test func bestValidationESRNilWhenNoItems() {
        let session = TrainingSession()
        #expect(session.bestValidationESR == nil)
    }

    @Test func allItemsSucceededRequiresCompletedItems() {
        let session = TrainingSession()
        #expect(session.allItemsSucceeded == false)  // empty

        let a = BatchItem(order: 0); a.status = .completed
        let b = BatchItem(order: 1); b.status = .completed
        session.batchItems = [a, b]
        #expect(session.allItemsSucceeded == true)

        b.status = .failed
        #expect(session.allItemsSucceeded == false)
    }

    @Test func hasAnyCompletedItem() {
        let session = TrainingSession()
        #expect(session.hasAnyCompletedItem == false)

        let a = BatchItem(order: 0); a.status = .failed
        let b = BatchItem(order: 1); b.status = .completed
        session.batchItems = [a, b]
        #expect(session.hasAnyCompletedItem == true)
    }

    // MARK: - Queue State

    @Test func queuedStatusIsActive() {
        #expect(TrainingStatus.queued.isActive == true)
    }
}
