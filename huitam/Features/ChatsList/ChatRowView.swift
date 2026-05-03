import SwiftUI

struct ChatRowView: View {
    @Environment(\.appTintColor) private var tintColor

    let chat: ChatSummary
    var presence: PresenceStatus = .offline

    var body: some View {
        HStack(spacing: 12) {
            PresenceAvatarView(
                systemImage: chat.participant.avatarSystemImage,
                size: 44,
                seed: chat.participant.id,
                presence: presence
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(chat.participant.displayName)
                        .font(.body)
                        .fontWeight(chat.unreadCount > 0 ? .semibold : .regular)
                        .foregroundStyle(PremiumTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(chat.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(PremiumTheme.textTertiary)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Text(chat.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(PremiumTheme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(tintColor, in: Circle())
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: roleIconName)
                        .font(.caption2.weight(.semibold))

                    Text(roleSummary)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(PremiumTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PremiumTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var roleIconName: String {
        switch (chat.currentUserRole.isLearner, chat.participantRole.isLearner) {
        case (true, true): "arrow.left.arrow.right.circle"
        case (true, false): "graduationcap"
        case (false, true): "bubble.left.and.bubble.right"
        case (false, false): "message"
        }
    }

    private var roleSummary: String {
        switch (chat.currentUserRole.learningLanguage, chat.participantRole.learningLanguage) {
        case let (.some(myLanguage), .some(theirLanguage)):
            "You: \(myLanguage.shortCode) · Them: \(theirLanguage.shortCode)"
        case let (.some(myLanguage), .none):
            "You practice \(myLanguage.shortCode)"
        case let (.none, .some(theirLanguage)):
            "They practice \(theirLanguage.shortCode)"
        case (.none, .none):
            "Just chatting"
        }
    }
}
