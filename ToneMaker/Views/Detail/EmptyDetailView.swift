import SwiftUI

/// Placeholder shown when no session is selected.
struct EmptyDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Session",
            systemImage: "sidebar.left",
            description: Text("Choose a training session from the sidebar, or create a new one.")
        )
    }
}
