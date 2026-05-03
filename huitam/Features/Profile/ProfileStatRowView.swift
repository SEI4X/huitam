import SwiftUI

struct ProfileStatRowView: View {
    let title: String
    let value: String
    let systemImage: String
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(PremiumTheme.textSecondary)

            Spacer()

            Text(value)
                .foregroundStyle(PremiumTheme.textPrimary)
        }
        .listRowBackground(PremiumTheme.surface)
    }
}
