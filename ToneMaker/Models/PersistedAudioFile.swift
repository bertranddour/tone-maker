import Foundation
import SwiftData

/// Persists the actual audio file data for a training session.
///
/// `@Attribute(.externalStorage)` keeps the binary data adjacent to the SQLite store
/// (and becomes a CKAsset when CloudKit sync is enabled). Input (reference) files
/// attach to the `TrainingSession` directly; output (reamped) files attach to a
/// `BatchItem` via `batchItem`.
@Model
final class PersistedAudioFile {

    var id: UUID = UUID()
    var fileName: String = ""
    var roleRaw: String = AudioFileRole.output.rawValue

    @Attribute(.externalStorage) var fileData: Data = Data()

    @Relationship(inverse: \TrainingSession.persistedAudioFiles)
    var session: TrainingSession?

    @Relationship(inverse: \BatchItem.persistedOutputFile)
    var batchItem: BatchItem?

    init(
        id: UUID = UUID(),
        fileName: String,
        role: AudioFileRole,
        fileData: Data
    ) {
        self.id = id
        self.fileName = fileName
        self.roleRaw = role.rawValue
        self.fileData = fileData
    }
}

// MARK: - Typed Enum Access

extension PersistedAudioFile {

    var role: AudioFileRole {
        get { AudioFileRole(rawValue: roleRaw) ?? .output }
        set { roleRaw = newValue.rawValue }
    }
}
