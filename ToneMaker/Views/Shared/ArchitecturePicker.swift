import SwiftUI

/// Combined picker for model architecture type and size.
struct ArchitecturePicker: View {
    @Binding var modelType: ModelArchitecture
    @Binding var size: ArchitectureSize

    var body: some View {
        Picker("Architecture", selection: $modelType) {
            ForEach(ModelArchitecture.allCases) { arch in
                Text(arch.rawValue).tag(arch)
            }
        }

        Picker("Size", selection: $size) {
            ForEach(ArchitectureSize.allCases) { size in
                VStack(alignment: .leading) {
                    Text(size.displayName)
                }
                .tag(size)
            }
        }
    }
}
