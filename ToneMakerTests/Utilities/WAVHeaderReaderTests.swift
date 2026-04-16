import Testing
import Foundation
@testable import ToneMaker

struct WAVHeaderReaderTests {

    // MARK: - Valid WAV Parsing

    @Test func parseMinimalValidWAV() throws {
        // Create a minimal valid 48kHz mono 16-bit WAV file in memory
        let wavData = createWAVData(
            channels: 1,
            sampleRate: 48_000,
            bitsPerSample: 16,
            dataSize: 96_000 // 1 second of mono 16-bit audio
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_48k_mono.wav")
        try wavData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let info = try WAVHeaderReader.read(from: tempURL)
        #expect(info.channels == 1)
        #expect(info.sampleRate == 48_000)
        #expect(info.bitsPerSample == 16)
        #expect(info.isMono == true)
        #expect(info.isStandard48k == true)
        #expect(info.isSupportedSampleRate == true)
    }

    @Test func parse44_1kWAV() throws {
        let wavData = createWAVData(
            channels: 1,
            sampleRate: 44_100,
            bitsPerSample: 16,
            dataSize: 88_200
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_44_1k_mono.wav")
        try wavData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let info = try WAVHeaderReader.read(from: tempURL)
        #expect(info.sampleRate == 44_100)
        #expect(info.isProteus44_1k == true)
        #expect(info.isSupportedSampleRate == true)
    }

    @Test func detectStereoFile() throws {
        let wavData = createWAVData(
            channels: 2,
            sampleRate: 48_000,
            bitsPerSample: 16,
            dataSize: 192_000
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_stereo.wav")
        try wavData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let info = try WAVHeaderReader.read(from: tempURL)
        #expect(info.channels == 2)
        #expect(info.isMono == false)
    }

    @Test func calculateDuration() throws {
        // 48000 samples/sec * 2 bytes/sample * 1 channel = 96000 bytes/sec
        // 96000 bytes of data = 1 second
        let wavData = createWAVData(
            channels: 1,
            sampleRate: 48_000,
            bitsPerSample: 16,
            dataSize: 96_000
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_duration.wav")
        try wavData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let info = try WAVHeaderReader.read(from: tempURL)
        #expect(abs(info.duration - 1.0) < 0.001)
    }

    @Test func unsupportedSampleRate() throws {
        let wavData = createWAVData(
            channels: 1,
            sampleRate: 22_050,
            bitsPerSample: 16,
            dataSize: 44_100
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_22k.wav")
        try wavData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let info = try WAVHeaderReader.read(from: tempURL)
        #expect(info.isSupportedSampleRate == false)
    }

    // MARK: - Error Cases

    @Test func rejectsNonExistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/path/file.wav")
        #expect(throws: WAVHeaderReader.ReadError.self) {
            try WAVHeaderReader.read(from: url)
        }
    }

    @Test func rejectsTooSmallFile() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_small.wav")
        try Data([0x00, 0x01, 0x02]).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: WAVHeaderReader.ReadError.fileTooSmall) {
            try WAVHeaderReader.read(from: tempURL)
        }
    }

    @Test func rejectsNonRIFFFile() throws {
        var data = Data(count: 44)
        data[0] = 0x00 // Not "RIFF"

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_not_riff.wav")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: WAVHeaderReader.ReadError.notRIFF) {
            try WAVHeaderReader.read(from: tempURL)
        }
    }

    // MARK: - Helpers

    /// Creates a minimal valid WAV file data blob.
    private func createWAVData(
        channels: UInt16,
        sampleRate: UInt32,
        bitsPerSample: UInt16,
        dataSize: UInt32
    ) -> Data {
        var data = Data()

        let bytesPerSample = bitsPerSample / 8
        let blockAlign = channels * bytesPerSample
        let byteRate = sampleRate * UInt32(blockAlign)

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(&data, 36 + dataSize) // File size - 8
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(&data, 16) // Chunk size
        appendUInt16(&data, 1) // PCM format
        appendUInt16(&data, channels)
        appendUInt32(&data, sampleRate)
        appendUInt32(&data, byteRate)
        appendUInt16(&data, blockAlign)
        appendUInt16(&data, bitsPerSample)

        // data chunk header (no actual audio data needed for header tests)
        data.append(contentsOf: "data".utf8)
        appendUInt32(&data, dataSize)

        return data
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
