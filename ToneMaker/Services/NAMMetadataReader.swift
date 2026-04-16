import Foundation
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "NAMMetadataReader")

/// Extracted metadata from a .nam file.
nonisolated struct NAMMetadata: Sendable {
    var name: String?
    var modeledBy: String?
    var gearMake: String?
    var gearModel: String?
    var gearType: String?
    var toneType: String?
    var inputLevelDBu: Double?
    var outputLevelDBu: Double?
}

/// Reads embedded metadata from .nam model files (JSON format).
nonisolated struct NAMMetadataReader: Sendable {

    /// Reads metadata from a .nam file at the given path.
    static func readMetadata(from filePath: String) -> NAMMetadata? {
        logger.info("Reading metadata from: \(filePath)")

        guard let data = FileManager.default.contents(atPath: filePath) else {
            logger.error("Failed to read file: \(filePath)")
            return nil
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Not a JSON .nam file: \(filePath)")
            return nil
        }

        logger.debug("JSON .nam file, top-level keys: \(root.keys.sorted().joined(separator: ", "))")

        let dict: [String: Any]
        if let metadata = root["metadata"] as? [String: Any] {
            dict = metadata
        } else if let um = root["user_metadata"] as? [String: Any] {
            dict = um
        } else {
            logger.info("No metadata found in .nam file")
            return nil
        }

        guard !dict.isEmpty else {
            logger.info("Empty metadata in .nam file")
            return nil
        }

        logger.info("Extracted metadata keys: \(dict.keys.sorted().joined(separator: ", "))")

        var meta = NAMMetadata()
        meta.name = dict["name"] as? String
        meta.modeledBy = dict["modeled_by"] as? String
        meta.gearMake = dict["gear_make"] as? String
        meta.gearModel = dict["gear_model"] as? String
        meta.gearType = stringValue(dict["gear_type"])
        meta.toneType = stringValue(dict["tone_type"])
        meta.inputLevelDBu = dict["input_level_dbu"] as? Double
        meta.outputLevelDBu = dict["output_level_dbu"] as? Double
        return meta
    }

    /// Extracts a string value, handling both plain strings and enum-like objects.
    private static func stringValue(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any], let v = dict["value"] as? String { return v }
        return nil
    }
}
