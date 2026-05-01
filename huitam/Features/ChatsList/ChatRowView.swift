import SwiftUI

struct ChatRowView: View {
    @Environment(\.appTintColor) private var tintColor

    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(systemImage: chat.participant.avatarSystemImage, size: 42, seed: chat.participant.id)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.participant.displayName)
                        .font(.body)
                        .fontWeight(chat.unreadCount > 0 ? .semibold : .regular)
                    Spacer()
                    Text(chat.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(chat.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
