import Foundation

/// Builds JSON argument dictionaries for the Python bridge script that calls `core.train()`.
///
/// Handles LSTM vs WaveNet parameter differences, metadata serialization,
/// and model name derivation from output WAV filenames.
nonisolated struct TrainingArgumentBuilder: Sendable {

    /// Builds the JSON argument dictionary for a single training run.
    ///
    /// - Parameters:
    ///   - inputPath: Absolute path to the input (DI) WAV file.
    ///   - outputPath: Absolute path to the output (reamped) WAV file.
    ///   - trainPath: Absolute path to the training output directory.
    ///   - session: The training session containing all parameters.
    ///   - metadata: Optional user metadata to embed in the .nam file.
    /// - Returns: A JSON-serializable dictionary matching `core.train()` kwargs.
    func buildArguments(
        inputPath: String,
        outputPath: String,
        trainPath: String,
        session: TrainingSession,
        metadata: ModelMetadata?
    ) -> [String: Any] {
        let modelName: String
        if let rigName = metadata?.namName, !rigName.isEmpty {
            modelName = rigName
        } else {
            modelName = Self.deriveModelName(from: outputPath)
        }

        var args: [String: Any] = [
            "input_path": inputPath,
            "output_path": outputPath,
            "train_path": trainPath,
            "epochs": session.epochs,
            "model_type": session.modelType.rawValue,
            "architecture": session.architectureSize.rawValue,
            "batch_size": session.batchSize,
            "ny": session.ny,
            "lr": session.learningRate,
            "lr_decay": session.learningRateDecay,
            "seed": session.seed,
            "save_plot": session.savePlot,
            "silent": session.silentMode,
            "modelname": modelName,
            "ignore_checks": session.ignoreChecks,
            "fit_mrstft": session.fitMRSTFT,
        ]

        // Optional parameters: use NSNull for JSON null
        if let latency = session.latencyOverride {
            args["latency"] = latency
        }

        if let threshold = session.esrThreshold {
            args["threshold_esr"] = threshold
        }

        // User metadata
        if let metadata, metadata.hasContent {
            args["user_metadata"] = buildMetadataDict(metadata)
        }

        return args
    }

    /// Serializes arguments to a JSON string for passing to the bridge script.
    func serializeArguments(_ args: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: args, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw ArgumentBuilderError.serializationFailed
        }
        return json
    }

    // MARK: - Model Name Derivation

    /// Derives the model name from an output WAV file path.
    ///
    /// Matches the Python GUI behavior (gui/__init__.py:720):
    /// `basename = re.sub(r'\.wav$', '', file.split('/')[-1])`
    static func deriveModelName(from outputPath: String) -> String {
        let filename = URL(fileURLWithPath: outputPath).lastPathComponent
        if filename.lowercased().hasSuffix(".wav") {
            return String(filename.dropLast(4))
        }
        return filename
    }

    // MARK: - Private

    private func buildMetadataDict(_ metadata: ModelMetadata) -> [String: Any] {
        var dict: [String: Any] = [:]

        if let name = metadata.namName { dict["name"] = name }
        if let modeledBy = metadata.modeledBy { dict["modeled_by"] = modeledBy }
        if let gearMake = metadata.gearMake { dict["gear_make"] = gearMake }
        if let gearModel = metadata.gearModel { dict["gear_model"] = gearModel }
        if let gearType = metadata.gearType { dict["gear_type"] = gearType.rawValue }
        if let toneType = metadata.toneType { dict["tone_type"] = toneType.rawValue }
        if let inputLevel = metadata.inputLevelDBu { dict["input_level_dbu"] = inputLevel }
        if let outputLevel = metadata.outputLevelDBu { dict["output_level_dbu"] = outputLevel }

        return dict
    }

    nonisolated enum ArgumentBuilderError: Error, LocalizedError, Sendable {
        case serializationFailed

        var errorDescription: String? {
            switch self {
            case .serializationFailed:
                "Failed to serialize training arguments to JSON"
            }
        }
    }
}
