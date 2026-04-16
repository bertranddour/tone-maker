import SwiftUI

/// Banner displaying validation warnings or errors.
struct ValidationBannerView: View {
    let warnings: [String]
    let errors: [String]

    init(warnings: [String] = [], errors: [String] = []) {
        self.warnings = warnings
        self.errors = errors
    }

    var body: some View {
        if !errors.isEmpty {
            bannerContent(
                messages: errors,
                icon: "xmark.octagon.fill",
                color: .red,
                title: "Validation Errors"
            )
        }

        if !warnings.isEmpty {
            bannerContent(
                messages: warnings,
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                title: "Warnings"
            )
        }
    }

    private func bannerContent(
        messages: [String],
        icon: String,
        color: Color,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(color)

            ForEach(messages, id: \.self) { message in
                Text("- \(message)")
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
