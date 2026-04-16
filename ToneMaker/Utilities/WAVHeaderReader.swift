import Foundation

/// Minimal WAV file header parser for client-side validation.
///
/// Reads RIFF/WAV headers to extract format info (channels, sample rate, bit depth)
/// without loading the entire audio file into memory.
nonisolated struct WAVHeaderReader: Sendable {

    /// Information extracted from a WAV file header.
    struct WAVInfo: Sendable, Equatable {
        let channels: UInt16
        let sampleRate: UInt32
        let bitsPerSample: UInt16
        let dataSize: UInt32

        /// Duration in seconds.
        var duration: Double {
            guard channels > 0, sampleRate > 0, bitsPerSample > 0 else { return 0 }
            let bytesPerSample = Double(bitsPerSample) / 8.0
            let bytesPerFrame = bytesPerSample * Double(channels)
            let totalFrames = Double(dataSize) / bytesPerFrame
            return totalFrames / Double(sampleRate)
        }

        var isMono: Bool { channels == 1 }

        var isStandard48k: Bool { sampleRate == 48_000 }

        var isProteus44_1k: Bool { sampleRate == 44_100 }

        var isSupportedSampleRate: Bool { isStandard48k || isProteus44_1k }
    }

    enum ReadError: Error, LocalizedError, Sendable {
        case fileNotFound
        case fileTooSmall
        case notRIFF
        case notWAVE
        case fmtChunkNotFound
        case dataChunkNotFound
        case notPCM

        var errorDescription: String? {
            switch self {
            case .fileNotFound: "File not found"
            case .fileTooSmall: "File is too small to be a valid WAV"
            case .notRIFF: "File is not a RIFF container"
            case .notWAVE: "File is not a WAVE format"
            case .fmtChunkNotFound: "WAV fmt chunk not found"
            case .dataChunkNotFound: "WAV data chunk not found"
            case .notPCM: "WAV file is not PCM format"
            }
        }
    }

    /// Reads WAV header information from a file URL.
    static func read(from url: URL) throws -> WAVInfo {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ReadError.fileNotFound
        }

        // Minimum WAV header size: RIFF(4) + size(4) + WAVE(4) + fmt(24) + data(8) = 44
        guard data.count >= 44 else {
            throw ReadError.fileTooSmall
        }

        // Verify RIFF header
        guard String(data: data[0..<4], encoding: .ascii) == "RIFF" else {
            throw ReadError.notRIFF
        }

        // Verify WAVE format
        guard String(data: data[8..<12], encoding: .ascii) == "WAVE" else {
            throw ReadError.notWAVE
        }

        // Find fmt chunk
        guard let fmtOffset = findChunk(named: "fmt ", in: data, startingAt: 12) else {
            throw ReadError.fmtChunkNotFound
        }

        let fmtDataStart = fmtOffset + 8 // Skip chunk ID (4) + chunk size (4)

        let audioFormat = readUInt16(from: data, at: fmtDataStart)
        guard audioFormat == 1 else {
            // audioFormat 1 = PCM; other values are compressed formats
            throw ReadError.notPCM
        }

        let channels = readUInt16(from: data, at: fmtDataStart + 2)
        let sampleRate = readUInt32(from: data, at: fmtDataStart + 4)
        let bitsPerSample = readUInt16(from: data, at: fmtDataStart + 14)

        // Find data chunk
        guard let dataOffset = findChunk(named: "data", in: data, startingAt: 12) else {
            throw ReadError.dataChunkNotFound
        }

        let dataSize = readUInt32(from: data, at: dataOffset + 4)

        return WAVInfo(
            channels: channels,
            sampleRate: sampleRate,
            bitsPerSample: bitsPerSample,
            dataSize: dataSize
        )
    }

    // MARK: - Private Helpers

    /// Finds a chunk by its 4-character ID in the RIFF container.
    private static func findChunk(named name: String, in data: Data, startingAt offset: Int) -> Int? {
        var position = offset
        let nameData = Data(name.utf8)

        while position + 8 <= data.count {
            if data[position..<(position + 4)] == nameData {
                return position
            }
            // Move to next chunk: skip ID (4) + read chunk size (4) + chunk data
            let chunkSize = Int(readUInt32(from: data, at: position + 4))
            position += 8 + chunkSize
            // Chunks are word-aligned (2-byte boundaries)
            if chunkSize % 2 != 0 {
                position += 1
            }
        }
        return nil
    }

    private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
