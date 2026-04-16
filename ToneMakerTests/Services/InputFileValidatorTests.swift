import Testing
import Foundation
@testable import ToneMaker

struct InputFileValidatorTests {

    // MARK: - Input Validation

    @Test func validMonoInput48k() throws {
        let wavData = createWAVData(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 960_000) // ~10 sec
        let url = try writeTempWAV(wavData, name: "valid_48k_input.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
        #expect(result.wavInfo?.isMono == true)
        #expect(result.wavInfo?.isStandard48k == true)
    }

    @Test func validMonoInput44_1k() throws {
        let wavData = createWAVData(channels: 1, sampleRate: 44_100, bitsPerSample: 16, dataSize: 882_000) // ~10 sec
        let url = try writeTempWAV(wavData, name: "valid_44k_input.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == true)
        #expect(result.warnings.contains(where: { $0.contains("Proteus") }))
    }

    @Test func rejectsStereoInput() throws {
        let wavData = createWAVData(channels: 2, sampleRate: 48_000, bitsPerSample: 16, dataSize: 192_000)
        let url = try writeTempWAV(wavData, name: "stereo_input.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == false)
        #expect(result.errors.contains(where: { $0.contains("mono") }))
    }

    @Test func rejectsUnsupportedSampleRate() throws {
        let wavData = createWAVData(channels: 1, sampleRate: 22_050, bitsPerSample: 16, dataSize: 44_100)
        let url = try writeTempWAV(wavData, name: "bad_samplerate.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == false)
        #expect(result.errors.contains(where: { $0.contains("sample rate") }))
    }

    @Test func warnsShortInput() throws {
        let wavData = createWAVData(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 96_000) // ~1 sec
        let url = try writeTempWAV(wavData, name: "short_input.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == true)
        #expect(result.warnings.contains(where: { $0.contains("short") }))
    }

    @Test func handlesNonExistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/file.wav")
        let result = InputFileValidator.validateInput(at: url)
        #expect(result.isValid == false)
        #expect(result.errors.contains(where: { $0.contains("Cannot read") }))
    }

    // MARK: - Output Validation

    @Test func validOutputMatchesInput() throws {
        let inputInfo = WAVHeaderReader.WAVInfo(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 960_000)
        let wavData = createWAVData(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 960_000)
        let url = try writeTempWAV(wavData, name: "valid_output.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateOutput(at: url, against: inputInfo)
        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
    }

    @Test func rejectsSampleRateMismatch() throws {
        let inputInfo = WAVHeaderReader.WAVInfo(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 960_000)
        let wavData = createWAVData(channels: 1, sampleRate: 44_100, bitsPerSample: 16, dataSize: 882_000)
        let url = try writeTempWAV(wavData, name: "mismatch_output.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateOutput(at: url, against: inputInfo)
        #expect(result.isValid == false)
        #expect(result.errors.contains(where: { $0.contains("Sample rate mismatch") }))
    }

    @Test func warnsLengthDifference() throws {
        // Input: ~10 sec, Output: ~15 sec (5 sec difference)
        let inputInfo = WAVHeaderReader.WAVInfo(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 960_000)
        let wavData = createWAVData(channels: 1, sampleRate: 48_000, bitsPerSample: 16, dataSize: 1_440_000)
        let url = try writeTempWAV(wavData, name: "long_output.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = InputFileValidator.validateOutput(at: url, against: inputInfo)
        #expect(result.isValid == true) // Length mismatch is a warning, not error
        #expect(result.warnings.contains(where: { $0.contains("Length difference") }))
    }

    // MARK: - Helpers

    private func createWAVData(channels: UInt16, sampleRate: UInt32, bitsPerSample: UInt16, dataSize: UInt32) -> Data {
        var data = Data()
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)

        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(&data, 36 + dataSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(&data, 16)
        appendUInt16(&data, 1)
        appendUInt16(&data, channels)
        appendUInt32(&data, sampleRate)
        appendUInt32(&data, byteRate)
        appendUInt16(&data, blockAlign)
        appendUInt16(&data, bitsPerSample)
        data.append(contentsOf: "data".utf8)
        appendUInt32(&data, dataSize)
        return data
    }

    private func writeTempWAV(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }

    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }
}
