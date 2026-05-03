import SwiftUI

struct AvatarView: View {
    let systemImage: String
    let size: CGFloat
    var seed: UUID?

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundGradient)

            Image(systemName: avatarSymbol)
                .font(.system(size: size * 0.56, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: backgroundColor.opacity(0.18), radius: 8, y: 5)
        .accessibilityHidden(true)
    }

    private var avatarSymbol: String {
        systemImage.contains("person") ? "person.fill" : systemImage
    }

    private var backgroundColor: Color {
        let palette: [Color] = [
            Color(red: 0.20, green: 0.42, blue: 1.0),
            Color(red: 0.36, green: 0.72, blue: 0.64),
            Color(red: 0.96, green: 0.22, blue: 0.56),
            Color(red: 0.53, green: 0.40, blue: 1.0),
            Color(red: 1.0, green: 0.55, blue: 0.26),
            Color(red: 0.26, green: 0.82, blue: 0.92)
        ]
        guard let seed else {
            return PremiumTheme.blue
        }
        let index = seed.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        } % palette.count
        return palette[index]
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                backgroundColor.opacity(0.95),
                backgroundColor.opacity(0.48),
                PremiumTheme.surfaceStrong
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
