import SwiftUI
import SwiftData

@main
struct ToneMakerApp: App {

    @State private var trainingEngine = TrainingEngine()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrainingSession.self,
            ModelMetadata.self,
            TrainingPreset.self,
            PersistedAudioFile.self,
            CaptureItem.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1100, minHeight: 700)
                .environment(trainingEngine)
        }
        .modelContainer(sharedModelContainer)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 800)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        .defaultSize(width: 520, height: 480)
        #endif
    }
}
