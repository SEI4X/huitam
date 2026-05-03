import Intents
import UIKit
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        bestAttemptContent = content

        Task {
            let updatedContent = await communicationNotificationContent(from: content, userInfo: request.content.userInfo)
            contentHandler(updatedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func communicationNotificationContent(
        from content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) async -> UNNotificationContent {
        let senderName = userInfo["senderName"] as? String ?? content.title
        let messageText = content.body
        let chatID = userInfo["chatId"] as? String ?? UUID().uuidString

        content.title = senderName
        content.body = messageText
        content.attachments = []
        content.threadIdentifier = chatID
        content.targetContentIdentifier = chatID

        let sender = INPerson(
            personHandle: INPersonHandle(value: userInfo["senderUID"] as? String ?? senderName, type: .unknown),
            nameComponents: nil,
            displayName: senderName,
            image: await avatarImage(from: userInfo),
            contactIdentifier: nil,
            customIdentifier: userInfo["senderUID"] as? String,
            isMe: false,
            suggestionType: .none
        )
        let currentUser = INPerson(
            personHandle: INPersonHandle(value: "me", type: .unknown),
            nameComponents: nil,
            displayName: "You",
            image: nil,
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: true,
            suggestionType: .none
        )
        let intent = INSendMessageIntent(
            recipients: [currentUser],
            outgoingMessageType: .outgoingMessageText,
            content: messageText,
            speakableGroupName: nil,
            conversationIdentifier: chatID,
            serviceName: "huitam",
            sender: sender,
            attachments: nil
        )
        intent.setImage(sender.image, forParameterNamed: \.sender)

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        try? await interaction.donate()

        do {
            return try content.updating(from: intent)
        } catch {
            return content
        }
    }

    private func avatarImage(from userInfo: [AnyHashable: Any]) async -> INImage? {
        if let rawURL = userInfo["chatAvatarURL"] as? String,
           let url = URL(string: rawURL),
           let data = await downloadedAvatarData(from: url) {
            return INImage(imageData: circularAvatarData(from: data) ?? data)
        }

        let color = UIColor(hex: userInfo["chatAvatarColorHex"] as? String) ?? UIColor(red: 0.20, green: 0.42, blue: 1.0, alpha: 1)
        let symbol = userInfo["chatAvatarSymbol"] as? String ?? "person.fill"
        return generatedAvatarData(color: color, symbolName: symbol).map(INImage.init(imageData:))
    }

    private func downloadedAvatarData(from url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    private func circularAvatarData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        let avatar = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()

            let aspect = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            let drawOrigin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        return avatar.pngData()
    }

    private func generatedAvatarData(color: UIColor, symbolName: String) -> Data? {
        let size = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.addEllipse(in: rect)
            cgContext.clip()

            let colors = [
                color.withAlphaComponent(0.98).cgColor,
                color.withAlphaComponent(0.52).cgColor,
                UIColor(white: 1, alpha: 0.12).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.62, 1])
            if let gradient {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            cgContext.restoreGState()

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 72, weight: .regular)
            let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig) ??
                UIImage(systemName: "person.fill", withConfiguration: symbolConfig)
            let symbolImage = symbol?.withTintColor(.white.withAlphaComponent(0.86), renderingMode: .alwaysOriginal)
            let symbolRect = CGRect(x: 44, y: 40, width: 72, height: 72)
            symbolImage?.draw(in: symbolRect)
        }
        return image.pngData()
    }

}

private extension UIColor {
    convenience init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }

        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
