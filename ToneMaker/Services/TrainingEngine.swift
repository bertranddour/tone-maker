import Foundation
import SwiftData
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "TrainingEngine")

/// Manages active training sessions, bridging `NAMTrainerService` to the UI.
///
/// This is the only `@Observable` class in the app (besides SwiftData `@Model` classes).
/// Views observe this for live training state; persistent data lives in `TrainingSession`.
@Observable
final class TrainingEngine {

    // MARK: - Observable State

    /// The currently active training session ID, if any.
    private(set) var activeSessionID: UUID?

    /// Live log output from the current training process.
    private(set) var logOutput: String = ""

    /// Current epoch number (1-based).
    private(set) var currentEpoch: Int = 0

    /// Most recent ESR value from training output.
    private(set) var currentESR: Double?

    /// Warnings emitted during validation/training.
    private(set) var warnings: [String] = []

    /// Whether a training process is actively running.
    var isTraining: Bool { activeSessionID != nil }

    // MARK: - Private

    private let service = NAMTrainerService()
    private var trainingTask: Task<Void, Never>?

    // MARK: - Training Control

    /// Starts training for a session.
    ///
    /// Resolves file bookmarks, then runs training for each output file (batch support).
    /// Updates the session's status and results in the model context.
    func startTraining(session: TrainingSession, modelContext: ModelContext) {
        guard !isTraining else {
            logger.warning("Training already in progress, ignoring start request")
            return
        }
        logger.info("Starting training for session: \(session.displayName)")

        activeSessionID = session.id
        logOutput = ""
        currentEpoch = 0
        currentESR = nil
        warnings = []

        session.status = .training

        trainingTask = Task {
            await runTraining(session: session, modelContext: modelContext)
        }
    }

    /// Cancels the currently running training.
    func cancelTraining(session: TrainingSession) {
        logger.info("Cancelling training for session: \(session.displayName)")
        trainingTask?.cancel()
        trainingTask = nil

        Task {
            await service.cancel()
        }

        session.status = .cancelled
        activeSessionID = nil
    }

    // MARK: - Private Training Logic

    private func runTraining(session: TrainingSession, modelContext: ModelContext) async {
        var tempURLs: [URL] = []
        var bookmarkURLs: [URL] = []

        defer {
            bookmarkURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            tempURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        // Resolve input file
        guard let inputResult = resolveFileURL(
            bookmark: session.inputFileBookmark,
            persistedFile: session.persistedInputFile
        ) else {
            session.status = .failed
            session.trainingLog = "Error: Could not access input file. Please re-select it."
            activeSessionID = nil
            return
        }
        let inputURL = inputResult.url
        if inputResult.isTemp { tempURLs.append(inputURL) } else { bookmarkURLs.append(inputURL) }

        // Create temp directory for training output
        let tempTrainDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToneMaker_\(session.id.uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempTrainDir, withIntermediateDirectories: true)
        } catch {
            session.status = .failed
            session.trainingLog = "Error: Could not create temp directory: \(error.localizedDescription)"
            activeSessionID = nil
            return
        }
        tempURLs.append(tempTrainDir)

        // Resolve all output files
        let persistedOutputs = session.persistedOutputFiles
        var outputURLs: [URL] = []
        for (index, bookmark) in session.outputFileBookmarks.enumerated() {
            let persisted = index < persistedOutputs.count ? persistedOutputs[index] : nil
            if let result = resolveFileURL(bookmark: bookmark, persistedFile: persisted) {
                outputURLs.append(result.url)
                if result.isTemp { tempURLs.append(result.url) } else { bookmarkURLs.append(result.url) }
            }
        }

        guard !outputURLs.isEmpty else {
            session.status = .failed
            session.trainingLog = "Error: Could not access output audio files. Please re-select them."
            activeSessionID = nil
            return
        }

        // Train each output file sequentially (batch training)
        let totalFiles = outputURLs.count
        var allSucceeded = true

        for (index, outputURL) in outputURLs.enumerated() {
            if Task.isCancelled { break }

            if totalFiles > 1 {
                let header = "=== Training file \(index + 1) of \(totalFiles): \(outputURL.lastPathComponent) ===\n"
                logOutput += header
            }

            let stream = service.train(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                trainPath: tempTrainDir.path,
                session: session,
                metadata: session.metadata
            )

            do {
                for try await event in stream {
                    if Task.isCancelled { break }
                    handleEvent(event, session: session)
                }
            } catch {
                logOutput += "\nError: \(error.localizedDescription)\n"
                allSucceeded = false
            }
        }

        // Finalize
        session.trainingLog = logOutput
        session.completedAt = Date()

        if Task.isCancelled {
            logger.info("Training cancelled")
            session.status = .cancelled
        } else if allSucceeded && session.validationESR != nil {
            // Import .nam files from temp directory into library
            let namFiles = (try? FileManager.default.contentsOfDirectory(
                at: tempTrainDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "nam" }) ?? []

            for namURL in namFiles {
                if let modelData = try? Data(contentsOf: namURL) {
                    let capture = CaptureItem()
                    capture.modelFileData = modelData
                    capture.modelFileName = namURL.lastPathComponent
                    capture.validationESR = session.validationESR
                    capture.architectureRaw = session.modelTypeRaw
                    capture.architectureSizeRaw = session.architectureSizeRaw
                    if let meta = session.metadata {
                        capture.name = meta.namName ?? ""
                        capture.brand = meta.gearMake ?? ""
                        capture.model = meta.gearModel ?? ""
                        capture.modeledBy = meta.modeledBy ?? ""
                        capture.gearType = meta.gearType
                        capture.toneType = meta.toneType
                        capture.inputLevelDBu = meta.inputLevelDBu
                        capture.outputLevelDBu = meta.outputLevelDBu
                    }
                    capture.sourceSession = session
                    modelContext.insert(capture)
                    logger.info("Imported capture: \(namURL.lastPathComponent)")
                }
            }
            logger.info("Training completed with ESR \(session.validationESR ?? 0), imported \(namFiles.count) capture(s)")
            session.status = .completed
        } else {
            logger.error("Training failed (succeeded=\(allSucceeded), ESR=\(session.validationESR.map { String($0) } ?? "nil"))")
            session.status = .failed
        }

        activeSessionID = nil
    }

    /// Resolves a file for training: tries bookmark first, falls back to persisted data via temp file.
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

    private func handleEvent(_ event: TrainingEvent, session: TrainingSession) {
        switch event {
        case .log(let line):
            logOutput += line + "\n"

        case .epochCompleted(let epoch, let total):
            currentEpoch = epoch
            if total > 0 {
                session.epochs = total // Update if we learn the actual total
            }

        case .esrResult(let esr):
            currentESR = esr
            session.validationESR = esr

        case .latencyDetected(let samples):
            session.calibratedLatency = samples

        case .warning(let message):
            warnings.append(message)

        case .checksPassed:
            logOutput += "[Checks passed]\n"

        case .checksFailed:
            warnings.append("Data checks failed")

        case .trainingStarted:
            session.status = .training

        case .trainingCompleted:
            logOutput += "[Training completed]\n"

        case .trainingFailed:
            logOutput += "[Training failed]\n"

        case .exporting(let path):
            session.outputModelPaths.append(path)
            // Check for comparison plot alongside the model
            let plotPath = URL(fileURLWithPath: path).deletingLastPathComponent()
                .appendingPathComponent("comparison.png").path
            if FileManager.default.fileExists(atPath: plotPath) {
                session.comparisonPlotPath = plotPath
            }
        }
    }
}
