import Foundation
import SwiftData

/// User-provided metadata embedded in the exported .nam model file.
///
/// Maps directly to NAM's `UserMetadata` Pydantic model (metadata.py:44-68).
/// All fields are optional - users can fill in as much or as little as they want.
@Model
final class ModelMetadata {

    var id: UUID = UUID()

    var namName: String?
    var modeledBy: String?
    var gearMake: String?
    var gearModel: String?

    /// Raw string backing for `GearType`.
    var gearTypeRaw: String?
    /// Raw string backing for `ToneType`.
    var toneTypeRaw: String?

    /// Analog loudness in dBu corresponding to 0 dBFS input to the model.
    var inputLevelDBu: Double?
    /// Analog loudness in dBu corresponding to 0 dBFS output from the model.
    var outputLevelDBu: Double?

    @Relationship(inverse: \TrainingSession.metadata)
    var session: TrainingSession?

    init(
        id: UUID = UUID(),
        namName: String? = nil,
        modeledBy: String? = nil,
        gearMake: String? = nil,
        gearModel: String? = nil,
        gearType: GearType? = .amp,
        toneType: ToneType? = .crunch,
        inputLevelDBu: Double? = nil,
        outputLevelDBu: Double? = nil
    ) {
        self.id = id
        self.namName = namName
        self.modeledBy = modeledBy
        self.gearMake = gearMake
        self.gearModel = gearModel
        self.gearTypeRaw = gearType?.rawValue
        self.toneTypeRaw = toneType?.rawValue
        self.inputLevelDBu = inputLevelDBu
        self.outputLevelDBu = outputLevelDBu
    }
}

// MARK: - Typed Enum Access

extension ModelMetadata {

    var gearType: GearType? {
        get { gearTypeRaw.flatMap { GearType(rawValue: $0) } }
        set { gearTypeRaw = newValue?.rawValue }
    }

    var toneType: ToneType? {
        get { toneTypeRaw.flatMap { ToneType(rawValue: $0) } }
        set { toneTypeRaw = newValue?.rawValue }
    }

    /// Whether any metadata field has been filled in.
    var hasContent: Bool {
        namName != nil || modeledBy != nil || gearMake != nil || gearModel != nil
            || gearTypeRaw != nil || toneTypeRaw != nil
            || inputLevelDBu != nil || outputLevelDBu != nil
    }
}
