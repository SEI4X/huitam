import SwiftUI

struct FriendSearchRowView: View {
    let result: FriendSearchResult

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(systemImage: result.avatarSystemImage, size: 36, seed: result.id)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.displayName)
                    .font(.body)
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text("@\(result.nickname)")
                    .font(.caption)
                    .foregroundStyle(PremiumTheme.textSecondary)
            }
            Spacer()
            Text(result.nativeLanguage.shortCode)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PremiumTheme.textTertiary)
        }
        .padding(.vertical, 6)
    }
}
