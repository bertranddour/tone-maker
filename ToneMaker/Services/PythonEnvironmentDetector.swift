import Foundation

/// Detected Python environment configuration for running NAM.
nonisolated struct PythonEnvironment: Sendable {
    /// Path to the python3 executable (typically inside a .venv).
    let pythonPath: URL
    /// Path to the NAM-Trainer project root.
    let projectRoot: URL?

    /// Builds the command to invoke Python with inline code via `-c`.
    func buildPythonCommand(code: String, arguments: [String]) -> (executable: URL, args: [String], environment: [String: String]) {
        let env = PythonEnvironmentDetector.environmentWithUserPath()
        return (
            executable: pythonPath,
            args: ["-c", code] + arguments,
            environment: env
        )
    }
}

/// Detects the Python environment and NAM installation.
///
/// Strategy: find the project's `.venv/bin/python3` directly. This is the most
/// reliable approach because it doesn't depend on `uv run` properly activating
/// the venv for arbitrary commands.
///
/// Search order:
/// 1. NAM-Trainer project `.venv/bin/python3` (preferred - has all deps installed)
/// 2. Well-known executable locations for nam-full, python3
nonisolated struct PythonEnvironmentDetector: Sendable {

    /// Searches common locations for a NAM-Trainer project directory.
    static var defaultNAMTrainerPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Developer/NAM-Trainer"),
            home.appendingPathComponent("Projects/NAM-Trainer"),
            home.appendingPathComponent("Code/NAM-Trainer"),
            home.appendingPathComponent("NAM-Trainer"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("pyproject.toml").path) }
            ?? candidates[0]
    }

    /// Attempts to detect a working Python environment for NAM.
    static func detect(
        userConfiguredPath: URL? = nil,
        namTrainerPath: URL = defaultNAMTrainerPath
    ) async -> PythonEnvironment? {
        // 1. User-configured project path - check for .venv/bin/python3
        if let userPath = userConfiguredPath {
            if let env = checkVenvPython(at: userPath) { return env }
        }

        // 2. Default NAM-Trainer project - check for .venv/bin/python3
        if let env = checkVenvPython(at: namTrainerPath) { return env }

        // 3. Fallback: search for nam-full directly in PATH
        if let namFullPath = findExecutableInKnownPaths(named: "nam-full") {
            return PythonEnvironment(
                pythonPath: namFullPath,
                projectRoot: nil
            )
        }

        return nil
    }

    /// Validates that a detected environment can actually import NAM.
    static func validate(_ environment: PythonEnvironment) async -> Bool {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = environment.pythonPath
        process.arguments = ["-c", "from nam import __version__; print(__version__)"]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environmentWithUserPath()

        do {
            try process.run()

            let exitCode: Int32 = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                }
            }
            return exitCode == 0
        } catch {
            return false
        }
    }

    // MARK: - Internal

    /// Builds an environment dictionary that includes common user PATH locations.
    static func environmentWithUserPath() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let additionalPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.pyenv/shims",
            "\(home)/.cargo/bin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (additionalPaths + [currentPath]).joined(separator: ":")

        // Disable Python output buffering so print() flushes immediately.
        // Without this, stdout is block-buffered when not connected to a TTY,
        // and log lines arrive in large delayed chunks instead of real-time.
        env["PYTHONUNBUFFERED"] = "1"

        return env
    }

    // MARK: - Private

    /// Checks for a working Python with NAM in a project's .venv.
    private static func checkVenvPython(at projectRoot: URL) -> PythonEnvironment? {
        let venvPython = projectRoot
            .appendingPathComponent(".venv")
            .appendingPathComponent("bin")
            .appendingPathComponent("python3")

        guard FileManager.default.isExecutableFile(atPath: venvPython.path) else { return nil }

        return PythonEnvironment(
            pythonPath: venvPython,
            projectRoot: projectRoot
        )
    }

    /// Finds an executable by checking well-known PATH directories directly.
    private static func findExecutableInKnownPaths(named name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let searchPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.pyenv/shims",
            "\(home)/.cargo/bin",
        ]

        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
