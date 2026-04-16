import SwiftUI

/// A color-coded square thumbnail for displaying a capture in the library grid.
///
/// Plain background colored by tone type, rig name centered, brand/model bottom-right.
/// PED/CAB labels indicate pedal and cabinet chain components.
struct CaptureGridCell: View {
    let capture: CaptureItem
    let isSelected: Bool

    private var showPed: Bool {
        capture.gearType == .pedalAmp || capture.gearType == .ampPedalCab
    }

    private var showCab: Bool {
        capture.gearType == .ampCab || capture.gearType == .ampPedalCab
    }

    var body: some View {
        ZStack {
            // Centered rig name
            Text(capture.displayName)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(.white)
                .padding(12)

            // PED / CAB labels top corners
            if showPed || showCab {
                VStack {
                    HStack {
                        if showPed {
                            Text("PED")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        if showCab {
                            Text("CAB")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }

            // Brand / Model bottom-right
            if !capture.brand.isEmpty || !capture.model.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            if !capture.brand.isEmpty {
                                Text(capture.brand)
                                    .font(.caption2.weight(.semibold))
                            }
                            if !capture.model.isEmpty {
                                Text(capture.model)
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(toneColor.opacity(isSelected ? 1.0 : 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var toneColor: Color {
        capture.toneType?.color ?? .secondary
    }
}
