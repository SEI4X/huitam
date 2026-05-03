import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatViewModel
    @State private var isAIHelpPresented = false
    @State private var shareTextItem: ActivityShareTextItem?
    @State private var didAnchorInitialMessages = false
    @State private var highlightedMessageID: UUID?
    private let bottomAnchorID = "chat-bottom-anchor"

    init(chat: ChatSummary, container: AppDependencyContainer) {
        _viewModel = State(initialValue: ChatViewModel(
            chat: chat,
            chatService: container.chatService,
            studyCardService: container.studyCardService,
            aiAssistService: container.aiAssistService,
            settingsService: container.settingsService,
            subscriptionService: container.subscriptionService,
            presenceService: container.presenceService
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            let maxBubbleWidth = min(geometry.size.width * 0.76, 360)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if viewModel.hasMoreEarlierMessages && viewModel.messages.isEmpty == false {
                            Button {
                                Task {
                                    await viewModel.loadEarlierMessages()
                                }
                            } label: {
                                if viewModel.isLoadingEarlierMessages {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white.opacity(0.72))
                                } else {
                                    Label("Earlier messages", systemImage: "chevron.up")
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(PremiumTheme.textSecondary)
                            .padding(.vertical, 8)
                            .disabled(viewModel.isLoadingEarlierMessages)
                        }

                        if viewModel.needsSubscription {
                            LearnerSubscriptionBanner {
                                Task {
                                    await viewModel.startLearnerTrial()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }

                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOriginalVisible: viewModel.isOriginalVisible(for: message),
                                isCorrectionVisible: viewModel.isCorrectionVisible(for: message),
                                canUseStudyFeatures: viewModel.canUseStudyFeatures,
                                maxBubbleWidth: maxBubbleWidth,
                                onOriginalTap: {
                                    viewModel.toggleOriginal(for: message)
                                },
                                onCorrectionToggle: {
                                    viewModel.toggleCorrection(for: message)
                                },
                                onReplySwipe: {
                                    withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
                                        viewModel.startReply(to: message)
                                    }
                                },
                                onAnalyzeTap: {
                                    Task {
                                        await viewModel.analyze(message)
                                    }
                                },
                                onRetryTap: {
                                    Task {
                                        await viewModel.retry(message)
                                    }
                                },
                                onDeleteTap: {
                                    Task {
                                        await viewModel.delete(message)
                                    }
                                },
                                onShareTap: {
                                    shareTextItem = ActivityShareTextItem(text: shareText(for: message))
                                },
                                onReplyPreviewTap: { reply in
                                    Task {
                                        await jumpToReply(reply, proxy: proxy)
                                    }
                                }
                            )
                            .equatable()
                            .id(message.id)
                            .transition(messageTransition(for: message))
                            .scaleEffect(highlightedMessageID == message.id ? 1.035 : 1, anchor: message.direction == .outgoing ? .trailing : .leading)
                            .brightness(highlightedMessageID == message.id ? 0.13 : 0)
                            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: highlightedMessageID)
                        }

                        Color.clear
                            .frame(height: 18)
                            .id(bottomAnchorID)
                    }
                    .padding(.top, 14)
                }
                .defaultScrollAnchor(.bottom)
                .background {
                    PremiumScreenBackground(intensity: 0.72)
                        .ignoresSafeArea()
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onEnded { value in
                            if shouldDismissKeyboard(after: value) {
                                dismissKeyboard()
                            }
                        }
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ChatInputBarView(
                        draft: Binding(
                            get: { viewModel.draft },
                            set: { viewModel.draft = $0 }
                        ),
                        replyTarget: viewModel.replyTarget,
                        isSending: viewModel.isSending,
                        canUseStudyFeatures: viewModel.canUseStudyFeatures,
                        onSend: {
                            Task {
                                await viewModel.sendDraft()
                            }
                        },
                        onAIHelp: {
                            Task {
                                await viewModel.suggestReply()
                                withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                                    isAIHelpPresented = true
                                }
                            }
                        },
                        onCancelReply: {
                            viewModel.cancelReply()
                        }
                    )
                }
                .onChange(of: viewModel.messages.last?.id) { _, newLastID in
                    guard newLastID != nil else { return }
                    Task { @MainActor in
                        await settleBeforeBottomScroll()
                        if didAnchorInitialMessages {
                            withAnimation(AppMotion.messageInsert(reduceMotion: reduceMotion)) {
                                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                            }
                        } else {
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                            didAnchorInitialMessages = true
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.chat.participant.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatNavigationPresenceTitle(
                    name: viewModel.chat.participant.displayName,
                    presence: viewModel.participantPresence
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChatStatsView(chat: viewModel.chat, messages: viewModel.messages)
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Chat Stats")
            }
        }
        .task {
            await viewModel.load()
        }
        .task {
            await viewModel.startObservingPresence()
        }
        .onDisappear {
            viewModel.stopMessageUpdates()
        }
        .sheet(item: Binding(
            get: { viewModel.analysis },
            set: { viewModel.analysis = $0 }
        )) { analysis in
            let liveAnalysis = viewModel.analysis ?? analysis
            MessageAnalysisSheet(
                analysis: liveAnalysis,
                onToggleToken: { token in
                    viewModel.toggleTokenSelection(token)
                },
                onSave: {
                    Task {
                        await viewModel.saveSelectedTokens()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAIHelpPresented) {
            AIWritingHelpSheet(
                suggestion: viewModel.draft,
                onUseSuggestion: {}
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $shareTextItem) { item in
            ActivityShareView(items: [item.text])
        }
    }

    private func shareText(for message: ChatMessage) -> String {
        var components: [String] = []
        components.append(message.translatedText)

        if message.direction == .incoming, message.originalText.isEmpty == false {
            components.append("Original: \(message.originalText)")
        }

        if message.direction == .outgoing, let correction = message.correction {
            components.append("Correction: \(correction.correctedText)")
            if correction.explanation.isEmpty == false {
                components.append("Note: \(correction.explanation)")
            }
        }

        return components.joined(separator: "\n\n")
    }

    private func messageTransition(for message: ChatMessage) -> AnyTransition {
        let edge: Edge = message.direction == .outgoing ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .scale(scale: 0.94, anchor: message.direction == .outgoing ? .trailing : .leading)).combined(with: .opacity),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    @MainActor
    private func settleBeforeBottomScroll() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    private func shouldDismissKeyboard(after value: DragGesture.Value) -> Bool {
        let verticalDistance = abs(value.translation.height)
        let horizontalDistance = abs(value.translation.width)
        let projectedVerticalMomentum = abs(value.predictedEndTranslation.height - value.translation.height)

        return verticalDistance > horizontalDistance &&
            verticalDistance > 24 &&
            projectedVerticalMomentum > 130
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @MainActor
    private func jumpToReply(_ reply: MessageReplyPreview, proxy: ScrollViewProxy) async {
        guard await viewModel.revealMessageIfNeeded(id: reply.messageID) else { return }

        await Task.yield()
        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
            proxy.scrollTo(reply.messageID, anchor: .center)
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
            highlightedMessageID = reply.messageID
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
            if highlightedMessageID == reply.messageID {
                highlightedMessageID = nil
            }
        }
    }
}

private struct ChatNavigationPresenceTitle: View {
    let name: String
    let presence: PresenceStatus

    var body: some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 5) {
                Text(presence.label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityLabel("\(name), \(presence.label)")
    }
}

private struct LearnerSubscriptionBanner: View {
    @Environment(\.appTintColor) private var tintColor

    let onStartTrial: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(tintColor)
            Text("Learner mode")
                .font(.headline)
                .foregroundStyle(PremiumTheme.textPrimary)
                Spacer()
            }

            Text("AI hints, corrections, message analysis, and saved cards are available for learners.")
                .font(.subheadline)
                .foregroundStyle(PremiumTheme.textSecondary)

            Button(action: onStartTrial) {
                Label("Start Trial", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .premiumSurface(cornerRadius: 20, strength: 1.25)
    }
}
