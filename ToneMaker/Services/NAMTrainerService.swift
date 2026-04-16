import Foundation
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "NAMTrainerService")

/// Protocol for the training service, enabling test mocking.
protocol TrainingServiceProtocol: Sendable {
    func train(
        inputPath: String,
        outputPath: String,
        trainPath: String,
        session: TrainingSession,
        metadata: ModelMetadata?
    ) -> AsyncThrowingStream<TrainingEvent, any Error>

    func cancel() async
}

/// Central orchestrator for NAM model training.
///
/// Coordinates the Python bridge script invocation via `ProcessRunner`,
/// parses output via `OutputParser`, and builds arguments via `TrainingArgumentBuilder`.
actor NAMTrainerService: TrainingServiceProtocol {

    private let processRunner = ProcessRunner()
    private let argumentBuilder = TrainingArgumentBuilder()
    private let outputParser = OutputParser()
    private var environment: PythonEnvironment?

    /// The Python bridge script content that wraps `core.train()`.
    private nonisolated static let bridgeScript = """
    import matplotlib
    matplotlib.use("Agg")  # Non-interactive backend: prevents plt.show() from opening windows
    import sys, json, os
    os.environ["PYTHONUNBUFFERED"] = "1"

    import pytorch_lightning as pl

    # Custom callback that prints epoch progress to stdout for ToneMaker to parse.
    # PyTorch Lightning's tqdm/rich progress bars disable real-time updates when
    # stderr is not a TTY (which it isn't when launched from a pipe).
    class _ToneMakerProgress(pl.Callback):
        def on_train_epoch_end(self, trainer, pl_module):
            epoch = trainer.current_epoch + 1
            max_epochs = trainer.max_epochs
            val_loss = trainer.callback_metrics.get("val_loss")
            val_str = f" val_loss={val_loss:.6f}" if val_loss is not None else ""
            print(f"TONEMAKER_EPOCH {epoch}/{max_epochs}{val_str}", flush=True)

    # Monkey-patch Trainer to inject our progress callback
    _original_trainer_init = pl.Trainer.__init__
    def _patched_trainer_init(self, *args, **kwargs):
        callbacks = list(kwargs.get("callbacks", []) or [])
        callbacks.append(_ToneMakerProgress())
        kwargs["callbacks"] = callbacks
        _original_trainer_init(self, *args, **kwargs)
    pl.Trainer.__init__ = _patched_trainer_init

    from nam.train.core import train, Architecture
    from nam.models.metadata import UserMetadata, GearType, ToneType

    args = json.loads(sys.argv[1])

    # Build user metadata if provided
    user_metadata = None
    if "user_metadata" in args and args["user_metadata"]:
        md = args["user_metadata"]
        # Convert string enums back to enum objects
        if "gear_type" in md and md["gear_type"]:
            md["gear_type"] = GearType(md["gear_type"])
        if "tone_type" in md and md["tone_type"]:
            md["tone_type"] = ToneType(md["tone_type"])
        user_metadata = UserMetadata(**md)

    train_output = train(
        input_path=args["input_path"],
        output_path=args["output_path"],
        train_path=args["train_path"],
        epochs=args["epochs"],
        latency=args.get("latency"),
        model_type=args.get("model_type", "WaveNet"),
        architecture=Architecture(args["architecture"]),
        batch_size=args["batch_size"],
        ny=args["ny"],
        lr=args["lr"],
        lr_decay=args["lr_decay"],
        seed=args.get("seed", 0),
        save_plot=args["save_plot"],
        silent=True,  # ToneMaker uses custom _ToneMakerProgress callback instead of tqdm
        modelname=args["modelname"],
        ignore_checks=args["ignore_checks"],
        local=False,
        fit_mrstft=args["fit_mrstft"],
        threshold_esr=args.get("threshold_esr"),
        user_metadata=user_metadata,
    )

    if train_output.model is None:
        print("Model training failed! Skip exporting...")
        sys.exit(1)

    print("Model training complete!")
    outdir = args["train_path"]
    basename = args["modelname"]
    print(f"Exporting trained model to {outdir}...")

    from nam.train import metadata as _metadata
    train_output.model.net.export(
        outdir,
        basename=basename,
        user_metadata=user_metadata,
        other_metadata={
            _metadata.TRAINING_KEY: train_output.metadata.model_dump()
        },
    )
    print("Done!")
    """

    /// Sets the Python environment to use for training.
    func setEnvironment(_ env: PythonEnvironment) {
        self.environment = env
    }

    /// Detects and caches the Python environment.
    ///
    /// Reads the user-configured NAM-Trainer project path from UserDefaults
    /// (set via Settings > General > NAM-Trainer Project).
    func detectEnvironment() async -> PythonEnvironment? {
        if let existing = environment { return existing }
        logger.info("Detecting Python environment")

        let userPath = UserDefaults.standard.string(forKey: "namTrainerProjectPath")
        let projectURL: URL
        if let userPath, !userPath.isEmpty {
            projectURL = URL(fileURLWithPath: userPath)
        } else {
            projectURL = PythonEnvironmentDetector.defaultNAMTrainerPath
        }

        let detected = await PythonEnvironmentDetector.detect(namTrainerPath: projectURL)
        if let detected {
            logger.info("Python environment found: \(detected.pythonPath.path)")
        } else {
            logger.error("Python environment not found")
        }
        environment = detected
        return detected
    }

    /// Runs a training session and streams events.
    nonisolated func train(
        inputPath: String,
        outputPath: String,
        trainPath: String,
        session: TrainingSession,
        metadata: ModelMetadata?
    ) -> AsyncThrowingStream<TrainingEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.runTraining(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        trainPath: trainPath,
                        session: session,
                        metadata: metadata,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Cancels the currently running training process.
    func cancel() async {
        await processRunner.terminate()
    }

    // MARK: - Private

    private func runTraining(
        inputPath: String,
        outputPath: String,
        trainPath: String,
        session: TrainingSession,
        metadata: ModelMetadata?,
        continuation: AsyncThrowingStream<TrainingEvent, any Error>.Continuation
    ) async throws {
        // 1. Detect environment
        guard let env = await detectEnvironment() else {
            throw NAMTrainerError.pythonNotFound
        }

        // 2. Build arguments
        let args = argumentBuilder.buildArguments(
            inputPath: inputPath,
            outputPath: outputPath,
            trainPath: trainPath,
            session: session,
            metadata: metadata
        )
        let jsonArgs = try argumentBuilder.serializeArguments(args)

        // 3. Build command using inline Python via -c (avoids sandbox temp file issues)
        let (executable, cmdArgs, processEnv) = env.buildPythonCommand(
            code: Self.bridgeScript,
            arguments: [jsonArgs]
        )

        // 5. Run process and stream output
        let stream = try await processRunner.run(
            executableURL: executable,
            arguments: cmdArgs,
            environment: processEnv
        )

        for try await output in stream {
            switch output {
            case .stdout(let line):
                let events = outputParser.parse(line: line)
                for event in events {
                    continuation.yield(event)
                }

            case .stderr(let line):
                // PyTorch Lightning progress goes to stderr
                let events = outputParser.parse(line: line)
                for event in events {
                    continuation.yield(event)
                }

            case .terminated(let exitCode):
                if exitCode != 0 {
                    continuation.yield(.trainingFailed)
                }
                continuation.finish()
                return
            }
        }

        continuation.finish()
    }

    nonisolated enum NAMTrainerError: Error, LocalizedError, Sendable {
        case pythonNotFound
        case trainingFailed(exitCode: Int32)

        var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                "Python environment with NAM not found. Configure it in Settings."
            case .trainingFailed(let code):
                "Training process exited with code \(code)"
            }
        }
    }
}
