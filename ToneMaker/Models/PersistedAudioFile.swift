import Foundation
import SwiftData

/// Persists the actual audio file data for a training session.
///
/// Each file is stored individually with `@Attribute(.externalStorage)` so SwiftData
/// keeps the binary data adjacent to the SQLite store (and as CKAssets with CloudKit).
@Model
final class PersistedAudioFile {

    var id: UUID = UUID()
    var fileName: String = ""
    var roleRaw: String = AudioFileRole.output.rawValue
    var order: Int = 0

    @Attribute(.externalStorage) var fileData: Data = Data()

    @Relationship(inverse: \TrainingSession.persistedAudioFiles)
    var session: TrainingSession?

    init(
        id: UUID = UUID(),
        fileName: String,
        role: AudioFileRole,
        order: Int = 0,
        fileData: Data
    ) {
        self.id = id
        self.fileName = fileName
        self.roleRaw = role.rawValue
        self.order = order
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
