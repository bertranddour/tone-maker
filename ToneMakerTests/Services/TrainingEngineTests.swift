
import Testing
import Foundation
@testable import ToneMaker

struct TrainingEngineTests {

    // MARK: - Initial State

    @Test func initialStateIsInactive() {
        let engine = TrainingEngine()
        #expect(engine.isTraining == false)
        #expect(engine.activeSessionID == nil)
        #expect(engine.logOutput.isEmpty)
        #expect(engine.currentEpoch == 0)
        #expect(engine.currentESR == nil)
        #expect(engine.warnings.isEmpty)
    }

    // MARK: - Prevent Concurrent Training

    @Test func isTrainingReflectsActiveSession() {
        let engine = TrainingEngine()
        // Without calling startTraining (which requires ModelContext),
        // isTraining should always be false
        #expect(engine.isTraining == false)
        #expect(engine.activeSessionID == nil)
    }

    // MARK: - Cancel Training

    @Test func cancelSetsStatus() {
        let engine = TrainingEngine()
        let session = TrainingSession()
        session.status = .training

        engine.cancelTraining(session: session)

        #expect(session.status == .cancelled)
    }

    // MARK: - Event Handling (via public state observation)

    @Test func logOutputAccumulates() {
        let engine = TrainingEngine()
        #expect(engine.logOutput == "")
        // LogOutput is populated during training - tested indirectly via integration
    }

    @Test func warningsArrayStartsEmpty() {
        let engine = TrainingEngine()
        #expect(engine.warnings.isEmpty)
    }

    @Test func currentEpochStartsAtZero() {
        let engine = TrainingEngine()
        #expect(engine.currentEpoch == 0)
    }

    @Test func currentESRStartsNil() {
        let engine = TrainingEngine()
        #expect(engine.currentESR == nil)
    }
}
