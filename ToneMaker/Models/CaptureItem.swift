import Foundation
import SwiftData

/// A trained .nam capture stored in the library.
///
/// Created automatically when training completes successfully. Stores the .nam file data
/// with `@Attribute(.externalStorage)` for efficient CloudKit sync as CKAssets.
@Model
final class CaptureItem {

    // MARK: - Identity

    var id: UUID = UUID()
    var createdAt: Date = Date()

    // MARK: - Metadata (copied from session at training time)

    var name: String = ""
    var brand: String = ""
    var model: String = ""
    var modeledBy: String = ""
    var gearTypeRaw: String?
    var toneTypeRaw: String?

    // MARK: - Calibration

    var inputLevelDBu: Double?
    var outputLevelDBu: Double?

    // MARK: - Training Results

    var validationESR: Double?
    var architectureRaw: String = ModelArchitecture.waveNet.rawValue
    var architectureSizeRaw: String = ArchitectureSize.standard.rawValue

    // MARK: - Model File

    @Attribute(.externalStorage) var modelFileData: Data = Data()
    var modelFileName: String = ""

    // MARK: - Relationships

    @Relationship(inverse: \TrainingSession.captures)
    var sourceSession: TrainingSession?

    @Relationship(inverse: \BatchItem.capture)
    var sourceBatchItem: BatchItem?

    init() {}
}

// MARK: - Typed Enum Access

extension CaptureItem {

    var gearType: GearType? {
        get { gearTypeRaw.flatMap { GearType(rawValue: $0) } }
        set { gearTypeRaw = newValue?.rawValue }
    }

    var toneType: ToneType? {
        get { toneTypeRaw.flatMap { ToneType(rawValue: $0) } }
        set { toneTypeRaw = newValue?.rawValue }
    }

    var architecture: ModelArchitecture {
        get { ModelArchitecture(rawValue: architectureRaw) ?? .waveNet }
        set { architectureRaw = newValue.rawValue }
    }

    var architectureSize: ArchitectureSize {
        get { ArchitectureSize(rawValue: architectureSizeRaw) ?? .standard }
        set { architectureSizeRaw = newValue.rawValue }
    }

    var displayName: String {
        name.isEmpty ? "Untitled Capture" : name
    }
}
