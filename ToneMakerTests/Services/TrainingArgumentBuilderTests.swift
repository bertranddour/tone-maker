import Testing
import Foundation
@testable import ToneMaker

struct TrainingArgumentBuilderTests {

    let builder = TrainingArgumentBuilder()

    // MARK: - Model Name Derivation

    @Test func derivesModelNameFromWAVPath() {
        let name = TrainingArgumentBuilder.deriveModelName(from: "/path/to/MyAmp_Crunch.wav")
        #expect(name == "MyAmp_Crunch")
    }

    @Test func derivesModelNameCaseInsensitive() {
        let name = TrainingArgumentBuilder.deriveModelName(from: "/path/to/MyAmp.WAV")
        #expect(name == "MyAmp")
    }

    @Test func derivesModelNameWithoutExtension() {
        let name = TrainingArgumentBuilder.deriveModelName(from: "/path/to/MyAmp")
        #expect(name == "MyAmp")
    }

    @Test func derivesModelNameFromFilenameOnly() {
        let name = TrainingArgumentBuilder.deriveModelName(from: "output.wav")
        #expect(name == "output")
    }

    // MARK: - Argument Building

    @Test func buildsRequiredArguments() {
        let session = TrainingSession()

        let args = builder.buildArguments(
            inputPath: "/input/di.wav",
            outputPath: "/output/reamped.wav",
            trainPath: "/train/output",
            session: session,
            metadata: nil
        )

        #expect(args["input_path"] as? String == "/input/di.wav")
        #expect(args["output_path"] as? String == "/output/reamped.wav")
        #expect(args["train_path"] as? String == "/train/output")
        #expect(args["epochs"] as? Int == 100)
        #expect(args["architecture"] as? String == "standard")
        #expect(args["batch_size"] as? Int == 16)
        #expect(args["ny"] as? Int == 8192)
        #expect(args["lr"] as? Double == 0.004)
        #expect(args["lr_decay"] as? Double == 0.007)
        #expect(args["seed"] as? Int == 0)
        #expect(args["save_plot"] as? Bool == true)
        #expect(args["silent"] as? Bool == true)
        #expect(args["modelname"] as? String == "reamped")
        #expect(args["ignore_checks"] as? Bool == false)
        #expect(args["fit_mrstft"] as? Bool == true)
        #expect(args["model_type"] as? String == "WaveNet")
    }

    @Test func modelTypeIsLSTMWhenSet() {
        let session = TrainingSession(modelType: .lstm, learningRate: Defaults.learningRateLSTM)

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        #expect(args["model_type"] as? String == "LSTM")
    }

    @Test func rigNameDrivesModelName() {
        let session = TrainingSession()
        let metadata = ModelMetadata(namName: "JCM800 Crunch")

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output/generic_output.wav",
            trainPath: "/train",
            session: session,
            metadata: metadata
        )

        #expect(args["modelname"] as? String == "JCM800 Crunch")
    }

    @Test func fallsBackToFilenameWhenNoRigName() {
        let session = TrainingSession()

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output/MyAmp.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        #expect(args["modelname"] as? String == "MyAmp")
    }

    @Test func omitsOptionalParametersWhenNil() {
        let session = TrainingSession()

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        // latency and threshold_esr should NOT be in the dict when nil
        #expect(args["latency"] == nil)
        #expect(args["threshold_esr"] == nil)
        #expect(args["user_metadata"] == nil)
    }

    @Test func includesOptionalParametersWhenSet() {
        let session = TrainingSession()
        session.latencyOverride = 42
        session.esrThreshold = 0.01

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        #expect(args["latency"] as? Int == 42)
        #expect(args["threshold_esr"] as? Double == 0.01)
    }

    @Test func includesMetadataWhenProvided() {
        let session = TrainingSession()
        let metadata = ModelMetadata(
            namName: "JCM800",
            modeledBy: "Bertrand",
            gearMake: "Marshall",
            gearModel: "JCM800",
            gearType: .amp,
            toneType: .crunch
        )

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: metadata
        )

        let metaDict = args["user_metadata"] as? [String: Any]
        #expect(metaDict != nil)
        #expect(metaDict?["name"] as? String == "JCM800")
        #expect(metaDict?["modeled_by"] as? String == "Bertrand")
        #expect(metaDict?["gear_make"] as? String == "Marshall")
        #expect(metaDict?["gear_model"] as? String == "JCM800")
        #expect(metaDict?["gear_type"] as? String == "amp")
        #expect(metaDict?["tone_type"] as? String == "crunch")
    }

    @Test func includesDefaultMetadata() {
        let session = TrainingSession()
        let metadata = ModelMetadata() // Defaults to gear_type=amp, tone_type=crunch

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: metadata
        )

        // Default metadata has gear_type and tone_type, so it should be included
        let metaDict = args["user_metadata"] as? [String: Any]
        #expect(metaDict != nil)
        #expect(metaDict?["gear_type"] as? String == "amp")
        #expect(metaDict?["tone_type"] as? String == "crunch")
    }

    // MARK: - Architecture-Specific

    @Test func liteArchitectureValue() {
        let session = TrainingSession(architectureSize: .lite)

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        #expect(args["architecture"] as? String == "lite")
    }

    @Test func lstmLearningRate() {
        let session = TrainingSession(
            modelType: .lstm,
            learningRate: Defaults.learningRateLSTM
        )

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        #expect(args["lr"] as? Double == 0.01)
    }

    // MARK: - JSON Serialization

    @Test func serializesToValidJSON() throws {
        let session = TrainingSession()

        let args = builder.buildArguments(
            inputPath: "/input.wav",
            outputPath: "/output.wav",
            trainPath: "/train",
            session: session,
            metadata: nil
        )

        let json = try builder.serializeArguments(args)
        #expect(!json.isEmpty)

        // Verify it's valid JSON by parsing it back
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["epochs"] as? Int == 100)
    }
}
