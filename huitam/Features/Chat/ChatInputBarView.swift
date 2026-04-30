import SwiftUI

struct ChatInputBarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    @Binding var draft: String
    let isSending: Bool
    let canUseStudyFeatures: Bool
    let onSend: () -> Void
    let onAIHelp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .focused($isFocused)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 2)

            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "paperclip")
                        .font(.callout)
                }
                .accessibilityLabel("Attach")

                if canUseStudyFeatures {
                    Button(action: onAIHelp) {
                        Label("Hint", systemImage: "sparkles")
                            .font(.caption.weight(.medium))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .clipShape(Capsule())
                    .accessibilityLabel("Hint")
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "mic")
                        .font(.callout)
                }
                .accessibilityLabel("Voice")

                Button(action: onSend) {
                    Image(systemName: isSending ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .animation(AppMotion.inputFocus(reduceMotion: reduceMotion), value: isFocused)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: canUseStudyFeatures)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: isSending)
    }
}
