import SwiftUI

struct ChatInputBarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    @Binding var draft: String
    let replyTarget: MessageReplyPreview?
    let isSending: Bool
    let canUseStudyFeatures: Bool
    let onSend: () -> Void
    let onAIHelp: () -> Void
    let onCancelReply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyTarget {
                ReplyComposerPreview(reply: replyTarget, onCancel: onCancelReply)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            TextField("Message", text: $draft, axis: .vertical)
                .focused($isFocused)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 2)
                .frame(minHeight: 22, alignment: .leading)

            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "paperclip")
                        .font(.callout)
                }
                .foregroundStyle(PremiumTheme.textSecondary)
                .accessibilityLabel("Attach")

                if canUseStudyFeatures {
                    Button(action: onAIHelp) {
                        Label("Hint", systemImage: "sparkles")
                            .font(.caption.weight(.medium))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.white)
                    .clipShape(Capsule())
                    .accessibilityLabel("Hint")
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "mic")
                        .font(.callout)
                }
                .foregroundStyle(PremiumTheme.textSecondary)
                .accessibilityLabel("Voice")

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(.white)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .background(inputBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.24), radius: 14, y: 7)
        .animation(AppMotion.inputFocus(reduceMotion: reduceMotion), value: isFocused)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: canUseStudyFeatures)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: replyTarget)
    }

    private var inputBackground: Color {
        Color(red: 0.075, green: 0.078, blue: 0.095).opacity(0.98)
    }
}

private struct ReplyComposerPreview: View {
    let reply: MessageReplyPreview
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(PremiumTheme.blue.opacity(0.95))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text(reply.text)
                    .font(.caption)
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PremiumTheme.textSecondary)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
