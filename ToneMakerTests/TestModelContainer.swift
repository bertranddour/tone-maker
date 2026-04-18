import Foundation
import SwiftData
@testable import ToneMaker

/// Builds an ephemeral disk-backed `ModelContainer` registering every app model.
///
/// Disk-backed ephemeral store: a unique temp file per call gives each test an
/// isolated store that the OS reclaims automatically.
///
/// The caller must retain this container for the test's lifetime: `ModelContext`
/// does not keep its `ModelContainer` alive on its own, and accessing a context
/// whose container was released causes the first `insert` to crash.
/// `TrainingEngineTests.TestEnv` holds the pair.
///
/// `cloudKitDatabase: .none` skips CloudKit compatibility validation that the
/// test bundle would otherwise inherit via the app target's entitlements.
@MainActor
func makeTestModelContainer() throws -> ModelContainer {
    let schema = Schema([
        TrainingSession.self,
        BatchItem.self,
        ModelMetadata.self,
        TrainingPreset.self,
        PersistedAudioFile.self,
        CaptureItem.self,
    ])
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ToneMakerTest-\(UUID().uuidString).store")
    let config = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: config)
}
