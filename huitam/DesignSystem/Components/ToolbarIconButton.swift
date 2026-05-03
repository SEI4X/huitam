import SwiftUI

struct ToolbarIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(PremiumTheme.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(PremiumTheme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .tint(.white)
        .accessibilityLabel(title)
    }
}
