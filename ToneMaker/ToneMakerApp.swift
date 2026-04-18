import SwiftUI
import SwiftData

@main
struct ToneMakerApp: App {

    @State private var trainingEngine = TrainingEngine()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrainingSession.self,
            BatchItem.self,
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
        .commands {
            CommandGroup(after: .appSettings) {
                ManagePresetsCommand()
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 520, height: 480)
        #endif
    }
}

/// Adds "Manage Presets…" to the app menu next to "Settings…".
///
/// Extracted into its own view so the `@AppStorage` and `@Environment` reads
/// happen in a view context (CommandGroup's content is a ViewBuilder).
private struct ManagePresetsCommand: View {
    @AppStorage("selectedSettingsTab") private var selectedTab = SettingsTab.environment
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Manage Presets\u{2026}") {
            selectedTab = .presets
            openSettings()
        }
    }
}
