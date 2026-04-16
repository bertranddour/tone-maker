import Foundation
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "InputFileValidator")

/// Result of client-side input file validation.
nonisolated struct InputValidationResult: Sendable {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let wavInfo: WAVHeaderReader.WAVInfo?
}

/// Client-side WAV file validation using `WAVHeaderReader`.
///
/// Provides instant feedback before shelling out to Python.
/// Checks format, channels, and sample rate against NAM requirements.
nonisolated struct InputFileValidator: Sendable {

    /// Validates a single WAV file for use as NAM training input.
    static func validateInput(at url: URL) -> InputValidationResult {
        logger.debug("Validating input: \(url.lastPathComponent)")
        do {
            let info = try WAVHeaderReader.read(from: url)
            var errors: [String] = []
            var warnings: [String] = []

            if !info.isMono {
                errors.append("Input must be mono (1 channel). Found \(info.channels) channels.")
            }

            if !info.isSupportedSampleRate {
                errors.append(
                    "Unsupported sample rate: \(info.sampleRate) Hz. "
                    + "NAM requires 48,000 Hz (standard) or 44,100 Hz (Proteus)."
                )
            }

            if info.isProteus44_1k {
                warnings.append("Using Proteus (44.1 kHz) format. Standard data checks won't be available.")
            }

            if info.duration < 3.0 {
                warnings.append(
                    String(format: "Input file is very short (%.1f sec). Training may not produce good results.", info.duration)
                )
            }

            return InputValidationResult(
                isValid: errors.isEmpty,
                errors: errors,
                warnings: warnings,
                wavInfo: info
            )
        } catch {
            return InputValidationResult(
                isValid: false,
                errors: ["Cannot read WAV file: \(error.localizedDescription)"],
                warnings: [],
                wavInfo: nil
            )
        }
    }

    /// Validates an output WAV file against the input file.
    ///
    /// Checks that sample rates match and lengths are compatible.
    static func validateOutput(at url: URL, against inputInfo: WAVHeaderReader.WAVInfo) -> InputValidationResult {
        do {
            let info = try WAVHeaderReader.read(from: url)
            var errors: [String] = []
            var warnings: [String] = []

            if !info.isMono {
                errors.append("Output must be mono (1 channel). Found \(info.channels) channels.")
            }

            if info.sampleRate != inputInfo.sampleRate {
                errors.append(
                    "Sample rate mismatch: input is \(inputInfo.sampleRate) Hz, "
                    + "output is \(info.sampleRate) Hz. They must match."
                )
            }

            let lengthDelta = abs(info.duration - inputInfo.duration)
            if lengthDelta > 1.0 {
                let longer = info.duration > inputInfo.duration ? "output" : "input"
                warnings.append(
                    String(format: "Length difference of %.2f seconds (the %@ is longer). Check your reamp alignment.", lengthDelta, longer)
                )
            }

            return InputValidationResult(
                isValid: errors.isEmpty,
                errors: errors,
                warnings: warnings,
                wavInfo: info
            )
        } catch {
            return InputValidationResult(
                isValid: false,
                errors: ["Cannot read WAV file: \(error.localizedDescription)"],
                warnings: [],
                wavInfo: nil
            )
        }
    }
}
