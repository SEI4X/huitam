import SwiftUI

struct MessageOriginalDisclosureView: View {
    let originalText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .overlay(Color.white.opacity(0.16))
            Text(originalText)
                .font(.callout)
                .foregroundStyle(PremiumTheme.textSecondary)
                .textSelection(.enabled)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
