import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrainingEngine.self) private var engine
    @Query(sort: \TrainingSession.createdAt, order: .reverse)
    private var sessions: [TrainingSession]
    @Query(sort: \CaptureItem.createdAt, order: .reverse)
    private var captures: [CaptureItem]
    @Query(sort: \TrainingPreset.name)
    private var presets: [TrainingPreset]

    @State private var sidebarMode: SidebarMode = .profileStudio
    @State private var selectedSessionID: TrainingSession.ID?
    @State private var selectedLibraryItem: LibrarySidebarItem?
    @State private var selectedCapture: CaptureItem?
    @State private var sessionToDelete: TrainingSession?
    @State private var showDeleteConfirmation = false
    @State private var showCancelAllConfirmation = false

    // User preferences from Settings
    @AppStorage("defaultEpochs") private var defaultEpochs = Defaults.epochs
    @AppStorage("defaultArchitecture") private var defaultArchitecture = ModelArchitecture.waveNet.rawValue
    @AppStorage("defaultArchitectureSize") private var defaultArchitectureSize = ArchitectureSize.standard.rawValue

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Mode", selection: $sidebarMode) {
                    Label("Profile Studio", systemImage: "waveform.path")
                        .tag(SidebarMode.profileStudio)
                    Label("Library", systemImage: "square.grid.2x2")
                        .tag(SidebarMode.library)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.vertical, 40)

                switch sidebarMode {
                case .profileStudio:
                    studioSidebar
                case .library:
                    librarySidebar
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            switch sidebarMode {
            case .profileStudio:
                studioDetail
            case .library:
                libraryDetail
            }
        }
        .confirmationDialog(
            "Delete Training Session?",
            isPresented: $showDeleteConfirmation,
            presenting: sessionToDelete
        ) { session in
            Button("Delete", role: .destructive) {
                performDelete(session)
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: { session in
            if session.status.isActive {
                Text("'\(session.displayName)' is still active. Deleting it will stop training and cannot be undone.")
            } else {
                Text("Delete '\(session.displayName)'? This cannot be undone.")
            }
        }
        .confirmationDialog(
            "Cancel All Training?",
            isPresented: $showCancelAllConfirmation
        ) {
            Button("Cancel All", role: .destructive) {
                engine.cancelAll(modelContext: modelContext)
            }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("This stops the active training and removes every queued session from the queue.")
        }
        .focusedSceneValue(engine)
        .focusedSceneValue(\.selectedSession, selectedSession)
        .focusedSceneValue(\.trainingPresets, presets)
        .focusedSceneValue(\.createNewSessionAction, createNewSession)
        .focusedSceneValue(\.requestCancelAllAction, showCancelAllButton ? { showCancelAllConfirmation = true } : nil)
        .focusedSceneValue(\.showProfileStudioAction) {
            sidebarMode = .profileStudio
        }
        .focusedSceneValue(\.showLibraryAction) {
            sidebarMode = .library
        }
        .onChange(of: pendingSessionCount, initial: true) { _, newValue in
            TrainingNotifier.shared.updateDockBadge(pendingSessionCount: newValue)
        }
    }

    /// Count of sessions that are currently training or waiting in the queue.
    /// Drives the Dock tile badge so users can see at a glance whether the app
    /// still has work in flight when it's in the background.
    private var pendingSessionCount: Int {
        sessions.reduce(0) { count, session in
            switch session.status {
            case .queued, .validating, .training: count + 1
            default: count
            }
        }
    }

    private var selectedSession: TrainingSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    // MARK: - Sidebar Mode

    private enum SidebarMode: String, CaseIterable {
        case profileStudio
        case library
    }

    /// Sidebar categories group related gear types together.
    private enum SidebarCategory: String, CaseIterable {
        case amp      // amp, pedalAmp, ampCab, ampPedalCab
        case pedal
        case preamp
        case studio

        var displayName: String {
            switch self {
            case .amp: "Amp"
            case .pedal: "Pedal"
            case .preamp: "Preamp"
            case .studio: "Studio"
            }
        }

        var gearTypes: [GearType] {
            switch self {
            case .amp: [.amp, .pedalAmp, .ampCab, .ampPedalCab]
            case .pedal: [.pedal]
            case .preamp: [.preamp]
            case .studio: [.studio]
            }
        }

        static func category(for gearType: GearType) -> SidebarCategory {
            switch gearType {
            case .amp, .pedalAmp, .ampCab, .ampPedalCab: .amp
            case .pedal: .pedal
            case .preamp: .preamp
            case .studio: .studio
            }
        }
    }

    /// Composite sidebar selection: category + brand, or nil for "All Captures".
    private struct LibrarySidebarItem: Hashable {
        let category: SidebarCategory?
        let brand: String?

        static let all = LibrarySidebarItem(category: nil, brand: nil)
        var isAll: Bool { category == nil && brand == nil }
    }

    // MARK: - Profile Studio Sidebar

    @ViewBuilder
    private var studioSidebar: some View {
        List(selection: $selectedSessionID) {
            if !activeSessions.isEmpty {
                Section(activeSectionTitle) {
                    ForEach(activeSessions) { session in
                        SessionRowView(
                            session: session,
                            queuePosition: queuePosition(for: session)
                        ) {
                            sessionToDelete = session
                            showDeleteConfirmation = true
                        }
                    }
                    .onDelete { offsets in
                        requestDelete(from: activeSessions, at: offsets)
                    }
                }
            }

            if !completedSessions.isEmpty {
                Section("History") {
                    ForEach(completedSessions) { session in
                        SessionRowView(session: session, queuePosition: nil) {
                            sessionToDelete = session
                            showDeleteConfirmation = true
                        }
                    }
                    .onDelete { offsets in
                        requestDelete(from: completedSessions, at: offsets)
                    }
                }
            }

            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Training Sessions", systemImage: "waveform.path")
                } description: {
                    Text("Create a new training session to get started.")
                } actions: {
                    Button("New Training") {
                        createNewSession()
                    }
                }
            }
        }
        .navigationTitle("Profile Studio")
        .toolbar {
            if showCancelAllButton {
                ToolbarItem {
                    Button("Cancel All", systemImage: "xmark.circle") {
                        showCancelAllConfirmation = true
                    }
                    .help("Cancel active training and clear the queue")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Training", systemImage: "plus") {
                    createNewSession()
                }
            }
        }
    }

    private var activeSectionTitle: String {
        let queued = queuedSessions.count
        if queued > 0 {
            return "Active  \u{00B7}  \(queued) queued"
        }
        return "Active"
    }

    private var showCancelAllButton: Bool {
        engine.isTraining || !queuedSessions.isEmpty
    }

    private var queuedSessions: [TrainingSession] {
        sessions
            .filter { $0.status == .queued }
            .sorted { ($0.queuedAt ?? .distantFuture) < ($1.queuedAt ?? .distantFuture) }
    }

    /// 1-based queue position for a queued session, or nil if not queued.
    private func queuePosition(for session: TrainingSession) -> Int? {
        guard session.status == .queued else { return nil }
        return queuedSessions.firstIndex(of: session).map { $0 + 1 }
    }

    // MARK: - Library Sidebar

    @ViewBuilder
    private var librarySidebar: some View {
        List(selection: $selectedLibraryItem) {
            Label("All Captures", systemImage: "square.grid.2x2")
                .tag(LibrarySidebarItem.all)

            ForEach(SidebarCategory.allCases, id: \.self) { category in
                let brands = brandsForCategory(category)
                if !brands.isEmpty {
                    Section(category.displayName) {
                        ForEach(brands, id: \.self) { brand in
                            Label(brand.isEmpty ? "NoBrand" : brand, systemImage: "amplifier")
                                .tag(LibrarySidebarItem(category: category, brand: brand))
                        }
                    }
                }
            }

            // Captures without a gear type
            let uncategorized = captures.filter { $0.gearType == nil }
            if !uncategorized.isEmpty {
                let brands = uncategorized.map(\.brand).uniqueSorted
                Section("Other") {
                    ForEach(brands, id: \.self) { brand in
                        Label(brand.isEmpty ? "NoBrand" : brand, systemImage: "amplifier")
                            .tag(LibrarySidebarItem(category: .amp, brand: brand))
                    }
                }
            }

            if captures.isEmpty {
                ContentUnavailableView {
                    Label("No Captures", systemImage: "square.grid.2x2")
                } description: {
                    Text("Train a model to add it to your library.")
                }
            }
        }
        .navigationTitle("Library")
    }

    // MARK: - Profile Studio Detail

    @ViewBuilder
    private var studioDetail: some View {
        if let selectedSessionID,
           let session = sessions.first(where: { $0.id == selectedSessionID }) {
            detailView(for: session)
        } else {
            EmptyDetailView()
        }
    }

    @ViewBuilder
    private func detailView(for session: TrainingSession) -> some View {
        switch session.status {
        case .configuring:
            TrainingConfigView(session: session)
        case .queued, .validating, .training, .completed, .failed, .cancelled:
            TrainingDashboardView(session: session)
        }
    }

    // MARK: - Library Detail

    @ViewBuilder
    private var libraryDetail: some View {
        if let item = selectedLibraryItem, !item.isAll,
           let category = item.category, let brand = item.brand {
            let gearTypes = category.gearTypes
            let filtered = captures.filter { gearTypes.contains($0.gearType ?? .amp) && $0.brand == brand }
            LibraryGridView(captures: filtered, selectedCapture: $selectedCapture)
                .navigationTitle(brand.isEmpty ? "NoBrand" : brand)
        } else {
            LibraryGridView(captures: captures, selectedCapture: $selectedCapture)
                .navigationTitle("All Captures")
        }
    }

    // MARK: - Computed Lists

    private var activeSessions: [TrainingSession] {
        sessions.filter { $0.status.isActive }
    }

    private var completedSessions: [TrainingSession] {
        sessions.filter { !$0.status.isActive }
    }

    private func brandsForCategory(_ category: SidebarCategory) -> [String] {
        let gearTypes = category.gearTypes
        return captures.filter { gearTypes.contains($0.gearType ?? .amp) }
            .map(\.brand)
            .uniqueSorted
    }

    // MARK: - Actions

    private func createNewSession() {
        withAnimation {
            let arch = ModelArchitecture(rawValue: defaultArchitecture) ?? .waveNet
            let size = ArchitectureSize(rawValue: defaultArchitectureSize) ?? .standard
            let session = TrainingSession(
                modelType: arch,
                architectureSize: size,
                epochs: defaultEpochs,
                learningRate: Defaults.learningRate(for: arch),
                learningRateDecay: Defaults.learningRateDecay,
                batchSize: Defaults.batchSize
            )
            modelContext.insert(session)
            selectedSessionID = session.id
        }
    }

    private func requestDelete(from list: [TrainingSession], at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        sessionToDelete = list[index]
        showDeleteConfirmation = true
    }

    private func performDelete(_ session: TrainingSession) {
        withAnimation {
            if session.status.isActive {
                engine.cancelTraining(session: session)
            }
            if selectedSessionID == session.id {
                selectedSessionID = nil
            }
            modelContext.delete(session)
            sessionToDelete = nil
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    @Bindable var session: TrainingSession
    var queuePosition: Int?
    var onDelete: () -> Void

    @FocusState private var isRenaming: Bool

    var body: some View {
        HStack {
            Image(systemName: session.status.symbolName)
                .foregroundStyle(session.status.tintColor)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Session Name", text: sessionNameBinding)
                    .focused($isRenaming)
                    .textFieldStyle(.plain)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(session.modelType.rawValue)
                    Text("\u{2014}")
                    Text(session.architectureSize.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let position = queuePosition {
                Text("#\(position)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12))
                    .clipShape(Capsule())
            } else if let esr = session.bestValidationESR {
                Text(String(format: "%.4f", esr))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .tag(session.id)
        .contextMenu {
            RenameButton()
            Divider()
            Button("Delete\u{2026}", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .renameAction { isRenaming = true }
    }

    private var sessionNameBinding: Binding<String> {
        Binding(
            get: { session.sessionName ?? session.displayName },
            set: { session.sessionName = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Array Extension

extension Array where Element == String {
    /// Returns unique strings sorted alphabetically.
    var uniqueSorted: [String] {
        Array(Set(self)).sorted()
    }
}

#Preview {
    ContentView()
        .environment(TrainingEngine())
        .modelContainer(
            for: [TrainingSession.self, BatchItem.self, ModelMetadata.self, TrainingPreset.self,
                  PersistedAudioFile.self, CaptureItem.self],
            inMemory: true
        )
}
