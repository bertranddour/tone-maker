import Foundation

/// Output from a running subprocess.
nonisolated enum ProcessOutput: Sendable {
    case stdout(String)
    case stderr(String)
    case terminated(exitCode: Int32)
}

/// Error from the process runner.
nonisolated enum ProcessRunnerError: Error, LocalizedError, Sendable {
    case executableNotFound(URL)
    case launchFailed(String)
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let url):
            "Executable not found at \(url.path)"
        case .launchFailed(let message):
            "Failed to launch process: \(message)"
        case .alreadyRunning:
            "A process is already running"
        }
    }
}

/// Generic async subprocess wrapper with real-time line streaming.
///
/// Uses `readabilityHandler` (dispatch source callback) for truly real-time
/// output delivery. `FileHandle.AsyncBytes` has internal buffering that
/// prevents real-time streaming from pipes.
///
/// Splits on both `\n` and `\r` so PyTorch Lightning tqdm progress bars
/// (which use `\r` to overwrite lines) emit per-epoch updates.
actor ProcessRunner {

    private var process: Process?

    /// Whether a process is currently running.
    var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// Runs a subprocess and streams its output line by line in real-time.
    func run(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil
    ) throws -> AsyncThrowingStream<ProcessOutput, any Error> {
        guard process == nil || process?.isRunning == false else {
            throw ProcessRunnerError.alreadyRunning
        }

        let proc = Process()
        proc.executableURL = executableURL
        proc.arguments = arguments

        if let environment {
            proc.environment = environment
        }
        if let workingDirectory {
            proc.currentDirectoryURL = workingDirectory
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        self.process = proc

        return AsyncThrowingStream { continuation in
            // Line buffers that split on \r and \n, emitting each segment immediately
            let stdoutBuffer = LineBuffer { line in
                continuation.yield(.stdout(line))
            }
            let stderrBuffer = LineBuffer { line in
                continuation.yield(.stderr(line))
            }

            // readabilityHandler fires via dispatch source whenever data is available.
            // This is truly real-time - unlike FileHandle.AsyncBytes which buffers.
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF - pipe closed
                    stdoutBuffer.flush()
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                } else {
                    stdoutBuffer.append(data)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    stderrBuffer.flush()
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                } else {
                    stderrBuffer.append(data)
                }
            }

            proc.terminationHandler = { [stdoutBuffer, stderrBuffer] proc in
                // Give a tiny delay for final readabilityHandler callbacks to fire
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    stdoutBuffer.flush()
                    stderrBuffer.flush()
                    continuation.yield(.terminated(exitCode: proc.terminationStatus))
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                if proc.isRunning {
                    proc.terminate()
                }
            }

            do {
                try proc.run()
            } catch {
                continuation.finish(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
            }
        }
    }

    /// Terminates the currently running process, if any.
    func terminate() {
        guard let process, process.isRunning else { return }
        process.terminate()
    }

    /// Sends an interrupt signal (SIGINT) to the running process.
    func interrupt() {
        guard let process, process.isRunning else { return }
        process.interrupt()
    }
}

// MARK: - Line Buffer

/// Thread-safe buffer that accumulates bytes and emits lines split on `\r` or `\n`.
///
/// Critical for PyTorch Lightning's tqdm progress which uses `\r` (carriage return)
/// to overwrite the progress bar each epoch. Without splitting on `\r`, the entire
/// training loop appears as one line that only arrives at EOF.
private nonisolated final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        emitLines()
        lock.unlock()
    }

    func flush() {
        lock.lock()
        if !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onLine(trimmed)
            }
            buffer.removeAll()
        }
        lock.unlock()
    }

    /// Scans buffer for `\n` or `\r` delimiters and emits each segment.
    private func emitLines() {
        while true {
            // Find first \n or \r in buffer
            guard let delimIndex = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) else {
                break
            }

            let lineData = buffer[buffer.startIndex..<delimIndex]
            let delimByte = buffer[delimIndex]

            // Skip \r\n sequence (consume both)
            var nextIndex = buffer.index(after: delimIndex)
            if delimByte == 0x0D, nextIndex < buffer.endIndex, buffer[nextIndex] == 0x0A {
                nextIndex = buffer.index(after: nextIndex)
            }

            buffer = Data(buffer[nextIndex...])

            if !lineData.isEmpty, let line = String(data: lineData, encoding: .utf8) {
                onLine(line)
            }
        }
    }
}
