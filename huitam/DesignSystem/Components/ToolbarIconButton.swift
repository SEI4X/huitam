import SwiftUI

struct ToolbarIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .accessibilityLabel(title)
    }
}
