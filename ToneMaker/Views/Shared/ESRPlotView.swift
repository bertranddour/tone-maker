import SwiftUI

/// Displays the ESR comparison plot image from disk.
struct ESRPlotView: View {
    let imagePath: String

    var body: some View {
        if let nsImage = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ContentUnavailableView(
                "Plot Not Available",
                systemImage: "chart.xyaxis.line",
                description: Text("The comparison plot could not be loaded.")
            )
        }
    }
}
