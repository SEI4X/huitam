import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    let chat: ChatSummary
    private static var pendingMessagesByChatDocumentID: [String: [ChatMessage]] = [:]
    private static var cachedMessagesByChatDocumentID: [String: [ChatMessage]] = [:]
    private static let pageSize = 15
    private static let maxCachedMessagesPerChat = 200

    private let chatService: ChatServicing
    private let studyCardService: StudyCardServicing
    private let aiAssistService: AIAssistServicing
    private let settingsService: SettingsServicing
    private let subscriptionService: SubscriptionServicing
    private let presenceService: PresenceServicing

    private(set) var messages: [ChatMessage] = []
    private(set) var participantPresence: PresenceStatus = .offline
    private(set) var isLoading = false
    private(set) var isLoadingEarlierMessages = false
    private(set) var hasMoreEarlierMessages = true
    private(set) var isSending = false
    private(set) var errorMessage: String?
    private(set) var visibleOriginalMessageIDs: Set<UUID> = []
    private(set) var hiddenCorrectionMessageIDs: Set<UUID> = []
    private(set) var settings = AppDefaults.settings
    private(set) var subscriptionEntitlement: SubscriptionEntitlement = .trial
    private(set) var replyTarget: MessageReplyPreview?
    var analysis: MessageAnalysis?
    var draft = ""
    private(set) var canUseStudyFeatures = false
    var sendTimeout: Duration = .seconds(15)
    private var updatesTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?

    var needsSubscription: Bool {
        chat.currentUserRole.isLearner &&
            settings.canUseStudyFeatures &&
            subscriptionEntitlement.canUseLearnerFeatures == false
    }

    static func resetPendingMessagesForTesting() {
        pendingMessagesByChatDocumentID = [:]
        cachedMessagesByChatDocumentID = [:]
    }

    init(
        chat: ChatSummary,
        chatService: ChatServicing,
        studyCardService: StudyCardServicing,
        aiAssistService: AIAssistServicing,
        settingsService: SettingsServicing,
        subscriptionService: SubscriptionServicing,
        presenceService: PresenceServicing? = nil
    ) {
        self.chat = chat
        self.chatService = chatService
        self.studyCardService = studyCardService
        self.aiAssistService = aiAssistService
        self.settingsService = settingsService
        self.subscriptionService = subscriptionService
        self.presenceService = presenceService ?? NoopPresenceService()
        refreshStudyFeatureAccess()
    }

    func load() async {
        let cachedMessages = Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? []
        if cachedMessages.isEmpty == false {
            messages = initialVisibleMessages(from: cachedMessages)
            hasMoreEarlierMessages = cachedMessages.count >= Self.pageSize
            isLoading = false
        } else {
            isLoading = true
        }
        errorMessage = nil
        async let loadedSettings = settingsService.loadSettings()
        async let loadedEntitlement = subscriptionService.loadEntitlement()

        do {
            if cachedMessages.isEmpty {
                let recentMessages = try await chatService.loadRecentMessages(chat: chat, limit: Self.pageSize)
                replaceMessages(with: recentMessages)
                hasMoreEarlierMessages = recentMessages.count == Self.pageSize
            } else {
                startMessageUpdates(after: cachedMessages.map(\.updatedAt).max())
            }
            markChatReadInBackground()
            let (settings, entitlement) = try await (loadedSettings, loadedEntitlement)
            self.settings = settings
            subscriptionEntitlement = entitlement
            refreshStudyFeatureAccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadEarlierMessages() async {
        guard isLoadingEarlierMessages == false, hasMoreEarlierMessages else { return }
        guard let oldestMessage = messages
            .filter({ $0.deliveryState != .sending && $0.deliveryState != .failed })
            .min(by: { $0.timestamp < $1.timestamp })
        else { return }

        isLoadingEarlierMessages = true
        defer { isLoadingEarlierMessages = false }

        do {
            let cachedEarlierMessages = cachedEarlierMessages(before: oldestMessage, limit: Self.pageSize)
            if cachedEarlierMessages.isEmpty == false {
                hasMoreEarlierMessages = cachedHasMessages(before: cachedEarlierMessages.first ?? oldestMessage)
                mergeServerMessages(cachedEarlierMessages)
                return
            }

            let earlierMessages = try await chatService.loadEarlierMessages(chat: chat, before: oldestMessage, limit: Self.pageSize)
            hasMoreEarlierMessages = earlierMessages.count == Self.pageSize
            mergeServerMessages(earlierMessages)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func revealMessageIfNeeded(id messageID: UUID) async -> Bool {
        if messages.contains(where: { $0.id == messageID }) {
            return true
        }

        if let cachedMessage = (Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? []).first(where: { $0.id == messageID }) {
            await revealCachedMessages(through: cachedMessage)
            return true
        }

        while hasMoreEarlierMessages && isLoadingEarlierMessages == false {
            let previousCount = messages.count
            await loadEarlierMessages()

            if messages.contains(where: { $0.id == messageID }) {
                return true
            }

            if messages.count == previousCount {
                break
            }
        }

        return messages.contains(where: { $0.id == messageID })
    }

    func loadSettings() async {
        do {
            let settings = try await settingsService.loadSettings()
            self.settings = settings
            refreshStudyFeatureAccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopMessageUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
        presenceTask?.cancel()
        presenceTask = nil
    }

    func startObservingPresence() async {
        presenceTask?.cancel()
        let userID = chat.participant.uid
        guard userID.isEmpty == false else {
            participantPresence = .offline
            return
        }

        presenceTask = Task { [presenceService] in
            for await status in presenceService.presenceUpdates(for: userID) {
                guard Task.isCancelled == false else { break }
                self.participantPresence = status
            }
        }
        for _ in 0..<3 {
            await Task.yield()
        }
    }

    func startLearnerTrial() async {
        guard chat.currentUserRole.isLearner else { return }

        do {
            subscriptionEntitlement = try await subscriptionService.startTrial()
            refreshStudyFeatureAccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDraft() async {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty == false else { return }

        errorMessage = nil
        let localMessageID = UUID()
        let localMessage = ChatMessage(
            id: localMessageID,
            chatID: chat.id,
            senderID: UUID(),
            timestamp: Date(),
            translatedText: trimmedDraft,
            originalText: trimmedDraft,
            direction: .outgoing,
            deliveryState: .sending,
            reply: replyTarget
        )
        let reply = replyTarget

        messages.append(localMessage)
        storePending(localMessage)
        cacheMessages(messages)
        draft = ""
        replyTarget = nil

        do {
            let message = try await sendWithTimeout(draft: trimmedDraft, localID: localMessageID, reply: reply)
            if let index = messages.firstIndex(where: { $0.id == localMessageID }) {
                messages[index] = message
            } else {
                messages.append(message)
            }
            removePendingMessage(id: localMessageID)
            cacheMessages(messages)
        } catch {
            errorMessage = error.localizedDescription
            if let index = messages.firstIndex(where: { $0.id == localMessageID }) {
                messages[index].deliveryState = .failed
                messages[index].errorMessage = AppErrorMessage.userFacing(error)
                storePending(messages[index])
                cacheMessages(messages)
            }
        }
    }

    func retry(_ message: ChatMessage) async {
        guard message.direction == .outgoing, message.deliveryState == .failed else { return }
        let retryMessageID = UUID()

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].id = retryMessageID
            messages[index].deliveryState = .sending
            messages[index].errorMessage = nil
            storePending(messages[index])
            cacheMessages(messages)
        }

        do {
            let sentMessage = try await sendWithTimeout(
                draft: message.originalText.isEmpty ? message.translatedText : message.originalText,
                localID: retryMessageID,
                reply: message.reply
            )
            if let index = messages.firstIndex(where: { $0.id == retryMessageID }) {
                messages[index] = sentMessage
            } else {
                messages.append(sentMessage)
            }
            removePendingMessage(id: message.id)
            removePendingMessage(id: retryMessageID)
            cacheMessages(messages)
        } catch {
            if let index = messages.firstIndex(where: { $0.id == retryMessageID }) {
                messages[index].deliveryState = .failed
                messages[index].errorMessage = AppErrorMessage.userFacing(error)
                storePending(messages[index])
                cacheMessages(messages)
            }
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func deleteFailedMessage(_ message: ChatMessage) {
        guard message.deliveryState == .failed else { return }
        messages.removeAll { $0.id == message.id }
        removePendingMessage(id: message.id)
        cacheMessages(messages)
    }

    func delete(_ message: ChatMessage) async {
        if message.deliveryState == .failed {
            deleteFailedMessage(message)
            return
        }

        guard message.direction == .outgoing else { return }

        do {
            try await chatService.deleteMessage(chat: chat, message: message)
            messages.removeAll { $0.id == message.id }
            removePendingMessage(id: message.id)
            cacheMessages(messages, removingIDs: [message.id])
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
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

    func startReply(to message: ChatMessage) {
        replyTarget = MessageReplyPreview(
            messageID: message.id,
            senderName: message.direction == .outgoing ? "You" : chat.participant.displayName,
            text: message.translatedText,
            originalText: message.direction == .incoming && message.originalText.isEmpty == false ? message.originalText : nil
        )
    }

    func cancelReply() {
        replyTarget = nil
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

    private func refreshStudyFeatureAccess() {
        canUseStudyFeatures = chat.currentUserRole.isLearner &&
            settings.canUseStudyFeatures &&
            subscriptionEntitlement.canUseLearnerFeatures
    }

    private func sendWithTimeout(draft: String, localID: UUID, reply: MessageReplyPreview?) async throws -> ChatMessage {
        try await withThrowingTaskGroup(of: ChatMessage.self) { group in
            group.addTask { [chatService, chat] in
                try await chatService.sendMessage(chat: chat, draft: draft, localID: localID, reply: reply)
            }

            group.addTask { [sendTimeout] in
                try await Task.sleep(for: sendTimeout)
                throw ChatSendError.timeout
            }

            guard let result = try await group.next() else {
                throw ChatSendError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    private var pendingMessagesKey: String {
        chat.documentID.isEmpty ? chat.id.uuidString : chat.documentID
    }

    private func replaceMessages(with loadedMessages: [ChatMessage]) {
        messages = mergePendingMessages(into: visibleMessages(from: loadedMessages))
        cacheMessages(messages)
        startMessageUpdates(after: loadedMessages.map(\.updatedAt).max())
    }

    private func mergeServerMessages(_ serverMessages: [ChatMessage]) {
        guard serverMessages.isEmpty == false else { return }
        var mergedMessagesByID = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        for message in visibleMessages(from: serverMessages) {
            mergedMessagesByID[message.id] = message
            removePendingMessage(id: message.id)
        }
        messages = mergedMessagesByID.values.sorted { $0.timestamp < $1.timestamp }
        cacheMessages(messages)
    }

    private func mergePendingMessages(into loadedMessages: [ChatMessage]) -> [ChatMessage] {
        let pendingMessages = Self.pendingMessagesByChatDocumentID[pendingMessagesKey] ?? []
        let loadedIDs = Set(loadedMessages.map(\.id))
        return loadedMessages + pendingMessages.filter { loadedIDs.contains($0.id) == false }
    }

    private func initialVisibleMessages(from cachedMessages: [ChatMessage]) -> [ChatMessage] {
        let recentCachedMessages = cachedMessages
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(Self.pageSize)
        return mergePendingMessages(into: Array(recentCachedMessages))
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func cachedEarlierMessages(before oldestMessage: ChatMessage, limit: Int) -> [ChatMessage] {
        let visibleIDs = Set(messages.map(\.id))
        return (Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? [])
            .filter { $0.timestamp < oldestMessage.timestamp && visibleIDs.contains($0.id) == false }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(limit)
    }

    private func cachedHasMessages(before message: ChatMessage) -> Bool {
        (Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? [])
            .contains { $0.timestamp < message.timestamp && messages.contains($0) == false }
    }

    private func revealCachedMessages(through targetMessage: ChatMessage) async {
        let cachedMessages = (Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? [])
            .filter { $0.timestamp >= targetMessage.timestamp }
            .sorted { $0.timestamp < $1.timestamp }
        mergeServerMessages(cachedMessages)
        hasMoreEarlierMessages = cachedHasMessages(before: targetMessage)
        await Task.yield()
    }

    private func visibleMessages(from messages: [ChatMessage]) -> [ChatMessage] {
        messages.filter { message in
            message.direction == .outgoing || message.deliveryState != .translating
        }
    }

    private func cacheMessages(_ messages: [ChatMessage], removingIDs: Set<UUID> = []) {
        var mergedMessagesByID = Dictionary(uniqueKeysWithValues: (Self.cachedMessagesByChatDocumentID[pendingMessagesKey] ?? []).map { ($0.id, $0) })
        for id in removingIDs {
            mergedMessagesByID[id] = nil
        }
        for message in messages where removingIDs.contains(message.id) == false {
            mergedMessagesByID[message.id] = message
        }

        let cacheableMessages = mergedMessagesByID.values
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(Self.maxCachedMessagesPerChat)
        Self.cachedMessagesByChatDocumentID[pendingMessagesKey] = Array(cacheableMessages)
    }

    private func startMessageUpdates(after date: Date?) {
        updatesTask?.cancel()
        updatesTask = Task { [chatService, chat, weak self] in
            for await result in chatService.messageUpdates(chat: chat, after: date) {
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    guard let self else { return }
                    switch result {
                    case let .success(messages):
                        self.mergeServerMessages(messages)
                        self.markChatReadInBackground()
                    case let .failure(error):
                        self.errorMessage = AppErrorMessage.userFacing(error)
                    }
                }
            }
        }
    }

    private func markChatReadInBackground() {
        guard messages.contains(where: { $0.direction == .incoming && $0.deliveryState != .read }) else {
            return
        }

        Task { [chatService, chat] in
            try? await chatService.markChatRead(chat: chat)
        }
    }

    private func storePending(_ message: ChatMessage) {
        var pendingMessages = Self.pendingMessagesByChatDocumentID[pendingMessagesKey] ?? []
        pendingMessages.removeAll { $0.id == message.id }
        pendingMessages.append(message)
        Self.pendingMessagesByChatDocumentID[pendingMessagesKey] = pendingMessages
    }

    private func removePendingMessage(id: UUID) {
        var pendingMessages = Self.pendingMessagesByChatDocumentID[pendingMessagesKey] ?? []
        pendingMessages.removeAll { $0.id == id }
        if pendingMessages.isEmpty {
            Self.pendingMessagesByChatDocumentID.removeValue(forKey: pendingMessagesKey)
        } else {
            Self.pendingMessagesByChatDocumentID[pendingMessagesKey] = pendingMessages
        }
    }
}

enum ChatSendError: LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            "Message took too long to send. Check your connection and try again."
        }
    }
}
