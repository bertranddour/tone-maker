import Foundation
import SwiftData
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "TrainingEngine")

/// Manages active and queued training sessions, bridging `NAMTrainerService` to the UI.
///
/// The engine processes one `TrainingSession` at a time. Within a session, it iterates
/// the session's `BatchItem`s sequentially, writing per-item state (status, ESR, latency,
/// error) to the `BatchItem` and importing each `.nam` capture as soon as it's produced —
/// so mid-batch cancellation preserves completed work. When a session finishes, the
/// engine auto-advances to the oldest `.queued` session.
@Observable
final class TrainingEngine {

    // MARK: - Observable State

    /// The currently active training session ID, if any.
    private(set) var activeSessionID: UUID?

    /// The ID of the batch item currently being trained, if any.
    private(set) var currentBatchItemID: UUID?

    /// Live log output from the current training process.
    private(set) var logOutput: String = ""

    /// Current epoch number (1-based) for the active batch item. Resets between items.
    private(set) var currentEpoch: Int = 0

    /// Warnings emitted during validation/training, cleared at session start.
    private(set) var warnings: [String] = []

    /// Whether a training process is actively running.
    var isTraining: Bool { activeSessionID != nil }

    // MARK: - Private

    private let service: any TrainingServiceProtocol
    private var trainingTask: Task<Void, Never>?

    init(service: any TrainingServiceProtocol = NAMTrainerService()) {
        self.service = service
    }

    // MARK: - Public API

    /// Starts the session immediately if the engine is idle; otherwise marks it `.queued`
    /// for auto-advance when the current session finishes.
    func enqueueTraining(session: TrainingSession, modelContext: ModelContext) {
        if !isTraining {
            startTraining(session: session, modelContext: modelContext)
        } else {
            logger.info("Queueing session: \(session.displayName)")
            session.status = .queued
            session.queuedAt = Date()
        }
    }

    /// Cancels a session. If active, cancels the underlying Task; the Task's `defer`
    /// clears engine state, marks remaining items `.cancelled`, and advances the queue.
    /// If queued, dequeues immediately. If already terminal, no-op.
    func cancelTraining(session: TrainingSession) {
        logger.info("Cancelling session: \(session.displayName)")
        if activeSessionID == session.id {
            trainingTask?.cancel()
            Task { await service.cancel() }
        } else if session.status == .queued {
            session.status = .cancelled
            session.queuedAt = nil
        }
    }

    /// Cancels the active session and marks every queued session `.cancelled`.
    func cancelAll(modelContext: ModelContext) {
        if let activeID = activeSessionID,
           let active = fetchSession(id: activeID, modelContext: modelContext) {
            trainingTask?.cancel()
            trainingTask = nil
            Task { await service.cancel() }
            active.status = .cancelled
            active.queuedAt = nil
            activeSessionID = nil
            currentBatchItemID = nil
        }
        let queuedRaw = TrainingStatus.queued.rawValue
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.statusRaw == queuedRaw }
        )
        if let queued = try? modelContext.fetch(descriptor) {
            for session in queued {
                session.status = .cancelled
                session.queuedAt = nil
            }
        }
    }

    /// Cancels a single batch item. If it's the running item, terminates its process
    /// (the outer loop advances to the next). If pending, marks it `.skipped`.
    func cancelBatchItem(_ item: BatchItem) {
        if currentBatchItemID == item.id {
            logger.info("Cancelling running batch item: \(item.displayName)")
            item.status = .cancelled
            item.completedAt = Date()
            Task { await service.cancel() }
        } else if item.status == .pending {
            item.status = .skipped
        }
    }

    /// Resets a non-completed item to `.pending` and requeues the parent session if needed.
    func retryBatchItem(_ item: BatchItem, modelContext: ModelContext) {
        guard let session = item.session else { return }
        guard item.status != .completed else { return }
        resetItem(item)
        requeueIfTerminal(session, modelContext: modelContext)
    }

    /// Resets every non-completed item in the session and requeues it.
    func retryFailedItems(in session: TrainingSession, modelContext: ModelContext) {
        for item in session.sortedBatchItems where item.status != .completed {
            resetItem(item)
        }
        requeueIfTerminal(session, modelContext: modelContext)
    }

    // MARK: - Private: Queue

    private func resetItem(_ item: BatchItem) {
        item.status = .pending
        item.validationESR = nil
        item.calibratedLatency = nil
        item.errorMessage = nil
        item.outputModelPath = nil
        item.comparisonPlotPath = nil
        item.startedAt = nil
        item.completedAt = nil
    }

    private func requeueIfTerminal(_ session: TrainingSession, modelContext: ModelContext) {
        let status = session.status
        if status == .completed || status == .failed || status == .cancelled {
            session.status = .queued
            session.queuedAt = Date()
            session.completedAt = nil
            if !isTraining {
                advanceQueue(modelContext: modelContext)
            }
        }
    }

    private func fetchSession(id: UUID, modelContext: ModelContext) -> TrainingSession? {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func advanceQueue(modelContext: ModelContext) {
        guard !isTraining else { return }
        let queuedRaw = TrainingStatus.queued.rawValue
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.statusRaw == queuedRaw },
            sortBy: [SortDescriptor(\.queuedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        guard let next = (try? modelContext.fetch(descriptor))?.first else { return }
        logger.info("Auto-advancing queue to: \(next.displayName)")
        startTraining(session: next, modelContext: modelContext)
    }

    private func startTraining(session: TrainingSession, modelContext: ModelContext) {
        guard !isTraining else {
            logger.warning("Training already in progress, refusing startTraining")
            return
        }
        logger.info("Starting training for session: \(session.displayName)")

        activeSessionID = session.id
        currentBatchItemID = nil
        logOutput = ""
        currentEpoch = 0
        warnings = []

        session.status = .training
        session.queuedAt = nil

        trainingTask = Task { [weak self] in
            await self?.runTraining(session: session, modelContext: modelContext)
        }
    }

    // MARK: - Private: Training Loop

    private func runTraining(session: TrainingSession, modelContext: ModelContext) async {
        var tempURLs: [URL] = []
        var bookmarkURLs: [URL] = []

        defer {
            currentBatchItemID = nil
            activeSessionID = nil
            bookmarkURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            tempURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            advanceQueue(modelContext: modelContext)
        }

        guard let inputResult = resolveFileURL(
            bookmark: session.inputFileBookmark,
            persistedFile: session.persistedInputFile
        ) else {
            session.status = .failed
            session.trainingLog = "Error: Could not access input file. Please re-select it."
            session.completedAt = Date()
            return
        }
        let inputURL = inputResult.url
        if inputResult.isTemp { tempURLs.append(inputURL) } else { bookmarkURLs.append(inputURL) }

        let tempTrainDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToneMaker_\(session.id.uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempTrainDir, withIntermediateDirectories: true)
        } catch {
            session.status = .failed
            session.trainingLog = "Error: Could not create temp directory: \(error.localizedDescription)"
            session.completedAt = Date()
            return
        }
        tempURLs.append(tempTrainDir)

        let items = session.sortedBatchItems
        guard !items.isEmpty else {
            session.status = .failed
            session.trainingLog = "Error: No output files configured for this session."
            session.completedAt = Date()
            return
        }

        let totalItems = items.count
        var itemIndex = 0

        for item in items {
            itemIndex += 1

            if Task.isCancelled {
                if !item.status.isTerminal { item.status = .cancelled }
                continue
            }
            if item.status == .completed { continue }
            if item.status == .skipped { continue }

            item.status = .running
            item.startedAt = Date()
            item.completedAt = nil
            item.errorMessage = nil

            currentBatchItemID = item.id
            currentEpoch = 0

            if totalItems > 1 {
                logOutput += "=== Item \(itemIndex) of \(totalItems): \(item.displayName) ===\n"
            }

            guard let outputResult = resolveFileURL(
                bookmark: item.outputFileBookmark,
                persistedFile: item.persistedOutputFile
            ) else {
                item.status = .failed
                item.errorMessage = "Could not access output file. Please re-select it."
                item.completedAt = Date()
                currentBatchItemID = nil
                continue
            }
            let outputURL = outputResult.url
            if outputResult.isTemp { tempURLs.append(outputURL) } else { bookmarkURLs.append(outputURL) }

            let perItemDir = tempTrainDir.appendingPathComponent(item.id.uuidString)
            do {
                try FileManager.default.createDirectory(at: perItemDir, withIntermediateDirectories: true)
            } catch {
                item.status = .failed
                item.errorMessage = "Could not create per-item directory: \(error.localizedDescription)"
                item.completedAt = Date()
                currentBatchItemID = nil
                continue
            }

            let perItemMetadata = buildItemMetadata(session: session, item: item)

            do {
                let stream = service.train(
                    inputPath: inputURL.path,
                    outputPath: outputURL.path,
                    trainPath: perItemDir.path,
                    session: session,
                    metadata: perItemMetadata
                )
                for try await event in stream {
                    if Task.isCancelled { break }
                    handleEvent(event, session: session, item: item)
                }
            } catch {
                if item.status != .cancelled {
                    item.errorMessage = error.localizedDescription
                    item.status = Task.isCancelled ? .cancelled : .failed
                }
                logOutput += "\nError on item \(itemIndex): \(error.localizedDescription)\n"
            }

            // Post-stream classification
            if Task.isCancelled && item.status != .cancelled {
                item.status = .cancelled
            } else if item.status == .running {
                if let esr = item.validationESR {
                    if esrMeetsThreshold(esr, threshold: session.esrThreshold) {
                        importCapture(for: item, from: perItemDir, into: modelContext)
                        item.status = .completed
                    } else {
                        item.status = .failed
                        if item.errorMessage == nil {
                            item.errorMessage = "ESR \(String(format: "%.4f", esr)) above threshold."
                        }
                    }
                } else {
                    item.status = .failed
                    if item.errorMessage == nil {
                        item.errorMessage = "Training produced no ESR."
                    }
                }
            }

            item.completedAt = Date()
            currentBatchItemID = nil
        }

        session.trainingLog = logOutput
        session.completedAt = Date()

        if Task.isCancelled {
            session.status = .cancelled
        } else if session.allItemsSucceeded {
            session.status = .completed
        } else if session.hasAnyCompletedItem {
            session.status = .completed
        } else {
            session.status = .failed
        }

        logger.info("Session \(session.displayName) finished: \(session.status.displayName)")
    }

    private func esrMeetsThreshold(_ esr: Double, threshold: Double?) -> Bool {
        guard let threshold else { return true }
        return esr <= threshold
    }

    // MARK: - Private: File Resolution

    private func resolveFileURL(bookmark: Data?, persistedFile: PersistedAudioFile?) -> (url: URL, isTemp: Bool)? {
        if let bookmark, let url = FileBookmark.resolveAndAccess(bookmark) {
            return (url, false)
        }
        guard let persisted = persistedFile else { return nil }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_\(persisted.fileName)")
        do {
            try persisted.fileData.write(to: tempURL)
            return (tempURL, true)
        } catch {
            return nil
        }
    }

    // MARK: - Private: Event Handling

    private func handleEvent(_ event: TrainingEvent, session: TrainingSession, item: BatchItem) {
        switch event {
        case .log(let line):
            logOutput += line + "\n"

        case .epochCompleted(let epoch, let total):
            currentEpoch = epoch
            if total > 0 {
                session.epochs = total
            }

        case .esrResult(let esr):
            item.validationESR = esr

        case .latencyDetected(let samples):
            item.calibratedLatency = samples

        case .warning(let message):
            warnings.append(message)

        case .checksPassed:
            logOutput += "[Checks passed]\n"

        case .checksFailed:
            warnings.append("Data checks failed")

        case .trainingStarted:
            // No-op: session.status is already .training when startTraining spawns the task.
            break

        case .trainingCompleted:
            logOutput += "[Training completed]\n"

        case .trainingFailed:
            logOutput += "[Training failed]\n"

        case .exporting(let path):
            item.outputModelPath = path
            let plotPath = URL(fileURLWithPath: path).deletingLastPathComponent()
                .appendingPathComponent("comparison.png").path
            if FileManager.default.fileExists(atPath: plotPath) {
                item.comparisonPlotPath = plotPath
            }
        }
    }

    // MARK: - Private: Capture Import

    private func importCapture(for item: BatchItem, from dir: URL, into context: ModelContext) {
        let namFiles = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "nam" }) ?? []
        guard let namURL = namFiles.first,
              let modelData = try? Data(contentsOf: namURL) else {
            logger.warning("No .nam file produced for item \(item.displayName)")
            return
        }
        let capture = CaptureItem()
        capture.modelFileData = modelData
        capture.modelFileName = namURL.lastPathComponent
        capture.validationESR = item.validationESR
        if let session = item.session {
            capture.architectureRaw = session.modelTypeRaw
            capture.architectureSizeRaw = session.architectureSizeRaw
            if let meta = session.metadata {
                capture.brand = meta.gearMake ?? ""
                capture.model = meta.gearModel ?? ""
                capture.modeledBy = meta.modeledBy ?? ""
                capture.gearType = meta.gearType
                capture.toneType = meta.toneType
                capture.inputLevelDBu = meta.inputLevelDBu
                capture.outputLevelDBu = meta.outputLevelDBu
            }
        }
        capture.name = item.displayName
        capture.sourceSession = item.session
        item.capture = capture
        context.insert(capture)
        logger.info("Imported capture: \(capture.name)")
    }

    // MARK: - Private: Per-Item Metadata

    /// Builds a detached `ModelMetadata` with the item's `captureName` as `namName`,
    /// cloning every other field from the session's metadata. Used so the .nam file
    /// header carries the item's name rather than the session-level name.
    private func buildItemMetadata(session: TrainingSession, item: BatchItem) -> ModelMetadata? {
        let itemName = item.captureName.isEmpty
            ? session.metadata?.namName
            : item.captureName
        guard let sessionMeta = session.metadata else {
            guard let itemName, !itemName.isEmpty else { return nil }
            return ModelMetadata(namName: itemName, gearType: nil, toneType: nil)
        }
        return ModelMetadata(
            namName: itemName,
            modeledBy: sessionMeta.modeledBy,
            gearMake: sessionMeta.gearMake,
            gearModel: sessionMeta.gearModel,
            gearType: sessionMeta.gearType,
            toneType: sessionMeta.toneType,
            inputLevelDBu: sessionMeta.inputLevelDBu,
            outputLevelDBu: sessionMeta.outputLevelDBu
        )
    }
}
