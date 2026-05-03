import SwiftUI

struct ChatStatsView: View {
    let chat: ChatSummary
    let messages: [ChatMessage]

    private var incomingCount: Int {
        messages.filter { $0.direction == .incoming }.count
    }

    private var outgoingCount: Int {
        messages.filter { $0.direction == .outgoing }.count
    }

    private var practicedWords: Int {
        messages
            .flatMap { $0.translatedText.split(separator: " ") }
            .count
    }

    private var correctedMessages: [ChatMessage] {
        messages.filter { $0.correction != nil }
    }

    var body: some View {
        List {
            Section {
                ChatStatsHeaderView(chat: chat, totalMessages: messages.count)
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Conversation") {
                ProfileStatRowView(title: "Total messages", value: "\(messages.count)", systemImage: "message")
                ProfileStatRowView(title: "Incoming", value: "\(incomingCount)", systemImage: "arrow.down.left")
                ProfileStatRowView(title: "Outgoing", value: "\(outgoingCount)", systemImage: "arrow.up.right")
                ProfileStatRowView(title: "Practiced words", value: "\(practicedWords)", systemImage: "textformat")
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Languages") {
                ProfileStatRowView(title: "You practice", value: chat.practiceLanguage?.displayName ?? "Off", systemImage: "graduationcap")
                ProfileStatRowView(title: "\(chat.participant.displayName) writes", value: chat.participant.nativeLanguage.displayName, systemImage: "globe")
                ProfileStatRowView(title: "Your language", value: chat.nativeLanguage.displayName, systemImage: "person")
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Practice Signals") {
                ProfileStatRowView(title: "Originals available", value: "\(messages.filter { !$0.originalText.isEmpty }.count)", systemImage: "text.bubble")
                ProfileStatRowView(title: "Read messages", value: "\(messages.filter { $0.deliveryState == .read }.count)", systemImage: "checkmark.circle")
                ProfileStatRowView(title: "Saved candidates", value: "\(max(practicedWords / 5, 1))", systemImage: "bookmark")
                ProfileStatRowView(title: "AI corrections", value: "\(correctedMessages.count)", systemImage: "sparkles")
            }
            .listRowBackground(PremiumTheme.surface)

            if correctedMessages.isEmpty == false {
                Section("Errors") {
                    ForEach(correctedMessages) { message in
                        if let correction = message.correction {
                            ChatErrorRowView(correction: correction)
                        }
                    }
                }
                .listRowBackground(PremiumTheme.surface)
            }
        }
        .premiumScrollBackground(glowPosition: .top, intensity: 0.66)
        .navigationTitle("Chat Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChatStatsHeaderView: View {
    let chat: ChatSummary
    let totalMessages: Int

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(systemImage: chat.participant.avatarSystemImage, size: 48, seed: chat.participant.id)
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.participant.displayName)
                    .font(.headline)
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text("@\(chat.participant.nickname)")
                    .font(.subheadline)
                    .foregroundStyle(PremiumTheme.textSecondary)
            }
            Spacer()
            Text("\(totalMessages)")
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 8)
    }
}

private struct ChatErrorRowView: View {
    let correction: MessageCorrection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(.orange)
                Text(correction.mistakeText)
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .strikethrough()
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.bubble")
                    .foregroundStyle(.green)
                Text(correction.correctedText)
                    .foregroundStyle(PremiumTheme.textPrimary)
            }

            Text(correction.explanation)
                .font(.caption)
                .foregroundStyle(PremiumTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
