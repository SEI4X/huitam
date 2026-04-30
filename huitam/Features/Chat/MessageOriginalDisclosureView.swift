import SwiftUI

struct MessageOriginalDisclosureView: View {
    let originalText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(originalText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
