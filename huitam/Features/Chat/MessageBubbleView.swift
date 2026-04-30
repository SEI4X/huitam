import SwiftUI
import UIKit

struct MessageBubbleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTintColor) private var tintColor

    let message: ChatMessage
    let isOriginalVisible: Bool
    let isCorrectionVisible: Bool
    let canUseStudyFeatures: Bool
    let onOriginalTap: () -> Void
    let onCorrectionToggle: () -> Void
    let onAnalyzeTap: () -> Void

    var body: some View {
        let shouldReduceMotion = reduceMotion

        HStack {
            if message.direction == .outgoing {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 8) {
                messageContent

                if message.direction == .incoming && message.originalText.isEmpty == false {
                    Button {
                        withAnimation(AppMotion.bubbleReveal(reduceMotion: reduceMotion)) {
                            onOriginalTap()
                        }
                    } label: {
                        Text(isOriginalVisible ? "Hide original" : "Show original")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(message.direction == .outgoing ? .white.opacity(0.82) : .secondary)
                }

                if isOriginalVisible {
                    MessageOriginalDisclosureView(originalText: message.originalText)
                }

                if let correction = message.correction {
                    MessageCorrectionView(
                        correction: correction,
                        isVisible: isCorrectionVisible,
                        isOutgoing: message.direction == .outgoing,
                        onToggle: {
                            withAnimation(AppMotion.bubbleReveal(reduceMotion: reduceMotion)) {
                                onCorrectionToggle()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                if canUseStudyFeatures {
                    Button("Break Into Words", systemImage: "text.magnifyingglass", action: onAnalyzeTap)
                }
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = message.translatedText
                }
            }

            if message.direction == .incoming {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .scrollTransition(.animated, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.88)
                .scaleEffect(phase.isIdentity || shouldReduceMotion ? 1 : 0.985)
                .offset(y: phase.isIdentity || shouldReduceMotion ? 0 : phase.value * -6)
        }
    }

    private var bubbleFill: some ShapeStyle {
        message.direction == .outgoing ? AnyShapeStyle(tintColor) : AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private var messageContent: some View {
        Text(message.translatedText)
            .font(.body)
            .foregroundStyle(message.direction == .outgoing ? .white : .primary)
            .contentShape(Rectangle())
            .onTapGesture {
                if canUseStudyFeatures {
                    onAnalyzeTap()
                }
            }
    }
}

private struct MessageCorrectionView: View {
    let correction: MessageCorrection
    let isVisible: Bool
    let isOutgoing: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(isOutgoing ? Color.white.opacity(0.34) : Color(.separator))

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text(isVisible ? "Hide correction" : "Show correction")
                Spacer(minLength: 4)
                Image(systemName: isVisible ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isOutgoing ? .white.opacity(0.86) : .secondary)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    onToggle()
                }
            )

            if isVisible {
                VStack(alignment: .leading, spacing: 6) {
                    Text(correction.correctedText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(isOutgoing ? .white : .primary)
                        .textSelection(.enabled)

                    Text(correction.explanation)
                        .font(.caption)
                        .foregroundStyle(isOutgoing ? .white.opacity(0.78) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
