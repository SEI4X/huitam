import SwiftUI

struct ChatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatViewModel
    @State private var isAIHelpPresented = false

    init(chat: ChatSummary, container: AppDependencyContainer) {
        _viewModel = State(initialValue: ChatViewModel(
            chat: chat,
            chatService: container.chatService,
            studyCardService: container.studyCardService,
            aiAssistService: container.aiAssistService,
            settingsService: container.settingsService
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isOriginalVisible: viewModel.isOriginalVisible(for: message),
                            isCorrectionVisible: viewModel.isCorrectionVisible(for: message),
                            canUseStudyFeatures: viewModel.canUseStudyFeatures,
                            onOriginalTap: {
                                viewModel.toggleOriginal(for: message)
                            },
                            onCorrectionToggle: {
                                viewModel.toggleCorrection(for: message)
                            },
                            onAnalyzeTap: {
                                Task {
                                    await viewModel.analyze(message)
                                }
                            }
                        )
                        .id(message.id)
                        .transition(messageTransition(for: message))
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 118)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputBarView(
                    draft: Binding(
                        get: { viewModel.draft },
                        set: { viewModel.draft = $0 }
                    ),
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
                    }
                )
                .background(.clear)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastID = viewModel.messages.last?.id else { return }
                withAnimation(AppMotion.messageInsert(reduceMotion: reduceMotion)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
        .navigationTitle(viewModel.chat.participant.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChatStatsView(chat: viewModel.chat, messages: viewModel.messages)
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.callout.weight(.semibold))
                }
                .accessibilityLabel("Chat Stats")
            }
        }
        .task {
            await viewModel.load()
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
    }

    private func messageTransition(for message: ChatMessage) -> AnyTransition {
        let edge: Edge = message.direction == .outgoing ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .scale(scale: 0.94, anchor: message.direction == .outgoing ? .trailing : .leading)).combined(with: .opacity),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }
}
