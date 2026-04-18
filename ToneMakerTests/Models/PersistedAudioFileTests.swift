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

    // MARK: - TrainingSession Integration

    @Test func newSessionHasNilPersistedAudioFiles() {
        let session = TrainingSession()
        #expect(session.persistedAudioFiles == nil)
        #expect(session.persistedInputFile == nil)
    }

    @Test func persistedInputFileReturnsInputRole() {
        let session = TrainingSession()
        let inputFile = PersistedAudioFile(fileName: "di.wav", role: .input, fileData: Data())
        let outputFile = PersistedAudioFile(fileName: "amp.wav", role: .output, fileData: Data())
        session.persistedAudioFiles = [inputFile, outputFile]

        #expect(session.persistedInputFile?.fileName == "di.wav")
        #expect(session.persistedInputFile?.role == .input)
    }

    @Test func persistedInputFileNilWhenNoInput() {
        let session = TrainingSession()
        let outputFile = PersistedAudioFile(fileName: "amp.wav", role: .output, fileData: Data())
        session.persistedAudioFiles = [outputFile]

        #expect(session.persistedInputFile == nil)
    }

    // MARK: - BatchItem Attachment

    @Test func outputFileAttachedToBatchItem() {
        let item = BatchItem(order: 0, outputFileName: "amp.wav")
        let file = PersistedAudioFile(fileName: "amp.wav", role: .output, fileData: Data([0xAA]))
        item.persistedOutputFile = file

        #expect(item.persistedOutputFile?.fileName == "amp.wav")
    }
}
