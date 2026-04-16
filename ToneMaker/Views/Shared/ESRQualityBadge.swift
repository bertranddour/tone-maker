import SwiftUI

/// Colored badge displaying ESR quality assessment.
struct ESRQualityBadge: View {
    let esr: Double

    private var quality: ESRQuality {
        ESRQuality.from(esr: esr)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: quality.symbolName)
            Text(quality.comment)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(quality.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(quality.color.opacity(0.12), in: Capsule())
    }
}
