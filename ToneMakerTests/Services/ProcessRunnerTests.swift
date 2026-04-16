import Testing
import Foundation
@testable import ToneMaker

struct ProcessRunnerTests {

    // MARK: - Basic Execution

    @Test func runsSimpleCommand() async throws {
        let runner = ProcessRunner()
        let stream = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello world"]
        )

        var lines: [String] = []
        var exitCode: Int32?

        for try await output in stream {
            switch output {
            case .stdout(let line):
                lines.append(line)
            case .stderr:
                break
            case .terminated(let code):
                exitCode = code
            }
        }

        #expect(lines.contains("hello world"))
        #expect(exitCode == 0)
    }

    @Test func capturesStderr() async throws {
        let runner = ProcessRunner()
        // Use bash to write to stderr
        let stream = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-c", "echo error_message >&2"]
        )

        var stderrLines: [String] = []

        for try await output in stream {
            if case .stderr(let line) = output {
                stderrLines.append(line)
            }
        }

        #expect(stderrLines.contains("error_message"))
    }

    @Test func reportsNonZeroExitCode() async throws {
        let runner = ProcessRunner()
        let stream = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-c", "exit 42"]
        )

        var exitCode: Int32?
        for try await output in stream {
            if case .terminated(let code) = output {
                exitCode = code
            }
        }

        #expect(exitCode == 42)
    }

    @Test func streamsMultipleLines() async throws {
        let runner = ProcessRunner()
        let stream = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-c", "echo line1; echo line2; echo line3"]
        )

        var lines: [String] = []
        for try await output in stream {
            if case .stdout(let line) = output {
                lines.append(line)
            }
        }

        #expect(lines.contains("line1"))
        #expect(lines.contains("line2"))
        #expect(lines.contains("line3"))
    }

    // MARK: - Termination

    @Test func canTerminateRunningProcess() async throws {
        let runner = ProcessRunner()
        let stream = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["60"]
        )

        // Terminate after a brief delay
        try await Task.sleep(for: .milliseconds(100))
        await runner.terminate()

        var terminated = false
        for try await output in stream {
            if case .terminated = output {
                terminated = true
            }
        }

        #expect(terminated)
    }
}
