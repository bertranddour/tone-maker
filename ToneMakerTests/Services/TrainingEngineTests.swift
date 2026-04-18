import Testing
import Foundation
import SwiftData
@testable import ToneMaker

@MainActor
struct TrainingEngineTests {

    // MARK: - Helpers

    /// Retains every piece the test needs: container, engine, mock, and a fresh
    /// `ModelContext`. Using an explicit context (not `container.mainContext`) and
    /// keeping the container in scope avoids ARC tearing down the container while
    /// the context still references it — otherwise the first `insert` crashes.
    private final class TestEnv {
        let container: ModelContainer
        let engine: TrainingEngine
        let mock: MockTrainerService
        let context: ModelContext
        init(container: ModelContainer, engine: TrainingEngine, mock: MockTrainerService) {
            self.container = container
            self.engine = engine
            self.mock = mock
            self.context = ModelContext(container)
        }
    }

    private func makeEnv(scripts: [MockTrainingScript] = []) async throws -> TestEnv {
        let container = try makeTestModelContainer()
        let mock = MockTrainerService()
        await mock.setScripts(scripts)
        let engine = TrainingEngine(service: mock)
        return TestEnv(container: container, engine: engine, mock: mock)
    }

    /// Creates a session pre-configured with persisted input + N batch items (each with
    /// a persisted output file) so the engine's file resolution bypasses bookmarks.
    private func makeSession(
        in context: ModelContext,
        itemCount: Int,
        itemNames: [String]? = nil
    ) -> TrainingSession {
        let session = TrainingSession()
        context.insert(session)

        let input = PersistedAudioFile(fileName: "input.wav", role: .input, fileData: Data([0x01, 0x02]))
        context.insert(input)
        session.persistedAudioFiles = [input]

        for i in 0..<itemCount {
            let name = itemNames?[i] ?? "capture\(i).wav"
            let item = BatchItem(order: i, outputFileName: name, captureName: "Capture \(i)")
            item.session = session

            let output = PersistedAudioFile(fileName: name, role: .output, fileData: Data([0x0A, 0x0B]))
            item.persistedOutputFile = output

            context.insert(item)
            context.insert(output)
            session.batchItems = (session.batchItems ?? []) + [item]
        }
        return session
    }

    private func waitForCompletion(_ engine: TrainingEngine) async {
        while engine.isTraining {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func successScript(esr: Double, latency: Int = 42) -> MockTrainingScript {
        MockTrainingScript(events: [
            .trainingStarted,
            .epochCompleted(epoch: 1, totalEpochs: 1),
            .latencyDetected(samples: latency),
            .esrResult(esr),
            .exporting(path: "/tmp/ignored"),
            .trainingCompleted,
        ])
    }

    // MARK: - Initial State

    @Test func initialStateIsInactive() async throws {
        let env = try await makeEnv()
        #expect(env.engine.isTraining == false)
    #expect(env.engine.activeSessionID == nil)
        #expect(env.engine.currentBatchItemID == nil)
        #expect(env.engine.logOutput.isEmpty)
        #expect(env.engine.currentEpoch == 0)
        #expect(env.engine.warnings.isEmpty)
    }

    // MARK: - Cancel Queued Session

    @Test func cancelMarksQueuedSessionCancelled() async throws {
        let env = try await makeEnv()
        let session = makeSession(in: env.context, itemCount: 1)
        session.status = .queued
        session.queuedAt = Date()

        env.engine.cancelTraining(session: session)

        #expect(session.status == .cancelled)
        #expect(session.queuedAt == nil)
    }

    // MARK: - Batch: Processes Items In Order with Per-Item ESR/Latency

    @Test func processesItemsInOrderStoringPerItemResults() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01, latency: 10),
            successScript(esr: 0.05, latency: 20),
            successScript(esr: 0.09, latency: 30),
        ])
        let session = makeSession(in: env.context, itemCount: 3)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let items = session.sortedBatchItems
        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.status == .completed })
        #expect(items[0].validationESR == 0.01)
        #expect(items[1].validationESR == 0.05)
        #expect(items[2].validationESR == 0.09)
        #expect(items[0].calibratedLatency == 10)
        #expect(items[1].calibratedLatency == 20)
        #expect(items[2].calibratedLatency == 30)
        #expect(session.bestValidationESR == 0.01)
        #expect(session.status == .completed)
    }

    // MARK: - Batch: Continues After Item Failure

    @Test func continuesAfterItemFailure() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            MockTrainingScript(events: [.trainingFailed], throwingError: nil, writeNamFile: false),
            successScript(esr: 0.03),
        ])
        let session = makeSession(in: env.context, itemCount: 3)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let items = session.sortedBatchItems
        #expect(items[0].status == .completed)
        #expect(items[1].status == .failed)
        #expect(items[2].status == .completed)
        #expect(session.status == .completed)
        #expect(session.hasAnyCompletedItem == true)
        #expect(session.allItemsSucceeded == false)
    }

    // MARK: - Per-Item Capture Import

    @Test func importsCapturePerCompletedItem() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            successScript(esr: 0.02),
        ])
        let session = makeSession(in: env.context, itemCount: 2)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let captures = try env.context.fetch(FetchDescriptor<CaptureItem>())
        #expect(captures.count == 2)

        let items = session.sortedBatchItems
        #expect(items[0].capture != nil)
        #expect(items[1].capture != nil)
        #expect(items[0].capture?.validationESR == 0.01)
        #expect(items[1].capture?.validationESR == 0.02)
    }

    // MARK: - Per-Item Capture Naming

    @Test func captureNameAppliedPerItem() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            successScript(esr: 0.02),
        ])
        let session = makeSession(in: env.context, itemCount: 2)
        session.sortedBatchItems[0].captureName = "Mesa Clean"
        session.sortedBatchItems[1].captureName = "Mesa Crunch"

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let items = session.sortedBatchItems
        #expect(items[0].capture?.name == "Mesa Clean")
        #expect(items[1].capture?.name == "Mesa Crunch")
    }

    // MARK: - Epoch Reset Between Items

    @Test func epochResetsBetweenItems() async throws {
        let env = try await makeEnv(scripts: [
            MockTrainingScript(events: [.epochCompleted(epoch: 100, totalEpochs: 100), .esrResult(0.01), .exporting(path: "x")]),
            MockTrainingScript(events: [.epochCompleted(epoch: 1, totalEpochs: 100), .esrResult(0.02), .exporting(path: "y")]),
        ])
        let session = makeSession(in: env.context, itemCount: 2)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        // After all items, currentEpoch reflects last item's final epoch (1) —
        // important: it was reset to 0 before item 2 started so item 1's 100 doesn't bleed through.
        #expect(env.engine.currentEpoch == 1)
    }

    // MARK: - Retry Failed Items

    @Test func retryFailedItemsResetsFailedOnly() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            MockTrainingScript(events: [], throwingError: NSError(domain: "Mock", code: 1), writeNamFile: false),
        ])
        let session = makeSession(in: env.context, itemCount: 2)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        #expect(session.sortedBatchItems[0].status == .completed)
        #expect(session.sortedBatchItems[1].status == .failed)

        await env.mock.setScripts([successScript(esr: 0.02)])
        env.engine.retryFailedItems(in: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let items = session.sortedBatchItems
        #expect(items[0].status == .completed)
        #expect(items[0].validationESR == 0.01)
        #expect(items[1].status == .completed)
        #expect(items[1].validationESR == 0.02)
    }

    // MARK: - Retry Single Item

    @Test func retryBatchItemRequeuesSession() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            MockTrainingScript(events: [], throwingError: NSError(domain: "Mock", code: 1), writeNamFile: false),
        ])
        let session = makeSession(in: env.context, itemCount: 2)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        let failed = session.sortedBatchItems[1]
        #expect(failed.status == .failed)

        await env.mock.setScripts([successScript(esr: 0.02)])
        env.engine.retryBatchItem(failed, modelContext: env.context)
        await waitForCompletion(env.engine)

        #expect(failed.status == .completed)
        #expect(failed.validationESR == 0.02)
    }

    // MARK: - Queue: Auto-Advance

    @Test func enqueueWhenBusyQueuesAndAutoAdvances() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            successScript(esr: 0.02),
        ])
        let sessionA = makeSession(in: env.context, itemCount: 1)
        sessionA.sessionName = "A"
        let sessionB = makeSession(in: env.context, itemCount: 1)
        sessionB.sessionName = "B"

        env.engine.enqueueTraining(session: sessionA, modelContext: env.context)
        env.engine.enqueueTraining(session: sessionB, modelContext: env.context)

        #expect(sessionB.status == .queued)
        #expect(sessionB.queuedAt != nil)

        await waitForCompletion(env.engine)

        #expect(sessionA.status == .completed)
        #expect(sessionB.status == .completed)
        #expect(sessionB.queuedAt == nil)
    }

    // MARK: - Queue: Cancel All

    @Test func cancelAllStopsActiveAndClearsQueue() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            successScript(esr: 0.02),
        ])
        let sessionA = makeSession(in: env.context, itemCount: 1)
        let sessionB = makeSession(in: env.context, itemCount: 1)

        env.engine.enqueueTraining(session: sessionA, modelContext: env.context)
        env.engine.enqueueTraining(session: sessionB, modelContext: env.context)
        #expect(sessionB.status == .queued)

        env.engine.cancelAll(modelContext: env.context)

        #expect(sessionA.status == .cancelled)
        #expect(sessionB.status == .cancelled)
        #expect(sessionB.queuedAt == nil)
    }

    // MARK: - Queue: Cancel Single Queued Session

    @Test func cancelQueuedDoesNotAffectActive() async throws {
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            successScript(esr: 0.02),
        ])
        let sessionA = makeSession(in: env.context, itemCount: 1)
        let sessionB = makeSession(in: env.context, itemCount: 1)

        env.engine.enqueueTraining(session: sessionA, modelContext: env.context)
        env.engine.enqueueTraining(session: sessionB, modelContext: env.context)

        env.engine.cancelTraining(session: sessionB)
        #expect(sessionB.status == .cancelled)

        await waitForCompletion(env.engine)
        #expect(sessionA.status == .completed)
    }

    // MARK: - Per-Item Cancel: Running Item Continues to Next

    @Test func cancelRunningBatchItemContinuesToNextItem() async throws {
        let stalling = MockTrainingScript(
            events: Array(repeating: .log("stalling"), count: 10_000),
            throwingError: nil,
            honoursCancel: true,
            writeNamFile: false
        )
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            stalling,
            successScript(esr: 0.03),
        ])
        let session = makeSession(in: env.context, itemCount: 3)
        env.engine.enqueueTraining(session: session, modelContext: env.context)

        while env.engine.currentBatchItemID != session.sortedBatchItems[1].id {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        env.engine.cancelBatchItem(session.sortedBatchItems[1])
        await waitForCompletion(env.engine)

        let items = session.sortedBatchItems
        #expect(items[0].status == .completed)
        #expect(items[1].status == .cancelled)
        #expect(items[2].status == .completed)
    }

    // MARK: - Per-Item Cancel: Pending Item Marked Skipped

    @Test func cancelPendingBatchItemMarksSkipped() async throws {
        let stalling = MockTrainingScript(
            events: Array(repeating: .log("stalling"), count: 10_000),
            throwingError: nil,
            honoursCancel: true,
            writeNamFile: false
        )
        let env = try await makeEnv(scripts: [stalling, stalling])
        let session = makeSession(in: env.context, itemCount: 2)
        env.engine.enqueueTraining(session: session, modelContext: env.context)

        while env.engine.currentBatchItemID != session.sortedBatchItems[0].id {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        env.engine.cancelBatchItem(session.sortedBatchItems[1])
        #expect(session.sortedBatchItems[1].status == .skipped)

        env.engine.cancelBatchItem(session.sortedBatchItems[0])
        await waitForCompletion(env.engine)

        #expect(session.sortedBatchItems[1].status == .skipped)
    }

    // MARK: - Mid-Batch Session Cancel Preserves Completed Captures

    @Test func cancelMidBatchPreservesCompletedCaptures() async throws {
        let stalling = MockTrainingScript(
            events: Array(repeating: .log("stalling"), count: 10_000),
            throwingError: nil,
            honoursCancel: true,
            writeNamFile: false
        )
        let env = try await makeEnv(scripts: [
            successScript(esr: 0.01),
            stalling,
            successScript(esr: 0.03),
        ])
        let session = makeSession(in: env.context, itemCount: 3)
        env.engine.enqueueTraining(session: session, modelContext: env.context)

        while env.engine.currentBatchItemID != session.sortedBatchItems[1].id {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        env.engine.cancelTraining(session: session)
        await waitForCompletion(env.engine)

        let captures = try env.context.fetch(FetchDescriptor<CaptureItem>())
        #expect(captures.count == 1)
        let items = session.sortedBatchItems
        #expect(items[0].status == .completed)
        #expect(items[0].capture != nil)
        #expect(items[1].status == .cancelled)
        #expect(items[2].status == .cancelled)
    }

    // MARK: - Logs and Warnings

    @Test func warningEventsAccumulate() async throws {
        let env = try await makeEnv(scripts: [
            MockTrainingScript(events: [.warning("watch out"), .esrResult(0.01), .exporting(path: "x")]),
        ])
        let session = makeSession(in: env.context, itemCount: 1)

        env.engine.enqueueTraining(session: session, modelContext: env.context)
        await waitForCompletion(env.engine)

        #expect(env.engine.warnings.contains("watch out"))
    }
}
