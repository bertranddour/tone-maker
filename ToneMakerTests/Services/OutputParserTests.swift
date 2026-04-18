import Testing
import Foundation
@testable import ToneMaker

struct OutputParserTests {

    let parser = OutputParser()

    // MARK: - Basic Parsing

    @Test func emptyLineReturnsEmpty() {
        let events = parser.parse(line: "")
        #expect(events.isEmpty)
    }

    @Test func whitespaceOnlyReturnsEmpty() {
        let events = parser.parse(line: "   ")
        #expect(events.isEmpty)
    }

    @Test func arbitraryLineReturnsLog() {
        let events = parser.parse(line: "Some random output")
        #expect(events.count == 1)
        #expect(events[0] == .log("Some random output"))
    }

    // MARK: - Epoch Parsing

    @Test func parsesToneMakerEpochCallback() {
        let events = parser.parse(line: "TONEMAKER_EPOCH 5/100 val_loss=0.123456")
        #expect(events.contains(.epochCompleted(epoch: 5, totalEpochs: 100)))
        #expect(events.contains(.epochProgress(epoch: 5, valLoss: 0.123456)))
    }

    @Test func parsesToneMakerEpochNoValLoss() {
        let events = parser.parse(line: "TONEMAKER_EPOCH 1/200")
        #expect(events.contains(.epochCompleted(epoch: 1, totalEpochs: 200)))
        #expect(!events.contains(where: {
            if case .epochProgress = $0 { return true }
            return false
        }))
    }

    @Test func toneMakerEpochWithValLossDoesNotEmitEsrResult() {
        // Standalone val_loss parsing was removed — mid-training val_loss is now
        // a distinct .epochProgress event so it doesn't overwrite the final ESR.
        let events = parser.parse(line: "TONEMAKER_EPOCH 5/100 val_loss=0.123456")
        #expect(!events.contains(where: {
            if case .esrResult = $0 { return true }
            return false
        }))
    }

    @Test func parsesEpochColonPattern() {
        let events = parser.parse(line: "Epoch 5: 100%|████| 42/42")
        #expect(events.contains(.epochCompleted(epoch: 6, totalEpochs: 0)))
    }

    @Test func parsesEpochZeroIndexed() {
        let events = parser.parse(line: "Epoch 0:  50%|██   | 21/42")
        #expect(events.contains(.epochCompleted(epoch: 1, totalEpochs: 0)))
    }

    @Test func parsesEpochSlashPattern() {
        let events = parser.parse(line: "Epoch 12/100")
        #expect(events.contains(.epochCompleted(epoch: 12, totalEpochs: 100)))
    }

    // MARK: - ESR Parsing

    @Test func parsesErrorSignalRatio() {
        let events = parser.parse(line: "Error-signal ratio = 0.0123")
        #expect(events.contains(.esrResult(0.0123)))
    }

    @Test func parsesESRScientificNotation() {
        let events = parser.parse(line: "Error-signal ratio = 1.23e-02")
        #expect(events.contains(where: {
            if case .esrResult(let esr) = $0 {
                return abs(esr - 0.0123) < 1e-6
            }
            return false
        }))
    }

    @Test func parsesESREqualsPattern() {
        // From plot title in full.py
        let events = parser.parse(line: "ESR=0.0045")
        #expect(events.contains(.esrResult(0.0045)))
    }

    // MARK: - Latency Parsing

    @Test func parsesDelaySpecified() {
        let events = parser.parse(line: "Delay is specified as 42")
        #expect(events.contains(.latencyDetected(samples: 42)))
    }

    @Test func parsesDelayFromAverage() {
        let events = parser.parse(line: "Delay based on average is 128")
        #expect(events.contains(.latencyDetected(samples: 128)))
    }

    // MARK: - Check Results

    @Test func parsesChecksPassed() {
        let events = parser.parse(line: "-Checks passed")
        #expect(events.contains(.checksPassed))
    }

    @Test func parsesChecksFailed() {
        let events = parser.parse(line: "Failed checks!")
        #expect(events.contains(.checksFailed))
    }

    // MARK: - Training Lifecycle

    @Test func parsesTrainingStarted() {
        let events = parser.parse(line: "Starting training. It's time to kick ass and chew bubblegum!")
        #expect(events.contains(.trainingStarted))
    }

    @Test func parsesTrainingCompleted() {
        let events = parser.parse(line: "Model training complete!")
        #expect(events.contains(.trainingCompleted))
    }

    @Test func parsesTrainingFailed() {
        let events = parser.parse(line: "Model training failed! Skip exporting...")
        #expect(events.contains(.trainingFailed))
    }

    // MARK: - Export

    @Test func parsesExporting() {
        let events = parser.parse(line: "Exporting trained model to /path/to/output...")
        #expect(events.contains(.exporting(path: "/path/to/output")))
    }

    // MARK: - Warnings

    @Test func parsesWarningColon() {
        let events = parser.parse(line: "WARNING: No GPU was found. Training will be very slow!")
        #expect(events.contains(.warning("No GPU was found. Training will be very slow!")))
    }

    // MARK: - Multiple Events Per Line

    @Test func alwaysIncludesLogEvent() {
        let events = parser.parse(line: "Error-signal ratio = 0.01")
        // Should have both .log and .esrResult
        #expect(events.contains(.log("Error-signal ratio = 0.01")))
        #expect(events.contains(.esrResult(0.01)))
        #expect(events.count == 2)
    }

    // MARK: - Additional ESR Patterns

    @Test func parsesReplicateESR() {
        let events = parser.parse(line: "Replicate ESR is 0.00123456.")
        // This doesn't match our ESR patterns (it's a validation message, not final ESR)
        // It should only be a log event
        #expect(events.count == 1)
        #expect(events[0] == .log("Replicate ESR is 0.00123456."))
    }

    @Test func parsesESRWithSpaces() {
        let events = parser.parse(line: "ESR = 0.0045")
        #expect(events.contains(.esrResult(0.0045)))
    }

    @Test func parsesVerySmallESR() {
        let events = parser.parse(line: "Error-signal ratio = 3.45e-04")
        #expect(events.contains(where: {
            if case .esrResult(let esr) = $0 {
                return abs(esr - 0.000345) < 1e-7
            }
            return false
        }))
    }

    // MARK: - Edge Cases

    @Test func handlesGarbageInput() {
        let events = parser.parse(line: "🎸🔥 random unicode garbage 日本語")
        #expect(events.count == 1)
        #expect(events[0] == .log("🎸🔥 random unicode garbage 日本語"))
    }

    @Test func handlesNumericOnlyLine() {
        let events = parser.parse(line: "42")
        #expect(events.count == 1)
    }
}
