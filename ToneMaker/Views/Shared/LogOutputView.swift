import SwiftUI

/// Auto-scrolling monospace text view for displaying training log output.
struct LogOutputView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
                    .id("logBottom")
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onChange(of: text) {
                withAnimation {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }
}
