import SwiftUI
import SwiftData

/// Where ToneMaker lives — used by the Help menu.
private nonisolated let helpURL = URL(string: "https://github.com/bertranddour/tone-maker")!

// MARK: - Focused Values

/// Focused values let menu commands read the active window's state.
///
/// ContentView and TrainingConfigView publish these via `focusedSceneValue(_:_:)`;
/// menu command views read them via `@FocusedValue(\.key)`. Entries go nil when
/// no window is key, which disables dependent menu items automatically.
extension FocusedValues {
    @Entry var selectedSession: TrainingSession?
    @Entry var createNewSessionAction: (() -> Void)?
    @Entry var requestCancelAllAction: (() -> Void)?
    @Entry var showProfileStudioAction: (() -> Void)?
    @Entry var showLibraryAction: (() -> Void)?
    @Entry var showSavePresetAction: (() -> Void)?
}

// MARK: - Umbrella

/// Top-level composition of every app-specific menu / menu-extension.
struct AppCommands: Commands {
    var body: some Commands {
        FileMenuCommands()
        ViewMenuCommands()
        TrainingMenuCommands()
        PresetsMenuCommands()
        HelpMenuCommands()
    }
}

// MARK: - File Menu

/// Replaces the default `New Window` with `New Training`.
private struct FileMenuCommands: Commands {
    @FocusedValue(\.createNewSessionAction) private var createNewSession

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Training") {
                createNewSession?()
            }
            .keyboardShortcut("n")
            .disabled(createNewSession == nil)
        }
    }
}

// MARK: - View Menu

/// Adds sidebar-mode switches after the Show/Hide Sidebar group.
private struct ViewMenuCommands: Commands {
    @FocusedValue(\.showProfileStudioAction) private var showProfileStudio
    @FocusedValue(\.showLibraryAction) private var showLibrary

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button("Profile Studio", systemImage: "waveform.path") {
                showProfileStudio?()
            }
            .keyboardShortcut("1")
            .disabled(showProfileStudio == nil)

            Button("Library", systemImage: "square.grid.2x2") {
                showLibrary?()
            }
            .keyboardShortcut("2")
            .disabled(showLibrary == nil)
        }
    }
}

// MARK: - Training Menu

/// Top-level `Training` menu — lifecycle actions for the selected session.
private struct TrainingMenuCommands: Commands {
    @FocusedValue(TrainingEngine.self) private var engine
    @FocusedValue(\.selectedSession) private var session
    @FocusedValue(\.requestCancelAllAction) private var requestCancelAll

    var body: some Commands {
        CommandMenu("Training") {
            Button("Start Training") {
                guard let engine, let session, let ctx = session.modelContext else { return }
                engine.enqueueTraining(session: session, modelContext: ctx)
            }
            .keyboardShortcut("r")
            .disabled(!canStart)

            Button("Cancel Training") {
                guard let engine, let session else { return }
                engine.cancelTraining(session: session)
            }
            .keyboardShortcut(".")
            .disabled(!canCancel)

            Divider()

            Button("Cancel All Training") {
                requestCancelAll?()
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(requestCancelAll == nil)
        }
    }

    private var canStart: Bool {
        session?.status == .configuring
    }

    private var canCancel: Bool {
        guard let status = session?.status else { return false }
        return status == .training || status == .validating || status == .queued
    }
}

// MARK: - Presets Menu

/// Top-level `Presets` menu — save / apply / update / manage.
private struct PresetsMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Presets") {
            PresetsMenuContent()
        }
    }
}

/// Extracted so `@Query` and other dynamic properties bind correctly inside the
/// commands hierarchy.
private struct PresetsMenuContent: View {
    @Query(sort: \TrainingPreset.name) private var presets: [TrainingPreset]
    @FocusedValue(\.selectedSession) private var session
    @FocusedValue(\.showSavePresetAction) private var showSavePreset

    @AppStorage("selectedSettingsTab") private var selectedTab = SettingsTab.environment
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Save Current as Preset\u{2026}") {
            showSavePreset?()
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(showSavePreset == nil)

        Divider()

        Menu("Apply Preset") {
            ForEach(presets) { preset in
                Button(preset.name) {
                    if let session { preset.apply(to: session) }
                }
            }
        }
        .disabled(session == nil || presets.isEmpty)

        Menu("Update Preset from Current") {
            ForEach(presets) { preset in
                Button(preset.name) {
                    if let session { preset.update(from: session) }
                }
            }
        }
        .disabled(session == nil || presets.isEmpty)

        Divider()

        Button("Manage Presets\u{2026}") {
            selectedTab = .presets
            openSettings()
        }
    }
}

// MARK: - Help Menu

/// Replaces the default Help entry with a link to the project on GitHub.
private struct HelpMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Link("ToneMaker Help", destination: helpURL)
                .keyboardShortcut("?")
        }
    }
}
