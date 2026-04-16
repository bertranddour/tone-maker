import Testing
import Foundation
@testable import ToneMaker

struct PersistedAudioFileTests {

    // MARK: - AudioFileRole

    @Test func audioFileRoleRawValues() {
        #expect(AudioFileRole.input.rawValue == "input")
        #expect(AudioFileRole.output.rawValue == "output")
    }

    @Test func audioFileRoleRoundTrip() {
        for role in AudioFileRole.allCases {
            #expect(AudioFileRole(rawValue: role.rawValue) == role)
        }
    }

    // MARK: - PersistedAudioFile

    @Test func roleComputedProperty() {
        let file = PersistedAudioFile(
            fileName: "test.wav",
            role: .input,
            fileData: Data([0x01, 0x02])
        )
        #expect(file.role == .input)
        #expect(file.roleRaw == "input")

        file.role = .output
        #expect(file.role == .output)
        #expect(file.roleRaw == "output")
    }

    @Test func defaultOrder() {
        let file = PersistedAudioFile(
            fileName: "test.wav",
            role: .output,
            fileData: Data()
        )
        #expect(file.order == 0)
    }

    @Test func customOrder() {
        let file = PersistedAudioFile(
            fileName: "test.wav",
            role: .output,
            order: 3,
            fileData: Data([0xFF])
        )
        #expect(file.order == 3)
    }

    // MARK: - TrainingSession Integration

    @Test func newSessionHasNilPersistedAudioFiles() {
        let session = TrainingSession()
        #expect(session.persistedAudioFiles == nil)
        #expect(session.persistedInputFile == nil)
        #expect(session.persistedOutputFiles.isEmpty)
    }

    @Test func persistedInputFileReturnsInputRole() {
        let session = TrainingSession()
        let inputFile = PersistedAudioFile(fileName: "di.wav", role: .input, fileData: Data())
        let outputFile = PersistedAudioFile(fileName: "amp.wav", role: .output, fileData: Data())
        session.persistedAudioFiles = [inputFile, outputFile]

        #expect(session.persistedInputFile?.fileName == "di.wav")
        #expect(session.persistedInputFile?.role == .input)
    }

    @Test func persistedOutputFilesReturnsOutputRole() {
        let session = TrainingSession()
        let inputFile = PersistedAudioFile(fileName: "di.wav", role: .input, fileData: Data())
        let output1 = PersistedAudioFile(fileName: "amp1.wav", role: .output, order: 0, fileData: Data())
        let output2 = PersistedAudioFile(fileName: "amp2.wav", role: .output, order: 1, fileData: Data())
        session.persistedAudioFiles = [output2, inputFile, output1]

        let outputs = session.persistedOutputFiles
        #expect(outputs.count == 2)
        #expect(outputs[0].fileName == "amp1.wav")
        #expect(outputs[1].fileName == "amp2.wav")
    }

    @Test func persistedInputFileNilWhenNoInput() {
        let session = TrainingSession()
        let outputFile = PersistedAudioFile(fileName: "amp.wav", role: .output, fileData: Data())
        session.persistedAudioFiles = [outputFile]

        #expect(session.persistedInputFile == nil)
    }
}
