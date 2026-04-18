import Foundation
@testable import ToneMaker

/// Scripted recording of what a single `train(...)` call should emit.
struct MockTrainingScript: Sendable {
    var events: [TrainingEvent]
    var throwingError: (any Error)?
    var honoursCancel: Bool = true
    var writeNamFile: Bool = true
}

/// Test double for `TrainingServiceProtocol` that replays pre-scripted streams.
///
/// Each `train(...)` call consumes the next enqueued script. If the script
/// contains an `.exporting(path:)` event, a stub `.nam` file is written to
/// the training directory so `importCapture` succeeds.
actor MockTrainerService: TrainingServiceProtocol {

    private var scripts: [MockTrainingScript] = []
    private(set) var callCount: Int = 0
    private var cancelRequested: Bool = false

    func setScripts(_ scripts: [MockTrainingScript]) {
        self.scripts = scripts
        self.callCount = 0
        self.cancelRequested = false
    }

    func wasCancelled() -> Bool { cancelRequested }

    nonisolated func train(
        inputPath: String,
        outputPath: String,
        trainPath: String,
        session: TrainingSession,
        metadata: ModelMetadata?
    ) -> AsyncThrowingStream<TrainingEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                guard let script = await self.nextScript() else {
                    continuation.finish()
                    return
                }
                if script.writeNamFile && script.throwingError == nil {
                    let namURL = URL(fileURLWithPath: trainPath).appendingPathComponent("mock.nam")
                    try? Data([0xDE, 0xAD, 0xBE, 0xEF]).write(to: namURL)
                }
                if let error = script.throwingError {
                    continuation.finish(throwing: error)
                    return
                }
                for event in script.events {
                    if script.honoursCancel, await self.wasCancelled() {
                        continuation.finish()
                        return
                    }
                    continuation.yield(event)
                    await Task.yield()
                }
                continuation.finish()
            }
        }
    }

    func cancel() async {
        cancelRequested = true
    }

    // MARK: - Private

    private func nextScript() -> MockTrainingScript? {
        callCount += 1
        cancelRequested = false
        guard !scripts.isEmpty else { return nil }
        return scripts.removeFirst()
    }
}
