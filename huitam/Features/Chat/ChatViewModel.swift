import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    let chat: ChatSummary

    private let chatService: ChatServicing
    private let studyCardService: StudyCardServicing
    private let aiAssistService: AIAssistServicing
    private let settingsService: SettingsServicing

    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?
    private(set) var visibleOriginalMessageIDs: Set<UUID> = []
    private(set) var hiddenCorrectionMessageIDs: Set<UUID> = []
    var analysis: MessageAnalysis?
    var draft = ""
    var canUseStudyFeatures = true

    init(
        chat: ChatSummary,
        chatService: ChatServicing,
        studyCardService: StudyCardServicing,
        aiAssistService: AIAssistServicing,
        settingsService: SettingsServicing
    ) {
        self.chat = chat
        self.chatService = chatService
        self.studyCardService = studyCardService
        self.aiAssistService = aiAssistService
        self.settingsService = settingsService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        async let loadedMessages = chatService.loadMessages(chatID: chat.id)
        async let loadedSettings = settingsService.loadSettings()

        do {
            let (messages, settings) = try await (loadedMessages, loadedSettings)
            self.messages = messages
            canUseStudyFeatures = settings.canUseStudyFeatures
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadSettings() async {
        do {
            let settings = try await settingsService.loadSettings()
            canUseStudyFeatures = settings.canUseStudyFeatures
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDraft() async {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty == false else { return }

        isSending = true
        errorMessage = nil
        do {
            let message = try await chatService.sendMessage(chatID: chat.id, draft: trimmedDraft)
            messages.append(message)
            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func toggleOriginal(for message: ChatMessage) {
        if visibleOriginalMessageIDs.contains(message.id) {
            visibleOriginalMessageIDs.remove(message.id)
        } else {
            visibleOriginalMessageIDs.insert(message.id)
        }
    }

    func isOriginalVisible(for message: ChatMessage) -> Bool {
        visibleOriginalMessageIDs.contains(message.id)
    }

    func toggleCorrection(for message: ChatMessage) {
        if hiddenCorrectionMessageIDs.contains(message.id) {
            hiddenCorrectionMessageIDs.remove(message.id)
        } else {
            hiddenCorrectionMessageIDs.insert(message.id)
        }
    }

    func isCorrectionVisible(for message: ChatMessage) -> Bool {
        message.correction != nil && hiddenCorrectionMessageIDs.contains(message.id) == false
    }

    func analyze(_ message: ChatMessage) async {
        guard canUseStudyFeatures else { return }
        do {
            analysis = try await chatService.analyze(message: message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleTokenSelection(_ token: MessageToken) {
        guard analysis != nil else { return }
        if analysis!.selectedTokenIDs.contains(token.id) {
            analysis!.selectedTokenIDs.remove(token.id)
        } else {
            analysis!.selectedTokenIDs.insert(token.id)
        }
    }

    func saveSelectedTokens() async {
        guard canUseStudyFeatures, let analysis else { return }
        let cards = analysis.selectedTokens.map { token in
            StudyCard(
                id: UUID(),
                sourceMessageID: analysis.messageID,
                type: .word,
                frontText: token.text,
                backText: token.translation,
                note: token.partOfSpeech,
                language: chat.practiceLanguage ?? .english,
                createdAt: Date()
            )
        }
        guard cards.isEmpty == false else { return }

        do {
            try await studyCardService.saveCards(cards)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func suggestReply() async {
        do {
            draft = try await aiAssistService.suggestReply(for: chat, messages: messages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
