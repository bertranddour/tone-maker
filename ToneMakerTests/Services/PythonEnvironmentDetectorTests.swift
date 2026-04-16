import Testing
import Foundation
@testable import ToneMaker

struct PythonEnvironmentDetectorTests {

    // MARK: - Default Path

    @Test func defaultPathContainsDeveloperNAMTrainer() {
        let path = PythonEnvironmentDetector.defaultNAMTrainerPath
        #expect(path.lastPathComponent == "NAM-Trainer")
    }

    // MARK: - Environment PATH

    @Test func environmentWithUserPathIncludesHomebrew() {
        let env = PythonEnvironmentDetector.environmentWithUserPath()
        let path = env["PATH"] ?? ""
        #expect(path.contains("/opt/homebrew/bin"))
    }

    @Test func environmentWithUserPathIncludesLocalBin() {
        let env = PythonEnvironmentDetector.environmentWithUserPath()
        let path = env["PATH"] ?? ""
        #expect(path.contains(".local/bin"))
    }

    @Test func environmentWithUserPathSetsPythonUnbuffered() {
        let env = PythonEnvironmentDetector.environmentWithUserPath()
        #expect(env["PYTHONUNBUFFERED"] == "1")
    }

    // MARK: - Python Command Building

    @Test func buildPythonCommandStructure() {
        let env = PythonEnvironment(
            pythonPath: URL(fileURLWithPath: "/usr/bin/python3"),
            projectRoot: nil
        )
        let command = env.buildPythonCommand(code: "print('hello')", arguments: ["arg1"])
        #expect(command.executable.path == "/usr/bin/python3")
        #expect(command.args == ["-c", "print('hello')", "arg1"])
        #expect(command.environment["PYTHONUNBUFFERED"] == "1")
    }
}
