import SwiftUI

struct PresenceAvatarView: View {
    let systemImage: String
    let size: CGFloat
    var seed: UUID?
    var presence: PresenceStatus

    var body: some View {
        AvatarView(systemImage: systemImage, size: size, seed: seed)
            .overlay(alignment: .bottomTrailing) {
                if presence.isOnline {
                    Circle()
                        .fill(Color(red: 0.31, green: 0.96, blue: 0.55))
                        .frame(width: max(size * 0.25, 10), height: max(size * 0.25, 10))
                        .overlay {
                            Circle()
                                .stroke(PremiumTheme.surfaceStrong, lineWidth: max(size * 0.055, 2))
                        }
                        .shadow(color: Color.green.opacity(0.34), radius: 7, y: 2)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: presence.isOnline)
    }
}
