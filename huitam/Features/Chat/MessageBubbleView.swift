import SwiftUI
import UIKit

struct MessageBubbleView: View, Equatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: ChatMessage
    let isOriginalVisible: Bool
    let isCorrectionVisible: Bool
    let canUseStudyFeatures: Bool
    let maxBubbleWidth: CGFloat
    let onOriginalTap: () -> Void
    let onCorrectionToggle: () -> Void
    let onReplySwipe: () -> Void
    let onAnalyzeTap: () -> Void
    let onRetryTap: () -> Void
    let onDeleteTap: () -> Void
    let onShareTap: () -> Void
    let onReplyPreviewTap: (MessageReplyPreview) -> Void

    static func == (lhs: MessageBubbleView, rhs: MessageBubbleView) -> Bool {
        lhs.message == rhs.message &&
            lhs.isOriginalVisible == rhs.isOriginalVisible &&
            lhs.isCorrectionVisible == rhs.isCorrectionVisible &&
            lhs.canUseStudyFeatures == rhs.canUseStudyFeatures &&
            lhs.maxBubbleWidth == rhs.maxBubbleWidth
    }

    var body: some View {
        HStack {
            if message.direction == .outgoing {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let reply = message.reply {
                    MessageReplyPreviewView(
                        reply: reply,
                        isOutgoing: message.direction == .outgoing,
                        onTap: {
                            onReplyPreviewTap(reply)
                        }
                    )
                }

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
                    .foregroundStyle(message.direction == .outgoing ? .white.opacity(0.82) : PremiumTheme.textSecondary)
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
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(message.direction == .outgoing ? Color.white.opacity(0.18) : PremiumTheme.hairline, lineWidth: 1)
            }
            .frame(maxWidth: maxBubbleWidth, alignment: message.direction == .outgoing ? .trailing : .leading)
            .shadow(color: .black.opacity(message.direction == .outgoing ? 0.10 : 0.06), radius: 3, y: 2)
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                Button("Reply", systemImage: "arrowshape.turn.up.left", action: onReplySwipe)
                if canUseStudyFeatures {
                    Button("Break Into Words", systemImage: "text.magnifyingglass", action: onAnalyzeTap)
                }
                if message.deliveryState == .failed {
                    Button("Retry", systemImage: "arrow.clockwise", action: onRetryTap)
                }
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = message.translatedText
                }
                Button("Share", systemImage: "square.and.arrow.up", action: onShareTap)
                if message.direction == .outgoing || message.deliveryState == .failed {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDeleteTap)
                }
            }
            .swipeReplyGesture(action: onReplySwipe)

            if message.direction == .incoming {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    private var bubbleFill: some ShapeStyle {
        if message.direction == .outgoing {
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.27, green: 0.44, blue: 0.92),
                        Color(red: 0.83, green: 0.24, blue: 0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            AnyShapeStyle(Color(red: 0.095, green: 0.098, blue: 0.118))
        }
    }

    private var messageContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(message.translatedText)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.trailing, metadataReservedWidth)
                .fixedSize(horizontal: false, vertical: true)

            messageMetadata
        }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    if canUseStudyFeatures {
                        onAnalyzeTap()
                    }
                }
            )
    }

    private var messageMetadata: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(formattedTime)
                .font(.caption.weight(.medium))
                .foregroundStyle(metaColor)
                .monospacedDigit()

            deliveryStatusIcon
        }
        .fixedSize()
    }

    private var formattedTime: String {
        MessageTimeFormatter.shared.string(from: message.timestamp)
    }

    @ViewBuilder
    private var deliveryStatusIcon: some View {
        if message.direction == .outgoing {
            switch message.deliveryState {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(metaColor)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(metaColor)
            case .read:
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(readColor)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.42))
            }
        }
    }

    private var metadataReservedWidth: CGFloat {
        message.direction == .outgoing ? 74 : 54
    }

    private var metaColor: Color {
        message.direction == .outgoing ? .white.opacity(0.74) : .white.opacity(0.48)
    }

    private var readColor: Color {
        Color(red: 0.40, green: 1.0, blue: 0.66)
    }

    private var accessibilityDeliverySummary: String {
        switch message.deliveryState {
        case .sending:
            "Sending, \(message.timestamp.formatted(date: .omitted, time: .shortened))"
        case .sent:
            "Sent, \(message.timestamp.formatted(date: .omitted, time: .shortened))"
        case .read:
            "Read, \(message.timestamp.formatted(date: .omitted, time: .shortened))"
        case .failed:
            "Failed to send, \(message.timestamp.formatted(date: .omitted, time: .shortened))"
        }
    }
}

private enum MessageTimeFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct MessageReplyPreviewView: View {
    let reply: MessageReplyPreview
    let isOutgoing: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(isOutgoing ? Color.white.opacity(0.78) : PremiumTheme.blue.opacity(0.92))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(isOutgoing ? 0.9 : 0.82))
                Text(reply.text)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(isOutgoing ? 0.74 : 0.56))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(isOutgoing ? 0.12 : 0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded(onTap)
        )
    }
}

private struct SwipeReplyModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var didTrigger = false
    @State private var isReplyDragActive = false

    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .overlay(alignment: .trailing) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(replyIconOpacity))
                    .frame(width: 36, height: 36)
                    .background(PremiumTheme.surfaceStrong.opacity(replyIconOpacity), in: Circle())
                    .scaleEffect(replyIconScale)
                    .offset(x: replyIconOffset)
                    .allowsHitTesting(false)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onChanged { value in
                        let translation = value.translation.width
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)
                        let isHorizontalReply = translation < -24 && horizontalDistance > verticalDistance * 1.9
                        if isReplyDragActive == false {
                            guard isHorizontalReply else { return }
                            isReplyDragActive = true
                        }

                        guard verticalDistance < horizontalDistance * 0.72 else {
                            isReplyDragActive = false
                            didTrigger = false
                            dragOffset = 0
                            return
                        }

                        let intended = min(translation, 0)
                        dragOffset = max(intended, -74) * 0.45
                        if abs(translation) > 54, didTrigger == false {
                            didTrigger = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .onEnded { value in
                        guard isReplyDragActive else { return }

                        let shouldReply = value.translation.width < -54 && abs(value.translation.width) > abs(value.translation.height) * 1.9
                        if shouldReply {
                            action()
                        }
                        didTrigger = false
                        isReplyDragActive = false
                        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
                            dragOffset = 0
                        }
                    }
            )
    }

    private var replyIconOpacity: Double {
        min(abs(dragOffset) / 24, 1)
    }

    private var replyIconOffset: CGFloat {
        44 - min(abs(dragOffset), 34)
    }

    private var replyIconScale: CGFloat {
        0.82 + min(abs(dragOffset) / 34, 1) * 0.18
    }
}

private extension View {
    func swipeReplyGesture(action: @escaping () -> Void) -> some View {
        modifier(SwipeReplyModifier(action: action))
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
                .overlay(Color.white.opacity(isOutgoing ? 0.34 : 0.16))

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text(isVisible ? "Hide correction" : "Show correction")
                Spacer(minLength: 4)
                Image(systemName: isVisible ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isOutgoing ? .white.opacity(0.86) : PremiumTheme.textSecondary)
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
                        .foregroundStyle(.white)
                        .textSelection(.enabled)

                    Text(correction.explanation)
                        .font(.caption)
                        .foregroundStyle(isOutgoing ? .white.opacity(0.78) : PremiumTheme.textSecondary)
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
