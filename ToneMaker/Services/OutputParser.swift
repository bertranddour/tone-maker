import Foundation

/// Structured events parsed from NAM training output.
nonisolated enum TrainingEvent: Sendable, Equatable {
    /// Raw log line (for display in log view).
    case log(String)
    /// An epoch completed with the given loss value.
    case epochCompleted(epoch: Int, totalEpochs: Int)
    /// ESR result from validation.
    case esrResult(Double)
    /// Latency was calibrated or specified.
    case latencyDetected(samples: Int)
    /// A warning was emitted.
    case warning(String)
    /// Data checks passed.
    case checksPassed
    /// Data checks failed.
    case checksFailed
    /// Training started.
    case trainingStarted
    /// Model training completed successfully.
    case trainingCompleted
    /// Model training failed.
    case trainingFailed
    /// Model is being exported.
    case exporting(path: String)
}

/// Parses NAM stdout/stderr lines into structured `TrainingEvent`s.
///
/// Patterns are derived from examining the actual print statements in:
/// - `core.py` (validation, latency, training, plotting)
/// - `full.py` (export, plot)
/// - PyTorch Lightning (epoch progress via tqdm)
nonisolated struct OutputParser: Sendable {

    /// Parses a single line of output into zero or more training events.
    ///
    /// Always returns a `.log` event for every non-empty line, plus any
    /// structured events extracted from the line content.
    func parse(line: String) -> [TrainingEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var events: [TrainingEvent] = [.log(line)]

        // Epoch progress from custom ToneMaker callback or Lightning tqdm
        if let epochMatch = parseEpoch(trimmed) {
            events.append(epochMatch)
        }

        // Live val_loss from TONEMAKER_EPOCH callback (shown as current ESR during training)
        if let match = trimmed.firstMatch(of: /val_loss=([0-9.eE\-+]+)/) {
            if let valLoss = Double(match.1) {
                events.append(.esrResult(valLoss))
            }
        }

        // ESR result from plotting
        // Pattern: "Error-signal ratio = 0.0123"
        if let esr = parseESR(trimmed) {
            events.append(.esrResult(esr))
        }

        // Latency detection
        // Pattern: "Delay is specified as 42" or "Delay based on average is 42"
        if let latency = parseLatency(trimmed) {
            events.append(.latencyDetected(samples: latency))
        }

        // Check results
        if trimmed.contains("-Checks passed") || trimmed.contains("Checks passed") {
            events.append(.checksPassed)
        }
        if trimmed.contains("Failed checks!") {
            events.append(.checksFailed)
        }

        // Training lifecycle
        if trimmed.contains("Starting training") {
            events.append(.trainingStarted)
        }
        if trimmed.contains("Model training complete!") {
            events.append(.trainingCompleted)
        }
        if trimmed.contains("Model training failed!") {
            events.append(.trainingFailed)
        }

        // Export
        if trimmed.hasPrefix("Exporting trained model to") {
            let path = trimmed.replacingOccurrences(of: "Exporting trained model to ", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "..."))
            events.append(.exporting(path: path))
        }

        // Warnings
        if trimmed.hasPrefix("WARNING:") || trimmed.hasPrefix("WARNING ") {
            let message = trimmed
                .replacingOccurrences(of: "WARNING:", with: "")
                .replacingOccurrences(of: "WARNING ", with: "")
                .trimmingCharacters(in: .whitespaces)
            events.append(.warning(message))
        }

        return events
    }

    // MARK: - Private Parsers

    /// Parses epoch progress from training output.
    ///
    /// Matches patterns like:
    /// - "TONEMAKER_EPOCH 5/100 val_loss=0.123456" (custom callback, preferred)
    /// - "TONEMAKER_EPOCH 5/100" (custom callback, no val_loss yet)
    /// - "Epoch 5: 100%|████| 42/42" (tqdm, if visible)
    /// - "Epoch 12/100 ..." (Lightning summary)
    private func parseEpoch(_ line: String) -> TrainingEvent? {
        // Pattern 1: Custom ToneMaker callback (reliable, always present)
        // Format: "TONEMAKER_EPOCH 5/100 val_loss=0.123456"
        if let match = line.firstMatch(of: /TONEMAKER_EPOCH\s+(\d+)\/(\d+)/) {
            let epoch = Int(match.1) ?? 0
            let total = Int(match.2) ?? 0
            return .epochCompleted(epoch: epoch, totalEpochs: total)
        }

        // Pattern 2: "Epoch N:" (tqdm style, 0-indexed)
        if let match = line.firstMatch(of: /Epoch\s+(\d+):/) {
            let epoch = Int(match.1) ?? 0
            return .epochCompleted(epoch: epoch + 1, totalEpochs: 0)
        }

        // Pattern 3: "Epoch N/M" (slash style, Lightning summary)
        if let match = line.firstMatch(of: /Epoch\s+(\d+)\/(\d+)/) {
            let epoch = Int(match.1) ?? 0
            let total = Int(match.2) ?? 0
            return .epochCompleted(epoch: epoch, totalEpochs: total)
        }

        return nil
    }

    /// Parses ESR from output.
    ///
    /// Matches patterns like:
    /// - "Error-signal ratio = 0.0123"
    /// - "ESR=0.0123"
    /// - "ESR=1.23e-02"
    private func parseESR(_ line: String) -> Double? {
        // Pattern 1: "Error-signal ratio = X.XXXg" (core.py:1162)
        if let match = line.firstMatch(of: /Error-signal ratio\s*=\s*([0-9.eE\-+]+)/) {
            return Double(match.1)
        }

        // Pattern 2: "ESR=X.XXX" (plot title, full.py:85)
        if let match = line.firstMatch(of: /ESR\s*=\s*([0-9.eE\-+]+)/) {
            return Double(match.1)
        }

        return nil
    }

    /// Parses latency from output.
    ///
    /// Matches patterns like:
    /// - "Delay is specified as 42" (core.py:593)
    /// - "Delay based on average is 42" (core.py:483)
    private func parseLatency(_ line: String) -> Int? {
        if let match = line.firstMatch(of: /Delay\s+(?:is specified as|based on average is)\s+(\d+)/) {
            return Int(match.1)
        }
        return nil
    }
}
